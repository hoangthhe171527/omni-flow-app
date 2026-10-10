import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/media_url.dart';
import '../../../design/components/components.dart';
import '../../../design/platform/omni_motion_scope.dart';
import '../../../design/tokens/tokens.dart';
import '../../../core/realtime/realtime_client.dart';
import '../../settings/settings.dart';
import '../application/inbox_providers.dart';
import '../application/inbox_realtime.dart';
import '../application/media_url_resolver.dart';
import '../application/thread_controller.dart';
import '../application/voice_recorder.dart';
import '../data/inbox_api.dart';
import '../domain/conversation.dart';
import '../domain/message.dart';
import '../domain/outbound_capabilities.dart';
import '../domain/pending_attachment.dart';
import '../../../security/session/session_controller.dart';
import '../../opportunities/opportunities.dart';
import '../../tasks/domain/task_permissions.dart';
import '../../tasks/routes.dart';
import '../../tasks/tasks.dart';
import '../../team/team.dart';
import '../inbox_routes.dart';
import 'message_key_registry.dart';
import 'thread_info_page.dart';
import 'widgets/attachment_picking.dart';
import 'widgets/composer_snack_bar.dart';
import 'widgets/message_bubble.dart';
import 'widgets/message_composer.dart';
import 'widgets/message_images.dart';
import 'widgets/thread_header.dart';
import 'widgets/thread_intro.dart';

export '../application/media_url_resolver.dart' show mediaReloadCooldown;

/// Đồng hồ của [mediaReloadCooldown] — test thay để khỏi chờ 10 phút thật.
@visibleForTesting
DateTime Function() mediaReloadClock = DateTime.now;

/// Rule-based, not generated: openers a rep would type anyway, offered as one
/// tap. Deliberately generic — a wrong "smart" suggestion costs more trust
/// than no suggestion.
const _defaultTemplates = <String>[
  'Dạ em chào anh/chị ạ!',
  'Em gửi báo giá ạ',
  'Em gọi lại ngay',
  'Cảm ơn anh/chị đã quan tâm.',
  'Anh/chị cho em xin số điện thoại để tư vấn nhé.',
  'Bên em đang có chương trình ưu đãi ạ.',
];

class ThreadPage extends ConsumerStatefulWidget {
  const ThreadPage({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ThreadPage> createState() => _ThreadPageState();
}

class _ThreadPageState extends ConsumerState<ThreadPage>
    with WidgetsBindingObserver {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _syncTimer;

  /// Nhịp poll dự phòng theo trạng thái socket thật (MS-I38).
  final _realtime = InboxRealtime.thread();
  String? _syncCursor;
  bool _syncing = false;
  Timer? _searchDebounce;
  Message? _replyingTo;

  /// Câu 422 của server khi gửi (`channel_send_unsupported`), hiện trong
  /// composer tới lượt gửi sau.
  String? _sendError;
  bool _searchMode = false;
  List<Message> _searchResults = const [];
  int _searchIndex = 0;

  /// Xin URL ký mới khi media hết hạn (MS-I24 + việc dồn từ Đợt 7 cho video).
  ///
  /// MỘT cái cho cả màn: nó là chỗ giữ "đã xin cho tệp nào rồi", thời gian
  /// nghỉ, và việc gộp cả loạt tệp hết hạn vào một lượt tải lại.
  late final MediaUrlResolver _mediaResolver = MediaUrlResolver(
    onReload: () =>
        ref.read(threadProvider(widget.conversationId).notifier).reloadMedia(),
    lookup: _freshMediaUrl,
    clock: () => mediaReloadClock(),
  );

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addObserver(this);
    _startRealtimeFallback();
    // Opening a thread is the act of reading it.
    Future.microtask(() async {
      // `/read` cần `inbox.write` (routes.php:49). Người chỉ đọc không gọi:
      // số chưa đọc là của hội thoại, giữ cho người phụ trách (INB-I28, Q3).
      if (!ref.read(inboxAccessProvider).canSend) return;
      try {
        await ref.read(inboxApiProvider).markRead(widget.conversationId);
        // Patch the ROW too, not just the filter counts. patch()'s own
        // docstring says it exists for "assign, mark-read and labelling", but
        // mark-read never called it — so returning from a thread you had just
        // read left it bold with a red badge until the next full refetch.
        final current = ref
            .read(conversationProvider(widget.conversationId))
            .valueOrNull;
        if (current != null) {
          ref.read(inboxListProvider.notifier).patch(current.asRead());
        }
        ref.invalidate(inboxFacetsProvider);
      } on AppException {
        // Non-critical: the badge stays until the next refresh.
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _syncTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshThread();
      _startRealtimeFallback();
    } else {
      _syncTimer?.cancel();
      _syncTimer = null;
    }
  }

  /// The catch-up poll, at whichever interval the socket's health calls for.
  ///
  /// Hẹn giờ một lượt rồi tự đặt lại — xem ghi chú ở `inbox_page.dart`.
  void _startRealtimeFallback() {
    _syncTimer?.cancel();
    _syncTimer = null;
    final period = _realtime.pollInterval;
    if (period == null) return;
    _syncTimer = Timer(period, _pollTick);
  }

  Future<void> _pollTick() async {
    _syncTimer = null;
    await _catchUpChanges();
    if (!mounted) return;
    _realtime.tickBackoff();
    _startRealtimeFallback();
  }

  Future<void> _catchUpChanges() async {
    if (!mounted || _syncing) return;
    _syncing = true;
    try {
      final changes = await ref
          .read(inboxApiProvider)
          .changes(_syncCursor, conversationId: widget.conversationId);
      if (!mounted) return;
      _syncCursor = changes.cursor.isEmpty ? _syncCursor : changes.cursor;
      if (changes.count > 0) {
        _refreshThread();
      }
    } catch (_) {
      // The next cursor poll retries without clearing the visible thread.
    } finally {
      _syncing = false;
    }
  }

  void _refreshThread() {
    // refresh(), not invalidate(). Invalidating rebuilt the thread from the
    // server every few seconds, which erased everything the server does not know
    // about: a failed send waiting to be retried (gone before the rep could act
    // on it), every older page they had scrolled back through, and the notifier
    // an in-flight send was about to write its result to.
    unawaited(
      ref
          .read(threadProvider(widget.conversationId).notifier)
          .refresh()
          .catchError((_) {
            // A refresh that fails leaves what is on screen; the next poll
            // retries. Nothing here should surface as an error to the rep.
          }),
    );
    ref.invalidate(conversationProvider(widget.conversationId));
    ref.invalidate(inboxFacetsProvider);
  }

  /// Ảnh trong tin không tải được — thường là link ký đã quá 12 giờ. Tải lại
  /// tin để lấy URL ký mới, đúng MỘT lần cho cả loạt ảnh hỏng cùng lúc; ảnh vẫn
  /// hỏng sau đó (tệp đã xoá, mất mạng) không kéo thành vòng lặp tải lại.
  ///
  /// Thời gian nghỉ 10 phút chỉ tính từ lượt tải lại THÀNH CÔNG: lượt hỏng
  /// (đang mất mạng) không được khoá việc phục hồi khi mạng đã về.
  void _onMediaLoadError() => _reloadMedia(userInitiated: false);

  /// Người dùng bấm "Tải lại ảnh": bỏ qua thời gian nghỉ (một lần bấm là một
  /// lượt, không thể thành vòng lặp), vẫn không chồng lượt đang chạy.
  void _onMediaUserRetry() => _reloadMedia(userInitiated: true);

  void _reloadMedia({required bool userInitiated}) =>
      unawaited(_mediaResolver.reloadAll(force: userInitiated));

  /// URL ký mới của đúng tệp này sau lượt tải lại, tra theo khoá cache (bỏ
  /// `expires`/`signature`) nên bản cũ và bản mới là MỘT tệp.
  String? _freshMediaUrl(String url) {
    final key = mediaCacheKey(resolveMediaUrl(url));
    final state = ref.read(threadProvider(widget.conversationId)).valueOrNull;
    if (state == null) return null;
    for (final message in state.messages) {
      for (final attachment in message.attachments) {
        final candidate = resolveMediaUrl(attachment.url);
        if (mediaCacheKey(candidate) == key) return candidate;
      }
    }
    return null;
  }

  void _onScroll() {
    // The list is reversed, so "older" is at the far end of the scroll extent.
    if (_scrollController.position.extentAfter < 200) {
      ref.read(threadProvider(widget.conversationId).notifier).loadOlder();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tín hiệu của RIÊNG hội thoại này — tin mới, khách đã xem, và cả FCM ở
    // nền trước — gộp nhịp 400ms. Nghe nó cũng chính là mở kênh của nó. Biên
    // nhận "đã xem" của một hội thoại KHÁC không còn kéo màn này tải lại, và
    // biên nhận của chính nó được vá tại chỗ chứ không qua đây.
    ref.listen<int>(threadSignalProvider(widget.conversationId), (
      previous,
      next,
    ) {
      if (previous == next) return;
      _refreshThread();
    });

    // Mỗi lần cửa sổ tin đổi (trang cũ tải thêm, refresh thay cả cửa sổ) là
    // một lần dọn key của tin không còn trên màn.
    ref.listen<AsyncValue<ThreadState>>(threadProvider(widget.conversationId), (
      previous,
      next,
    ) {
      final state = next.valueOrNull;
      if (state != null) _pruneMessageKeys(state);
    });

    final status =
        ref.watch(realtimeStatusProvider).valueOrNull ??
        RealtimeStatus.disabled;
    if (_realtime.setState(status)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startRealtimeFallback();
      });
    }

    final conversation = ref.watch(conversationProvider(widget.conversationId));
    final thread = ref.watch(threadProvider(widget.conversationId));
    final access = ref.watch(inboxAccessProvider);
    final policy = ref.watch(accessProvider);
    final canCreateTask = policy.can(TaskPermissions.write);
    final session = ref.watch(sessionProvider);
    final canCreateOpportunity =
        session.featureEnabled('opportunities') &&
        policy.can(OpportunityPermissions.create);
    final myUserId = session.user?.id;
    // Null = API cũ thiếu khoá: giữ chữ + ảnh, ẩn Tệp.
    final capabilities = conversation.valueOrNull?.outboundCapabilities;
    // Ghi âm chỉ khi kênh gửi được audio; API cũ (null) thì ẩn. Máy ghi chỉ
    // được tạo (và giữ) khi nút mic có mặt.
    final canVoice = access.canSend && (capabilities?.canSendVoice ?? false);
    // Tên người thả cảm xúc: danh bạ đội nếu ĐÃ nạp ở nơi khác (không kéo cả
    // danh bạ chỉ để mở một hội thoại), không thì tên server chụp lúc thả.
    // Theo dõi cờ "đã nạp": danh bạ nạp SAU khi mở (sheet Gán…) thì tên đổi
    // theo ngay. `exists` giữ cho trường hợp provider bị override.
    final directoryLoaded =
        ref.watch(teamDirectoryLoadedProvider) ||
        ref.exists(teamDirectoryProvider);
    final memberNames = directoryLoaded
        ? {
            for (final entry in ref.watch(teamMemberByIdProvider).entries)
              entry.key: entry.value.name,
          }
        : const <String, String>{};

    return Scaffold(
      // Bubbles can only read as raised against a tinted canvas. On white the
      // incoming (white) bubbles vanished into the page and the thread looked
      // like a flat document — the single biggest reason it did not feel like a
      // chat app.
      backgroundColor: OmniColors.chat(
        context,
        OmniColors.chatCanvas,
        OmniColors.chatCanvasDark,
      ),
      appBar: ThreadHeader(
        conversation: conversation.valueOrNull,
        onInfo: _openInfo,
        searchMode: _searchMode,
        searchController: _searchController,
        searchFocusNode: _searchFocusNode,
        searchResultCount: _searchResults.length,
        searchResultIndex: _searchResults.isEmpty ? 0 : _searchIndex,
        onSearchChanged: _search,
        onSearchPrevious: () => _moveSearch(-1),
        onSearchNext: () => _moveSearch(1),
        onCloseSearch: _closeSearch,
      ),
      body: SurfaceBackdrop(
        child: ComposerSnackBarScope(
          barKey: _bottomBarKey,
          child: Column(
            children: [
              Expanded(
                // No tint layer over the canvas: it fought the chat background and
                // washed the bubbles back down into the page.
                child: OmniAsyncView(
                  value: thread,
                  onRetry: () =>
                      ref.invalidate(threadProvider(widget.conversationId)),
                  isEmpty: (state) => state.isEmpty,
                  empty: const OmniEmptyState(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Chưa có tin nhắn',
                    message: 'Gửi tin đầu tiên để bắt đầu cuộc trò chuyện.',
                  ),
                  data: (state) => MediaReloadScope(
                    onLoadError: _onMediaLoadError,
                    onUserRetry: _onMediaUserRetry,
                    resolver: _mediaResolver,
                    child: _MessageList(
                      state: state,
                      controller: _scrollController,
                      conversation: conversation.valueOrNull,
                      // retry(), not send(): a fresh send would drop the reply the
                      // rep was answering, leave the failed bubble sitting below the
                      // new one, and — because it would carry a new idempotency key —
                      // deliver a second copy whenever the first attempt had in fact
                      // reached the server.
                      onRetry: _retry,
                      onDiscard: (message) => ref
                          .read(threadProvider(widget.conversationId).notifier)
                          .discard(message.id),
                      onReply: (message) =>
                          setState(() => _replyingTo = message),
                      // `/pin` cần `inbox.write`; null thì menu ẩn mục "Ghim".
                      onPin: access.canSend ? _togglePin : null,
                      onCreateTask: canCreateTask ? _createTaskFrom : null,
                      onCreateOpportunity: canCreateOpportunity
                          ? _createOpportunityFrom
                          : null,
                      // `team-reactions` cần `inbox.write`; cần biết tôi là ai
                      // để đảo đúng mục của mình.
                      onReact:
                          access.canReact &&
                              myUserId != null &&
                              myUserId.isNotEmpty
                          ? (message, emoji) => _react(
                              message,
                              emoji,
                              myUserId: myUserId,
                              myName: session.user?.fullName,
                            )
                          : null,
                      myUserId: myUserId,
                      myName: session.user?.fullName,
                      memberNames: memberNames,
                      keyForMessage: _keyForMessage,
                    ),
                  ),
                ),
              ),
              KeyedSubtree(
                key: _bottomBarKey,
                child: access.canSend && capabilities?.canSendText == false
                    ? const _ChannelCannotSendBar()
                    : access.canSend
                    ? MessageComposer(
                        replyTo: _replyingTo,
                        onCancelReply: () => setState(() => _replyingTo = null),
                        capabilities: capabilities,
                        errorText: _sendError,
                        onPickImages: (remaining) =>
                            _pickImages(remaining, capabilities),
                        onTakePhoto: () => _takePhoto(capabilities),
                        onPickFiles: _pickFiles,
                        onCreateTask: canCreateTask
                            ? () => context.pushNamed(
                                TaskRoutes.create,
                                extra: CreateTaskArgs(
                                  initialTitle: 'Liên hệ ${_customerName()}'
                                      .trim(),
                                ),
                              )
                            : null,
                        loadTemplates: _loadTemplates,
                        onSend: _sendWithAttachments,
                        voiceRecorder: canVoice
                            ? ref.watch(voiceRecorderProvider)
                            : null,
                        onSendVoice: canVoice
                            ? (voice) =>
                                  _sendWithAttachments('', [voice], _replyingTo)
                            : null,
                        warnVoiceAsLink:
                            capabilities?.audio == OutboundMode.link,
                      )
                    : _ReadOnlyBar(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Thanh dưới đáy (composer / dòng chỉ xem): snackbar nổi phía trên nó.
  final _bottomBarKey = GlobalKey(debugLabel: 'thread-bottom-bar');

  /// Tải từng tệp lên `POST /inbox/media` rồi gửi tin. Dùng cho cả composer
  /// (chữ + ảnh + tệp) lẫn ghi âm (một tệp `voice`, không chữ). `type` của
  /// tệp là cái server trả từ upload (MIME dò được), không đoán theo đuôi —
  /// bản ghi WAV về thành `audio`.
  Future<void> _sendWithAttachments(
    String text,
    List<PendingAttachment> attachments,
    Message? replyTo,
  ) async {
    final controller = ref.read(threadProvider(widget.conversationId).notifier);
    final api = ref.read(inboxApiProvider);
    if (_sendError != null) setState(() => _sendError = null);
    try {
      final upload = Future.wait(
        attachments.map((a) => api.uploadMedia(a.path, filename: a.name)),
      );
      await controller.sendAfterUpload(
        text,
        attachments: upload,
        replyTo: replyTo,
      );
    } on AppException catch (error) {
      if (error is ValidationException &&
          error.reason == kChannelSendUnsupported) {
        // Server không tạo tin: báo NGAY trong composer, nháp giữ nguyên
        // (composer giữ khi onSend ném).
        if (mounted) setState(() => _sendError = error.message);
      } else {
        _toast(error.message);
      }
      rethrow;
    } on Object {
      // Lỗi ngoài API (đọc tệp hỏng…): vẫn báo, và ném lại để composer giữ
      // chữ và khay ảnh (INB-I22).
      _toast('Không tải tệp lên được. Vui lòng thử lại.');
      rethrow;
    }
    if (mounted) setState(() => _replyingTo = null);
    _scrollToBottom();
  }

  /// Dọn theo cửa sổ đang hiển thị mỗi khi state đổi (xem [_pruneMessageKeys]);
  /// trước đây là một Map giữ key của mọi tin từng đi qua màn hình.
  final _messageKeys = MessageKeyRegistry();

  GlobalKey _keyForMessage(String id) => _messageKeys.keyFor(id);

  void _pruneMessageKeys(ThreadState state) {
    _messageKeys.prune({
      for (final message in state.visible) message.id,
      // Kết quả tìm kiếm cần key để cuộn tới, kể cả khi tin đó vừa được
      // mergeMessages vào cửa sổ.
      for (final message in _searchResults) message.id,
    });
  }

  void _openSearch() {
    setState(() => _searchMode = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _closeSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _searchMode = false;
      _searchResults = const [];
      _searchIndex = 0;
    });
  }

  void _search(String value) {
    _searchDebounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _searchResults = const [];
        _searchIndex = 0;
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 280), () async {
      try {
        final all = await ref
            .read(inboxApiProvider)
            .searchMessages(widget.conversationId, query);
        // Ghi chú nội bộ ẩn khỏi danh sách tin nên không có đích để cuộn tới.
        final found = all.where((m) => !m.isNote).toList();
        if (!mounted || _searchController.text.trim() != query) return;
        ref
            .read(threadProvider(widget.conversationId).notifier)
            .mergeMessages(found);
        setState(() {
          _searchResults = found;
          _searchIndex = 0;
        });
        _ensureSearchVisible();
      } on AppException catch (error) {
        if (mounted) _toast(error.message);
      }
    });
  }

  void _moveSearch(int delta) {
    if (_searchResults.isEmpty) return;
    setState(() {
      _searchIndex = (_searchIndex + delta) % _searchResults.length;
      if (_searchIndex < 0) _searchIndex = _searchResults.length - 1;
    });
    _ensureSearchVisible();
  }

  void _ensureSearchVisible() {
    if (_searchResults.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = _messageKeys.lookup(_searchResults[_searchIndex].id);
      final target = key?.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          duration: OmniMotion.of(context).base,
          curve: Curves.easeOut,
          alignment: 0.35,
        );
      }
    });
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: OmniMotion.of(context).base,
      curve: Curves.easeOut,
    );
  }

  Future<void> _togglePin(Message message) async {
    try {
      final pinned = await ref
          .read(threadProvider(widget.conversationId).notifier)
          .togglePin(message.id);
      if (mounted) {
        _toast(pinned ? 'Đã ghim tin nhắn.' : 'Đã bỏ ghim tin nhắn.');
      }
    } on AppException catch (error) {
      _toast(error.message);
    }
  }

  /// Thả / bỏ cảm xúc nội bộ. Bộ điều khiển cập nhật lạc quan và tự hoàn tác
  /// khi lỗi; ở đây chỉ báo. Messenger lấy TRƯỚC khi chờ.
  Future<void> _react(
    Message message,
    String emoji, {
    required String myUserId,
    String? myName,
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final controller = ref.read(threadProvider(widget.conversationId).notifier);
    try {
      await controller.toggleTeamReaction(
        message.id,
        emoji,
        myUserId: myUserId,
        myName: myName,
      );
    } on Object {
      if (!mounted) return;
      messenger?.showSnackBar(
        snackAboveBar(
          const Text('Không thả được cảm xúc. Vui lòng thử lại.'),
          barKey: _bottomBarKey,
        ),
      );
    }
  }

  /// Tiêu đề việc từ một tin: dòng đầu, tối đa 80 ký tự. Tin không có chữ
  /// (chỉ ảnh/tệp) thì để trống cho người dùng tự đặt.
  void _createTaskFrom(Message message) {
    final firstLine = message.text.trim().split('\n').first.trim();
    context.pushNamed(
      TaskRoutes.create,
      extra: CreateTaskArgs(
        initialTitle: firstLine.isEmpty
            ? null
            : firstLine.characters.take(80).toString(),
      ),
    );
  }

  void _createOpportunityFrom(Message message) {
    final customerId = ref
        .read(conversationProvider(widget.conversationId))
        .valueOrNull
        ?.customerId;
    context.pushNamed(
      OpportunityRoutes.create,
      queryParameters: {
        if (customerId != null && customerId.isNotEmpty) 'customer': customerId,
      },
    );
  }

  String _customerName() =>
      ref
          .read(conversationProvider(widget.conversationId))
          .valueOrNull
          ?.title ??
      '';

  /// Mẫu trả lời của tenant; chưa có (hoặc lỗi mạng) thì dùng bộ câu mở đầu
  /// mặc định — đừng để khay trống chỉ vì máy chủ chưa cấu hình.
  Future<List<String>> _loadTemplates() async {
    try {
      final replies = await ref.read(quickRepliesProvider.future);
      if (replies == null || replies.isEmpty) return _defaultTemplates;
      return [for (final q in replies) q.body];
    } catch (_) {
      return _defaultTemplates;
    }
  }

  /// "Gửi lại": tin đã có id server đi qua `/resend` (bộ điều khiển quyết).
  /// Quá hạn thì chỉ gửi thành tin MỚI khi người dùng đồng ý — khách có thể
  /// nhận lại phần đã tới.
  void _retry(Message message) {
    final controller = ref.read(threadProvider(widget.conversationId).notifier);
    unawaited(
      controller.retry(
        message,
        confirmNewSend: (serverMessage) async {
          if (!mounted) return false;
          return showOmniConfirm(
            context: context,
            title: 'Gửi thành tin mới?',
            message:
                '$serverMessage Gửi tin mới thì khách có thể nhận lại '
                'những phần đã tới.',
            confirmLabel: 'Gửi tin mới',
          );
        },
      ),
    );
  }

  Future<List<PendingAttachment>> _pickImages(
    int remaining,
    OutboundCapabilities? capabilities,
  ) async {
    final options = inboxImagePickOptions(capabilities);
    final picked = await ImagePicker().pickMultiImage(
      imageQuality: options.quality,
      maxWidth: options.maxDimension,
      maxHeight: options.maxDimension,
      // `limit` phải ≥ 2; composer vẫn tự cắt (có trình chọn bỏ qua nó).
      limit: remaining >= 2 ? remaining : null,
    );
    return [for (final x in picked) await _imageFrom(x)];
  }

  Future<PendingAttachment?> _takePhoto(
    OutboundCapabilities? capabilities,
  ) async {
    final options = inboxImagePickOptions(capabilities);
    final x = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: options.quality,
      maxWidth: options.maxDimension,
      maxHeight: options.maxDimension,
    );
    return x == null ? null : _imageFrom(x);
  }

  static Future<PendingAttachment> _imageFrom(XFile x) async {
    int? size;
    try {
      size = await x.length();
    } on Object {
      size = null; // không đọc được cỡ: để upload báo lỗi nếu có
    }
    return PendingAttachment(
      path: x.path,
      name: x.name,
      size: size,
      kind: PendingKind.image,
    );
  }

  /// Tài liệu qua `file_picker` (SAF trên Android, UIDocumentPicker trên iOS —
  /// không cần quyền bộ nhớ). Tệp không có đường dẫn (nhà cung cấp ảo) bị bỏ.
  Future<List<PendingAttachment>> _pickFiles(int remaining) async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: kInboxFileExtensions,
    );
    if (result == null) return const [];
    return [
      for (final f in result.files)
        if (f.path != null)
          PendingAttachment(
            path: f.path!,
            name: f.name,
            size: f.size,
            kind: PendingKind.file,
          ),
    ];
  }

  Future<void> _openInfo() async {
    final result = await context.pushNamed<ThreadInfoResult>(
      InboxRoutes.threadInfo,
      pathParameters: {'id': widget.conversationId},
    );
    if (result == ThreadInfoResult.search && mounted) _openSearch();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(snackAboveBar(Text(message), barKey: _bottomBarKey));
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.state,
    required this.controller,
    required this.conversation,
    required this.onRetry,
    required this.onDiscard,
    required this.onReply,
    required this.onPin,
    required this.onCreateTask,
    required this.onCreateOpportunity,
    required this.onReact,
    required this.myUserId,
    required this.myName,
    required this.memberNames,
    required this.keyForMessage,
  });

  final ThreadState state;
  final ScrollController controller;
  final Conversation? conversation;
  final void Function(Message message) onRetry;
  final void Function(Message message) onDiscard;
  final void Function(Message message) onReply;
  final void Function(Message message)? onPin;
  final void Function(Message message)? onCreateTask;
  final void Function(Message message)? onCreateOpportunity;
  final void Function(Message message, String emoji)? onReact;
  final String? myUserId;
  final String? myName;
  final Map<String, String> memberNames;
  final GlobalKey Function(String id) keyForMessage;

  @override
  Widget build(BuildContext context) {
    // Rendered bottom-up so new messages land where the eye already is and
    // loading history never shifts the viewport.
    // `visible` is history plus this device's outbox — a queued or failed
    // send is not in `messages` and would otherwise never render. It is sorted
    // once per state; indexing it from the end instead of `.reversed.toList()`
    // means this build copies nothing.
    final visible = state.visible
        .where((m) => !m.isNote)
        .toList(growable: false);
    final conversation = this.conversation;
    final showIntro =
        !state.hasMore && conversation != null && !conversation.isGroup;
    final isGroup = conversation?.isGroup ?? false;
    final count = visible.length;
    // The list runs newest→oldest: reversed index i is visible[count - 1 - i].
    Message? at(int reversedIndex) =>
        reversedIndex < 0 || reversedIndex >= count
        ? null
        : visible[count - 1 - reversedIndex];

    return ListView.builder(
      controller: controller,
      reverse: true,
      // Tight gutters: Zalo lets bubbles run close to both edges, which is what
      // makes the left/right split read at a glance.
      padding: const EdgeInsets.fromLTRB(8, OmniSpacing.lg, 8, OmniSpacing.md),
      itemCount: count + (state.hasMore ? 1 : 0) + (showIntro ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= count) {
          if (showIntro) return ThreadIntro(conversation: conversation);
          return const Padding(
            padding: EdgeInsets.all(OmniSpacing.lg),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final message = at(index)!;
        // Newest→oldest, so the *next* index is the earlier message.
        final earlier = at(index + 1);
        final later = at(index - 1);
        final needsDayHeader =
            message.sentAt != null &&
            (earlier?.sentAt == null ||
                !_sameDay(message.sentAt!, earlier!.sentAt!));

        // A run is consecutive messages from the same side with no day break
        // between them. Only the LAST of a run carries the avatar.
        final grouped =
            !needsDayHeader &&
            earlier != null &&
            earlier.isOutbound == message.isOutbound;
        final isLastInGroup =
            later == null || later.isOutbound != message.isOutbound;

        return KeyedSubtree(
          key: keyForMessage(message.id),
          child: Column(
            // Without this the Column defaults to centre, which collapsed to the
            // bubble's own width and parked every message in the middle of the
            // screen — the side a message is on is the whole point of a thread.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (needsDayHeader) _DaySeparator(date: message.sentAt!),
              MessageBubble(
                message: message,
                showSender: isGroup && !message.isOutbound && !grouped,
                groupedWithPrevious: grouped,
                isLastInGroup: isLastInGroup,
                // Kênh không có đường gửi đi: gửi lại không bao giờ được.
                onRetry:
                    message.status == DeliveryStatus.failed &&
                        !message.isChannelUnsupported
                    ? () => onRetry(message)
                    : null,
                onDiscard: message.status == DeliveryStatus.failed
                    ? () => onDiscard(message)
                    : null,
                onReply: () => onReply(message),
                onPin: onPin == null ? null : () => onPin!(message),
                onCreateTask: onCreateTask == null
                    ? null
                    : () => onCreateTask!(message),
                onCreateOpportunity: onCreateOpportunity == null
                    ? null
                    : () => onCreateOpportunity!(message),
                // Chỉ tin đã có id server: tin nháp chưa có gì để thả lên.
                onReact:
                    onReact == null ||
                        message.isPending ||
                        message.isNote ||
                        message.id.isEmpty
                    ? null
                    : (emoji) => onReact!(message, emoji),
                myUserId: myUserId,
                myName: myName,
                memberNames: memberNames,
              ),
            ],
          ),
        );
      },
    );
  }

  /// Ngày theo giờ VN như tiêu đề dải ngày (`Formatters.dayHeader`), không
  /// theo ngày UTC hay múi máy (APP-I14).
  bool _sameDay(DateTime a, DateTime b) => VnTime.day(a) == VnTime.day(b);
}

class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Mốc giờ trần, giữa: "09:40, HÔM NAY". Cỡ 12 (sàn đọc được của design
    // system; bản thiết kế ghi 10) w600 giãn chữ .5, lề trên 10 dưới 6.
    final color = OmniColors.byBrightness(
      context,
      const Color(0xFF8A95A8),
      scheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Center(
        child: Text(
          Formatters.threadStamp(date),
          style: OmniType.micro.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// Kênh của hội thoại không gửi tin đi được (`can_send:false` hoặc `text:
/// none`, vd TikTok): thay composer, cùng chỗ với [_ReadOnlyBar].
class _ChannelCannotSendBar extends StatelessWidget {
  const _ChannelCannotSendBar();

  @override
  Widget build(BuildContext context) => const _NoComposerBar(
    icon: Icons.block_rounded,
    text:
        'Kênh này chưa gửi tin được từ Hộp thư — hãy trả lời trên ứng dụng '
        'của kênh.',
  );
}

class _ReadOnlyBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const _NoComposerBar(
    icon: Icons.lock_outline_rounded,
    text: 'Bạn chỉ có quyền xem hội thoại này.',
  );
}

class _NoComposerBar extends StatelessWidget {
  const _NoComposerBar({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        OmniSpacing.lg,
        OmniSpacing.md,
        OmniSpacing.lg,
        OmniSpacing.md + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        border: Border(top: BorderSide(color: scheme.outline)),
      ),
      child: Row(
        children: [
          Icon(icon, size: OmniIconSize.sm, color: scheme.onSurfaceVariant),
          const SizedBox(width: OmniSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: OmniType.caption.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
