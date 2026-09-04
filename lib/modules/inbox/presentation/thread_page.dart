import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../application/inbox_providers.dart';
import '../application/thread_controller.dart';
import '../data/inbox_api.dart';
import '../domain/conversation.dart';
import '../domain/message.dart';
import 'widgets/assign_sheet.dart';
import 'widgets/conversation_context_sheet.dart';
import 'widgets/message_bubble.dart';
import 'widgets/message_composer.dart';

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
  String? _syncCursor;
  bool _syncing = false;
  Timer? _searchDebounce;
  Message? _replyingTo;
  bool _searchMode = false;
  List<Message> _searchResults = const [];
  int _searchIndex = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addObserver(this);
    _startRealtimeFallback();
    // Opening a thread is the act of reading it.
    Future.microtask(() async {
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

  void _startRealtimeFallback() {
    _syncTimer ??= Timer.periodic(const Duration(seconds: 8), (_) {
      _catchUpChanges();
    });
  }

  Future<void> _catchUpChanges() async {
    if (!mounted || _syncing) return;
    _syncing = true;
    try {
      final changes = await ref.read(inboxApiProvider).changes(
        _syncCursor,
        conversationId: widget.conversationId,
      );
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
    ref.invalidate(threadProvider(widget.conversationId));
    ref.invalidate(conversationProvider(widget.conversationId));
    ref.invalidate(inboxFacetsProvider);
  }

  void _onScroll() {
    // The list is reversed, so "older" is at the far end of the scroll extent.
    if (_scrollController.position.extentAfter < 200) {
      ref.read(threadProvider(widget.conversationId).notifier).loadOlder();
    }
  }

  @override
  Widget build(BuildContext context) {
    // The inbox list already listens to the foreground push signal, but an
    // open thread must invalidate its own message provider too. Without this,
    // FCM shows the notification while the conversation remains stale until a
    // manual reload or the next fallback poll.
    ref.listen<int>(inboxRealtimeSignalProvider, (previous, next) {
      if (previous == next) return;
      _refreshThread();
    });

    final conversation = ref.watch(conversationProvider(widget.conversationId));
    final thread = ref.watch(threadProvider(widget.conversationId));
    final access = ref.watch(inboxAccessProvider);

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
      appBar: _ThreadAppBar(
        conversation: conversation.valueOrNull,
        onAssign: access.canAssign ? _assign : null,
        onInfo: _showContext,
        searchMode: _searchMode,
        searchController: _searchController,
        searchFocusNode: _searchFocusNode,
        searchResultCount: _searchResults.length,
        searchResultIndex: _searchResults.isEmpty ? 0 : _searchIndex,
        onSearch: _openSearch,
        onSearchChanged: _search,
        onSearchPrevious: () => _moveSearch(-1),
        onSearchNext: () => _moveSearch(1),
        onCloseSearch: _closeSearch,
      ),
      body: Column(
        children: [
          Expanded(
            // No tint layer over the canvas: it fought the chat background and
            // washed the bubbles back down into the page.
            child: OmniAsyncView(
              value: thread,
              onRetry: () =>
                  ref.invalidate(threadProvider(widget.conversationId)),
              isEmpty: (state) => state.messages.isEmpty,
              empty: const OmniEmptyState(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Chưa có tin nhắn',
                message: 'Gửi tin đầu tiên để bắt đầu cuộc trò chuyện.',
              ),
              data: (state) => _MessageList(
                state: state,
                controller: _scrollController,
                isGroup: conversation.valueOrNull?.isGroup ?? false,
                // retry(), not send(): a fresh send would drop the reply the
                // rep was answering, leave the failed bubble sitting below the
                // new one, and — because it would carry a new idempotency key —
                // deliver a second copy whenever the first attempt had in fact
                // reached the server.
                onRetry: (message) => ref
                    .read(threadProvider(widget.conversationId).notifier)
                    .retry(message),
                onDiscard: (message) => ref
                    .read(threadProvider(widget.conversationId).notifier)
                    .discard(message.id),
                onReply: (message) => setState(() => _replyingTo = message),
                onPin: _togglePin,
                keyForMessage: _keyForMessage,
              ),
            ),
          ),
          if (access.canSend)
            MessageComposer(
              canNote: access.canNote,
              suggestions: _suggestions(conversation.valueOrNull),
              replyTo: _replyingTo,
              onCancelReply: () => setState(() => _replyingTo = null),
              onPickImages: _pickImages,
              onTakePhoto: _takePhoto,
              onSend: (text, mode, images, replyTo) async {
                final controller = ref.read(
                  threadProvider(widget.conversationId).notifier,
                );
                if (mode == ComposeMode.note) {
                  await controller.addNote(text);
                } else {
                  try {
                    final upload = Future.wait(
                      images.map(
                        (image) => ref
                            .read(inboxApiProvider)
                            .uploadMedia(image.path, filename: image.name),
                      ),
                    );
                    await controller.sendAfterUpload(
                      text,
                      attachments: upload,
                      replyTo: replyTo,
                    );
                  } on AppException catch (error) {
                    _toast(error.message);
                    rethrow;
                  }
                }
                if (mounted) setState(() => _replyingTo = null);
                _scrollToBottom();
              },
            )
          else
            _ReadOnlyBar(),
        ],
      ),
    );
  }

  final Map<String, GlobalKey> _messageKeys = {};

  GlobalKey _keyForMessage(String id) =>
      _messageKeys.putIfAbsent(id, GlobalKey.new);

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
        final found = await ref.read(inboxApiProvider).searchMessages(
          widget.conversationId,
          query,
        );
        if (!mounted || _searchController.text.trim() != query) return;
        ref.read(threadProvider(widget.conversationId).notifier).mergeMessages(found);
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
      final key = _messageKeys[_searchResults[_searchIndex].id];
      final target = key?.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: 0.35,
        );
      }
    });
  }

  /// Rule-based, not generated: openers a rep would type anyway, offered as one
  /// tap. Deliberately generic — a wrong "smart" suggestion costs more trust
  /// than no suggestion.
  List<String> _suggestions(Conversation? conversation) {
    if (conversation == null) return const [];
    return const [
      'Dạ em chào anh/chị ạ!',
      'Cảm ơn anh/chị đã quan tâm.',
      'Anh/chị cho em xin số điện thoại để tư vấn nhé.',
      'Bên em đang có chương trình ưu đãi ạ.',
    ];
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 240),
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

  Future<List<XFile>> _pickImages() =>
      ImagePicker().pickMultiImage(imageQuality: 85);

  Future<XFile?> _takePhoto() =>
      ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85);

  Future<void> _assign() async {
    final conversation = ref
        .read(conversationProvider(widget.conversationId))
        .valueOrNull;
    final result = await showOmniSheet<AssignResult>(
      context: context,
      expand: true,
      builder: (_) => AssignSheet(currentAssigneeId: conversation?.assigneeId),
    );
    if (result == null) return;

    try {
      final updated = await ref
          .read(inboxApiProvider)
          .assign(widget.conversationId, result.assigneeId, note: result.note);
      ref.read(inboxListProvider.notifier).patch(updated);
      ref.invalidate(conversationProvider(widget.conversationId));
      _toast(result.assigneeId == null ? 'Đã bỏ gán.' : 'Đã gán hội thoại.');
    } on AppException catch (error) {
      _toast(error.message);
    }
  }

  void _showContext() {
    showOmniSheet(
      context: context,
      expand: true,
      builder: (_) =>
          ConversationContextSheet(conversationId: widget.conversationId),
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ThreadAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ThreadAppBar({
    required this.conversation,
    required this.onInfo,
    required this.searchMode,
    required this.searchController,
    required this.searchFocusNode,
    required this.searchResultCount,
    required this.searchResultIndex,
    required this.onSearch,
    required this.onSearchChanged,
    required this.onSearchPrevious,
    required this.onSearchNext,
    required this.onCloseSearch,
    this.onAssign,
  });

  final Conversation? conversation;
  final VoidCallback onInfo;
  final bool searchMode;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final int searchResultCount;
  final int searchResultIndex;
  final VoidCallback onSearch;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchPrevious;
  final VoidCallback onSearchNext;
  final VoidCallback onCloseSearch;
  final VoidCallback? onAssign;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppBar(
      toolbarHeight: 72,
      leadingWidth: 52,
      titleSpacing: 0,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: Border(
        bottom: BorderSide(color: scheme.outline.withValues(alpha: 0.72)),
      ),
      title: searchMode
          ? TextField(
              controller: searchController,
              focusNode: searchFocusNode,
              autofocus: true,
              onChanged: onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Tìm trong hội thoại',
                border: InputBorder.none,
                isDense: true,
                suffixText: searchResultCount == 0
                    ? null
                    : '${searchResultIndex + 1}/$searchResultCount',
              ),
            )
          : conversation == null
          ? const SizedBox.shrink()
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                conversation!.isGroup
                    ? OmniGroupAvatar(
                        names: conversation!.groupMembers
                            .map((m) => m.name ?? '?')
                            .toList(),
                        size: 40,
                      )
                    : OmniAvatar(
                        name: conversation!.title,
                        imageUrl: conversation!.customerAvatar,
                        size: 40,
                      ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        conversation!.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: OmniChatType.peer.copyWith(
                          fontSize: 16,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: OmniSourcePill(
                                channel: conversation!.channel,
                                accountName: conversation!.accountName,
                              ),
                            ),
                          ),
                          if (conversation!.lastMessageAt != null) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                Formatters.relative(
                                  conversation!.lastMessageAt,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: OmniChatType.meta.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
      actions: [
        if (searchMode) ...[
          IconButton(
            tooltip: 'Kết quả trước',
            onPressed: searchResultCount == 0 ? null : onSearchPrevious,
            icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 22),
          ),
          IconButton(
            tooltip: 'Kết quả sau',
            onPressed: searchResultCount == 0 ? null : onSearchNext,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 22),
          ),
          IconButton(
            tooltip: 'Đóng tìm kiếm',
            onPressed: onCloseSearch,
            icon: const Icon(Icons.close_rounded, size: 21),
          ),
          const SizedBox(width: 8),
        ] else ...[
        IconButton(
          tooltip: 'Tìm trong hội thoại',
          onPressed: onSearch,
          style: IconButton.styleFrom(
            foregroundColor: scheme.onSurfaceVariant,
            minimumSize: const Size(40, 40),
            maximumSize: const Size(40, 40),
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: const Icon(Icons.search_rounded, size: 21),
        ),
        // The phone number lives on the customer record, not the thread, so
        // "gọi" is offered in the context sheet where that data is loaded.
        if (onAssign != null)
          IconButton(
            tooltip: 'Gán nhân viên',
            onPressed: onAssign,
            style: IconButton.styleFrom(
              foregroundColor: scheme.onSurfaceVariant,
              minimumSize: const Size(40, 40),
              maximumSize: const Size(40, 40),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.person_add_alt_outlined, size: 21),
          ),
        IconButton(
          tooltip: 'Thông tin khách hàng',
          onPressed: onInfo,
          style: IconButton.styleFrom(
            foregroundColor: scheme.onSurfaceVariant,
            minimumSize: const Size(40, 40),
            maximumSize: const Size(40, 40),
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: const Icon(Icons.info_outline_rounded, size: 21),
        ),
        const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.state,
    required this.controller,
    required this.isGroup,
    required this.onRetry,
    required this.onDiscard,
    required this.onReply,
    required this.onPin,
    required this.keyForMessage,
  });

  final ThreadState state;
  final ScrollController controller;
  final bool isGroup;
  final void Function(Message message) onRetry;
  final void Function(Message message) onDiscard;
  final void Function(Message message) onReply;
  final void Function(Message message) onPin;
  final GlobalKey Function(String id) keyForMessage;

  @override
  Widget build(BuildContext context) {
    // Rendered bottom-up so new messages land where the eye already is and
    // loading history never shifts the viewport.
    final items = state.messages.reversed.toList();

    return ListView.builder(
      controller: controller,
      reverse: true,
      // Tight gutters: Zalo lets bubbles run close to both edges, which is what
      // makes the left/right split read at a glance.
      padding: const EdgeInsets.fromLTRB(8, OmniSpacing.lg, 8, OmniSpacing.md),
      itemCount: items.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= items.length) {
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

        final message = items[index];
        // `items` runs newest→oldest, so the *next* index is the earlier message.
        final earlier = index + 1 < items.length ? items[index + 1] : null;
        final later = index > 0 ? items[index - 1] : null;
        final needsDayHeader =
            message.sentAt != null &&
            (earlier?.sentAt == null ||
                !_sameDay(message.sentAt!, earlier!.sentAt!));

        // A run is consecutive messages from the same side with no day break
        // between them. Only the LAST of a run carries the avatar.
        final grouped =
            !needsDayHeader &&
            earlier != null &&
            earlier.isOutbound == message.isOutbound &&
            !earlier.isNote &&
            !message.isNote;
        final isLastInGroup =
            later == null ||
            later.isOutbound != message.isOutbound ||
            later.isNote;

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
              onRetry: message.status == DeliveryStatus.failed
                  ? () => onRetry(message)
                  : null,
              onDiscard: message.status == DeliveryStatus.failed
                  ? () => onDiscard(message)
                  : null,
              onReply: () => onReply(message),
              onPin: () => onPin(message),
            ),
          ],
          ),
        );
      },
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Bare centred text, like Zalo. The bordered pill was a third framed object
    // in a thread that had just had its frames removed, and at fontSize 10 the
    // label inside it was below every platform's readable floor.
    //
    // 20 above, 12 below: the gap belongs to the day that is STARTING, so the
    // separator sits closer to what it introduces than to what it closes.
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      child: Center(
        child: Text(
          Formatters.dayHeader(date),
          style: OmniChatType.meta.copyWith(
            color: scheme.onSurfaceVariant,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyBar extends StatelessWidget {
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
          Icon(
            Icons.lock_outline_rounded,
            size: 16,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: OmniSpacing.sm),
          Expanded(
            child: Text(
              'Bạn chỉ có quyền xem hội thoại này.',
              style: OmniType.caption.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
