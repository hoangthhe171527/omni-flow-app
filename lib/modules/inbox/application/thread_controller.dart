import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/error/crash_reporting.dart';
import '../data/inbox_api.dart';
import '../domain/message.dart';
import 'inbox_providers.dart';

class ThreadState {
  ThreadState({
    this.messages = const [],
    this.pending = const [],
    this.hasMore = false,
    this.nextBefore,
    this.loadingOlder = false,
  });

  /// Server-owned history, oldest first. A refresh replaces this wholesale.
  final List<Message> messages;

  /// This device's outbox: sends the server has not confirmed yet — queued,
  /// waiting on an upload, or failed and awaiting a retry.
  ///
  /// Deliberately NOT part of [messages]. The catch-up poll refreshes history
  /// every few seconds, and anything living in that list is replaced by whatever
  /// the server returns. A failed send silently vanishing while the rep still
  /// believes it went out is the worst thing this screen can do, so the outbox
  /// is kept somewhere a refresh structurally cannot reach.
  final List<Message> pending;

  final bool hasMore;
  final String? nextBefore;
  final bool loadingOlder;

  /// What the thread renders: history plus this device's outbox, in time order.
  ///
  /// Chronological rather than outbox-last because the day separators and the
  /// same-sender grouping in the message list both read neighbouring entries and
  /// assume the list is ordered.
  ///
  /// Tính MỘT lần cho mỗi state (memo `late final`), không phải getter:
  /// `_MessageList` đọc nó trong `build`, và trang chat dựng lại theo từng phím
  /// gõ vào composer — một getter là copy + sort lại cả cửa sổ tin nhắn mỗi
  /// frame để ra cùng một kết quả. Vì thế constructor không còn `const`; đổi
  /// lấy đúng một lần sort cho mỗi lần state đổi. Unmodifiable để không ai sửa
  /// tại chỗ thứ đã được cache.
  ///
  /// Bản đang gửi có `clientId` trùng một tin đã có trong lịch sử thì bỏ: luồng
  /// tải lại (realtime `message.sent`) có thể về TRƯỚC phản hồi POST, và cùng
  /// một tin không được hiện hai bong bóng (Đợt 7 P3).
  late final List<Message> visible = List<Message>.unmodifiable(
    _withQuotes(<Message>[...messages, ..._notYetInHistory(messages, pending)])
      ..sort(ThreadController.compareMessages),
  );

  static Iterable<Message> _notYetInHistory(
    List<Message> messages,
    List<Message> pending,
  ) {
    if (pending.isEmpty) return pending;
    final settled = {
      for (final m in messages)
        if (m.clientId != null && m.clientId!.isNotEmpty) m.clientId,
    };
    if (settled.isEmpty) return pending;
    return pending.where((m) => !settled.contains(m.clientId));
  }

  /// API chỉ trả `reply_to_message_id`; câu trích dẫn lấy từ tin gốc nếu nó
  /// đang có trên màn (backlog report #2). Tin gốc chưa tải thì không có câu —
  /// như web.
  static List<Message> _withQuotes(List<Message> all) {
    final byId = {for (final m in all) m.id: m};
    return [
      for (final m in all)
        if (m.replyToMessageId != null &&
            (m.replyToText ?? '').isEmpty &&
            byId[m.replyToMessageId] != null)
          m.copyWith(
            replyToText: byId[m.replyToMessageId]!.text,
            replyToAuthorName:
                byId[m.replyToMessageId]!.senderName ??
                byId[m.replyToMessageId]!.agentName,
          )
        else
          m,
    ];
  }

  bool get isEmpty => messages.isEmpty && pending.isEmpty;

  ThreadState copyWith({
    List<Message>? messages,
    List<Message>? pending,
    bool? hasMore,
    String? nextBefore,
    bool? loadingOlder,
  }) {
    return ThreadState(
      messages: messages ?? this.messages,
      pending: pending ?? this.pending,
      hasMore: hasMore ?? this.hasMore,
      nextBefore: nextBefore ?? this.nextBefore,
      loadingOlder: loadingOlder ?? this.loadingOlder,
    );
  }
}

/// One chat thread: history paging plus sending.
///
/// Sends are optimistic — the bubble appears immediately as `queued`, then
/// resolves to the server's message or flips to `failed` with the reason the
/// platform gave. A rep must never be left wondering whether a message went out.
class ThreadController
    extends AutoDisposeFamilyAsyncNotifier<ThreadState, String> {
  /// True once this build has been torn down. A send can outlive the screen it
  /// was started from (the rep backs out while the request is in flight), and
  /// writing `state` after disposal throws.
  bool _disposed = false;

  @override
  Future<ThreadState> build(String conversationId) async {
    _disposed = false;
    ref.onDispose(() => _disposed = true);

    final page = await ref.watch(inboxApiProvider).messages(conversationId);
    return ThreadState(
      // The API returns newest-first; the thread reads oldest-first.
      messages: page.messages.reversed.toList(),
      hasMore: page.cursor.hasMore,
      nextBefore: page.cursor.nextBefore,
    );
  }

  /// Pulls the newest page and merges it into history, leaving the outbox and
  /// the already-loaded older pages alone.
  ///
  /// This is what the catch-up poll calls. It used to call
  /// `ref.invalidate(threadProvider(...))`, which rebuilt from scratch every few
  /// seconds and threw away everything the server does not know about: the
  /// outbox (so a failed send disappeared before the rep could retry it), every
  /// older page the rep had scrolled back through, and — when a send was in
  /// flight — the notifier that send was about to write its result to.
  Future<void> refresh() async {
    final page = await ref.read(inboxApiProvider).messages(arg);
    if (_disposed) return;

    // Read state AFTER the request, not before: a send can settle while this is
    // in flight, and writing back a pre-request snapshot would put the bubble
    // back in the outbox after it had already moved into history.
    final current = state.valueOrNull;
    final fresh = page.messages.reversed.toList();
    final history = current?.messages ?? const <Message>[];

    // If nothing in the fresh page is already on screen, more messages arrived
    // than one page holds — typically after a long offline stretch. Merging
    // would leave an invisible hole between the old history and the new page, so
    // start the window over from what the server just returned.
    //
    // An EMPTY page is not that case, and must not be read as one: it means
    // nothing new arrived, so the answer is the history already held. Treating
    // it as a gap would blank a thread the rep is looking at.
    final known = history.map((message) => message.id).toSet();
    final overlaps =
        history.isEmpty ||
        fresh.isEmpty ||
        fresh.any((message) => known.contains(message.id));

    if (!overlaps) {
      state = AsyncData(
        ThreadState(
          messages: fresh,
          pending: current?.pending ?? const [],
          hasMore: page.cursor.hasMore,
          nextBefore: page.cursor.nextBefore,
        ),
      );
      return;
    }

    // Fresh copies win, so a status that advanced server-side (sent → delivered
    // → read) lands on the message already on screen.
    final byId = <String, Message>{
      for (final message in [...history, ...fresh]) message.id: message,
    };

    state = AsyncData(
      ThreadState(
        messages: byId.values.toList()..sort(compareMessages),
        pending: current?.pending ?? const [],
        // Keep the paging cursor: the loaded window reaches further back than
        // this page does, and resetting it would re-fetch history already held.
        hasMore: current?.hasMore ?? page.cursor.hasMore,
        nextBefore: current?.nextBefore ?? page.cursor.nextBefore,
      ),
    );
  }

  /// Lấy lại bản mới của MỌI tin đang giữ, khi link media đã ký hết hạn
  /// (MS-I24: server ký URL ảnh 12 giờ lúc trả tin).
  ///
  /// [refresh] chỉ gộp trang mới nhất — ảnh hết hạn lại nằm ở các trang cũ đã
  /// tải từ lâu. Còn `ref.invalidate` dựng lại từ đầu: mất outbox (tin gửi hỏng
  /// đang chờ gửi lại) và các trang cũ đang xem. Nên ở đây đi từ trang mới
  /// nhất lùi dần tới trang chứa tin cũ nhất đang giữ, bản mới thắng; outbox
  /// và con trỏ phân trang giữ nguyên.
  Future<void> reloadMedia() async {
    final current = state.valueOrNull;
    if (current == null || current.messages.isEmpty) return;
    final oldest = current.messages.first;
    final api = ref.read(inboxApiProvider);

    final fresh = <Message>[];
    String? before;
    // Trần số trang: cửa sổ giữ trên máy không bao giờ lớn tới mức này.
    for (var pages = 0; pages < 20; pages++) {
      final page = await api.messages(arg, before: before);
      if (_disposed) return;
      fresh.addAll(page.messages);
      // Tới tin cũ nhất đang giữ — theo id, hoặc theo giờ khi tin đó đã bị
      // xoá phía server (không thì đi hết trần trang mới dừng).
      final reachedOldest = page.messages.any(
        (m) => m.id == oldest.id || compareMessages(m, oldest) <= 0,
      );
      if (reachedOldest ||
          !page.cursor.hasMore ||
          page.cursor.nextBefore == null) {
        break;
      }
      before = page.cursor.nextBefore;
    }

    // Đọc state SAU khi tải, như refresh(): một lượt gửi có thể đã xong.
    final latest = state.valueOrNull ?? current;
    // Không nới cửa sổ về phía cũ: tin cũ hơn tin cũ nhất đang giữ để
    // loadOlder() lấy theo con trỏ như thường, khỏi lặp hay hở.
    final byId = <String, Message>{
      for (final message in latest.messages) message.id: message,
      for (final message in fresh)
        if (compareMessages(message, oldest) >= 0) message.id: message,
    };
    state = AsyncData(
      latest.copyWith(messages: byId.values.toList()..sort(compareMessages)),
    );
  }

  Future<void> loadOlder() async {
    final current = state.valueOrNull;
    if (current == null ||
        !current.hasMore ||
        current.loadingOlder ||
        current.nextBefore == null) {
      return;
    }

    state = AsyncData(current.copyWith(loadingOlder: true));
    try {
      final page = await ref
          .read(inboxApiProvider)
          .messages(arg, before: current.nextBefore);
      if (_disposed) return;
      // Re-read for the same reason refresh() does: a send may have settled
      // while this page was loading.
      final latest = state.valueOrNull;
      if (latest == null) return;
      final byId = <String, Message>{
        for (final message in [...page.messages.reversed, ...latest.messages])
          message.id: message,
      };
      state = AsyncData(
        latest.copyWith(
          messages: byId.values.toList()..sort(compareMessages),
          hasMore: page.cursor.hasMore,
          nextBefore: page.cursor.nextBefore,
          loadingOlder: false,
        ),
      );
    } catch (_) {
      if (_disposed) return;
      final latest = state.valueOrNull;
      if (latest == null) return;
      state = AsyncData(latest.copyWith(loadingOlder: false));
    }
  }

  Future<void> send(
    String text, {
    List<MessageAttachment> attachments = const [],
    Message? replyTo,
  }) {
    final draft = Message.optimistic(
      text: text,
      attachments: attachments,
      replyTo: replyTo,
    );
    return _dispatch(
      draft: draft,
      surfaceUnsupported: true,
      call: () => ref
          .read(inboxApiProvider)
          .send(
            arg,
            text: text,
            attachments: attachments,
            replyToMessageId: replyTo?.id,
            clientMessageId: draft.clientId,
          ),
    );
  }

  /// Sends a failed bubble again.
  ///
  /// Tin server ĐÃ lưu rồi mới hỏng (id server, nằm trong lịch sử) đi qua
  /// `POST …/resend`: server mở lại chính tin đó và chỉ gửi phần chưa tới
  /// khách — gửi một tin mới sẽ gửi lại cả những tệp khách đã nhận. Quá hạn
  /// (`message_too_old_to_resend`) hay server không còn tin đó thì lùi về
  /// đường cũ.
  ///
  /// Đường cũ (bong bóng chưa từng có id server): the retried bubble replaces
  /// the failed one in place rather than being appended: two bubbles for one
  /// message is exactly the confusion a rep cannot afford, and the old one
  /// carried a failure reason that no longer applies. [Message.requeued]
  /// decides whether the original idempotency key is reused — see it for why
  /// that is not unconditional.
  ///
  /// [confirmNewSend] chỉ được hỏi khi `/resend` trả 422
  /// `message_too_old_to_resend`: gửi thành tin MỚI thì khách có thể nhận lại
  /// những phần đã tới, nên phải có người đồng ý. Null hoặc trả false → tin
  /// vẫn `failed` với câu của server.
  Future<void> retry(
    Message failed, {
    Future<bool> Function(String serverMessage)? confirmNewSend,
  }) {
    final stored =
        !failed.isPending &&
        (state.valueOrNull?.messages.any((m) => m.id == failed.id) ?? false);
    if (stored) return _resend(failed, confirmNewSend);
    return _sendAgain(failed);
  }

  Future<void> _resend(
    Message failed,
    Future<bool> Function(String serverMessage)? confirmNewSend,
  ) async {
    _replaceStored(failed.id, failed.copyWith(status: DeliveryStatus.queued));
    try {
      final reopened = await ref.read(inboxApiProvider).resend(arg, failed.id);
      if (_disposed) return;
      _replaceStored(failed.id, reopened);
    } on MessageNotFailedException catch (conflict) {
      if (_disposed) return;
      // 409 `message_not_failed`: một lượt khác vừa mở lại (hay đã gửi được)
      // tin này. KHÔNG BAO GIỜ gửi tin mới ở đây: đó là gửi trùng.
      final current = conflict.current;
      if (current != null) {
        // Server gửi kèm tin hiện tại: thay bong bóng, khỏi tải lại.
        _replaceStored(failed.id, current);
        return;
      }
      // Không có tin kèm: trả bong bóng về như trước (không kẹt "đang gửi"
      // nếu tải lại lỗi) rồi lấy trạng thái thật từ server.
      _replaceStored(failed.id, failed);
      try {
        await refresh();
      } on Object {
        // Lượt poll sau sẽ đồng bộ; vẫn không gửi gì thêm.
      }
    } on ValidationException catch (error) {
      if (_disposed) return;
      // 422 `channel_send_unsupported` cũng rơi vào đây: tin mang mã đó nên
      // bong bóng không còn "Gửi lại".
      _replaceStored(failed.id, _failedAgain(failed, error));
      if (error.reason == kChannelSendUnsupported) {
        _refreshCapabilities();
      }
      if (error.reason != kResendTooOld || confirmNewSend == null) return;
      final ok = await confirmNewSend(error.message);
      if (!ok || _disposed) return;
      // Tin cũ (đã hỏng, quá hạn) rời lịch sử; tin mới thay chỗ nó.
      return _sendAgain(failed);
    } on NotFoundException catch (error) {
      if (_disposed) return;
      // Không có route `/resend` (API chưa cập nhật): gửi theo đường cũ.
      if (error.routeMissing) return _sendAgain(failed);
      // 404 thật: tin không còn trên server. Câu server là tiếng Anh.
      _replaceStored(
        failed.id,
        failed.copyWith(
          status: DeliveryStatus.failed,
          error: kResendMessageGone,
        ),
      );
    } on AppException catch (error) {
      if (_disposed) return;
      _replaceStored(failed.id, _failedAgain(failed, error));
    } on Object {
      // Lỗi ngoài API (phản hồi hỏng…): đừng để bong bóng kẹt "đang gửi".
      if (_disposed) return;
      _replaceStored(failed.id, failed);
    }
  }

  /// Server nói kênh không gửi được (422 `channel_send_unsupported`): khả
  /// năng gửi đã đổi so với lúc mở hội thoại. Nạp lại hội thoại để trang thay
  /// composer bằng dòng "Kênh này chưa gửi tin được".
  void _refreshCapabilities() {
    if (!_disposed) ref.invalidate(conversationProvider(arg));
  }

  static Message _failedAgain(Message failed, AppException error) =>
      failed.copyWith(
        status: DeliveryStatus.failed,
        error: error.message,
        errorCode: error is ValidationException ? error.reason : null,
      );

  /// Thay tại chỗ một tin trong lịch sử (không đụng hộp gửi đi).
  void _replaceStored(String id, Message next) {
    if (_disposed) return;
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        messages: [
          for (final item in current.messages) item.id == id ? next : item,
        ],
      ),
    );
  }

  /// Tin [messageId] trên màn thành `failed` với lý do từ realtime
  /// (`message.sent` của worker mang `error`/`error_code`). False khi tin
  /// chưa tải — lượt tải sau đã mang lý do.
  bool applyFailure(String messageId, String? error, String? errorCode) {
    if (_disposed) return false;
    final current = state.valueOrNull;
    if (current == null) return false;
    if (!current.messages.any((m) => m.id == messageId)) return false;
    state = AsyncData(
      current.copyWith(
        messages: [
          for (final item in current.messages)
            item.id == messageId
                ? item.copyWith(
                    status: DeliveryStatus.failed,
                    error: error,
                    errorCode: errorCode,
                  )
                : item,
        ],
      ),
    );
    return true;
  }

  Future<void> _sendAgain(Message failed) {
    final draft = failed.requeued();
    return _dispatch(
      draft: draft,
      replacing: failed.id,
      call: () => ref
          .read(inboxApiProvider)
          .send(
            arg,
            text: draft.text,
            attachments: draft.attachments,
            replyToMessageId: draft.replyToMessageId,
            clientMessageId: draft.clientId,
          ),
    );
  }

  /// Shows the outgoing bubble immediately while large attachments upload.
  /// The resolved server message replaces the temporary bubble once the upload
  /// URLs are ready, so the composer never feels frozen behind network I/O.
  ///
  /// Hai bước (INB-I22). Upload lỗi nghĩa là CHƯA gửi gì: rút bong bóng và ném
  /// lại, để composer giữ chữ lẫn khay ảnh và trang chat báo lý do. Trước đây
  /// bản nháp không có ảnh và lỗi upload bị [_dispatch] nuốt: composer xoá
  /// khay, còn "Gửi lại" gửi body rỗng và nhận 422 mãi. Lỗi ở bước GỬI (sau
  /// khi upload xong) vẫn thành bong bóng `failed` như cũ — lúc đó bong bóng
  /// mang URL ảnh thật của server, nên "Gửi lại" gửi đủ ảnh.
  Future<void> sendAfterUpload(
    String text, {
    required Future<List<MessageAttachment>> attachments,
    Message? replyTo,
  }) async {
    final draft = Message.optimistic(text: text, replyTo: replyTo);
    _enqueue(draft); // bong bóng "đang gửi" hiện ngay như trước
    final List<MessageAttachment> uploaded;
    try {
      uploaded = await attachments;
    } on Object {
      discard(draft.id);
      rethrow;
    }
    return _dispatch(
      draft: draft.copyWith(attachments: uploaded),
      replacing: draft.id,
      surfaceUnsupported: true,
      call: () => ref
          .read(inboxApiProvider)
          .send(
            arg,
            text: text,
            attachments: uploaded,
            replyToMessageId: replyTo?.id,
            clientMessageId: draft.clientId,
          ),
    );
  }

  Future<bool> togglePin(String messageId) async {
    final current = state.valueOrNull;
    if (current == null) return false;
    // Only server-stored messages can be pinned; an outbox entry has no id the
    // API would recognise.
    final exists = current.messages.any((item) => item.id == messageId);
    if (!exists) return false;

    final pinned = await ref.read(inboxApiProvider).togglePin(arg, messageId);
    if (_disposed) return pinned;
    final latest = state.valueOrNull;
    if (latest == null) return pinned;

    state = AsyncData(
      latest.copyWith(
        messages: [
          for (final item in latest.messages)
            item.id == messageId ? item.copyWith(pinned: pinned) : item,
        ],
      ),
    );
    return pinned;
  }

  /// Thả / bỏ / đổi cảm xúc NỘI BỘ của tôi trên một tin (không gửi cho khách).
  ///
  /// Lạc quan: bỏ mục của tôi, rồi thêm [emoji] nếu nó khác emoji cũ của tôi
  /// (server cũng đảo y như vậy). Server trả lời thì danh sách server THAY
  /// danh sách lạc quan; lỗi thì trả lại danh sách cũ rồi ném tiếp để màn
  /// báo. Tin nháp (chưa có id server) hay không có trên màn thì bỏ qua.
  Future<void> toggleTeamReaction(
    String messageId,
    String emoji, {
    required String myUserId,
    String? myName,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final message = current.messages
        .where((item) => item.id == messageId)
        .firstOrNull;
    if (message == null || message.isPending) return;

    final before = message.teamReactions;
    final mine = before.where((r) => r.userId == myUserId).firstOrNull;
    final optimistic = [
      for (final r in before)
        if (r.userId != myUserId) r,
      if (mine?.emoji != emoji)
        TeamReaction(
          userId: myUserId,
          userName: myName,
          emoji: emoji,
          at: DateTime.now(),
        ),
    ];
    // Số thứ tự lượt bấm theo tin: phản hồi (hay lỗi) của lượt CŨ về sau một
    // lượt mới thì bỏ — không đè trạng thái mới hơn.
    final seq = (_reactionSeq[messageId] ?? 0) + 1;
    _reactionSeq[messageId] = seq;
    // Mốc hoàn tác: mục của tôi TRƯỚC lượt đang chờ đầu tiên (không phải
    // trước lượt này — lúc đó nó đã là kết quả lạc quan của lượt trước).
    final pending = _reactionPending[messageId] ?? 0;
    if (pending == 0) {
      _reactionBaseline[messageId] = mine;
      _reactionLatestFailed.remove(messageId);
    }
    _reactionPending[messageId] = pending + 1;
    applyTeamReactions(messageId, optimistic);

    final List<TeamReaction> saved;
    try {
      saved = await ref
          .read(inboxApiProvider)
          .toggleTeamReaction(arg, messageId, emoji);
    } on Object {
      final latest = _reactionSeq[messageId] == seq;
      if (!_disposed && latest) {
        // Chỉ trả lại mục CỦA TÔI: cảm xúc người khác về qua realtime trong
        // lúc chờ vẫn giữ.
        _restoreMine(messageId, myUserId, _reactionBaseline[messageId]);
        _reactionLatestFailed.add(messageId);
      }
      _settleReaction(messageId);
      rethrow;
    }
    // Server đã ghi lượt này: mốc hoàn tác của các lượt sau là kết quả thật.
    final confirmed = saved.where((r) => r.userId == myUserId).firstOrNull;
    _reactionBaseline[messageId] = confirmed;
    final latest = _reactionSeq[messageId] == seq;
    final latestFailed = _reactionLatestFailed.contains(messageId);
    _settleReaction(messageId);
    if (_disposed) return;
    if (latest) {
      applyTeamReactions(messageId, saved);
    } else if (latestFailed) {
      // Lượt mới hơn đã lỗi và đã hoàn tác về mốc cũ; lượt cũ này thì server
      // đã ghi — hiện đúng mục server có.
      _restoreMine(messageId, myUserId, confirmed);
    }
  }

  void _settleReaction(String messageId) {
    final left = (_reactionPending[messageId] ?? 1) - 1;
    if (left > 0) {
      _reactionPending[messageId] = left;
      return;
    }
    _reactionPending.remove(messageId);
    _reactionBaseline.remove(messageId);
    _reactionLatestFailed.remove(messageId);
  }

  final _reactionSeq = <String, int>{};
  final _reactionPending = <String, int>{};
  final _reactionBaseline = <String, TeamReaction?>{};
  final _reactionLatestFailed = <String>{};

  void _restoreMine(String messageId, String myUserId, TeamReaction? mine) {
    final current = state.valueOrNull?.messages
        .where((m) => m.id == messageId)
        .firstOrNull;
    if (current == null) return;
    applyTeamReactions(messageId, [
      for (final r in current.teamReactions)
        if (r.userId != myUserId) r,
      ?mine,
    ]);
  }

  /// Thay cảm xúc nội bộ của một tin đang có trên màn (phản hồi POST hoặc
  /// realtime `message.team_reaction`). Tin chưa tải thì trả `false`: lượt
  /// tải lịch sử sau đã mang sẵn danh sách mới.
  bool applyTeamReactions(String messageId, List<TeamReaction> reactions) {
    if (_disposed) return false;
    final current = state.valueOrNull;
    if (current == null) return false;
    if (!current.messages.any((item) => item.id == messageId)) return false;
    state = AsyncData(
      current.copyWith(
        messages: [
          for (final item in current.messages)
            item.id == messageId
                ? item.copyWith(teamReactions: reactions)
                : item,
        ],
      ),
    );
    return true;
  }

  /// Applies a realtime delivery receipt (`message.status`) in place.
  ///
  /// A receipt changes one field of one message already on screen; refetching
  /// a whole page of history for that was the single most frequent pointless
  /// request an open thread made. Returns false when the receipt could NOT be
  /// applied — the message is not loaded, or [wireStatus] is not a delivery
  /// state (`recalled` changes content, not delivery) — so the caller falls
  /// back to a refetch instead of silently dropping it.
  bool applyStatus(String messageId, String wireStatus) {
    final status = Message.parseStatus(wireStatus);
    if (status == DeliveryStatus.none) return false;
    final current = state.valueOrNull;
    if (current == null) return false;
    final index = current.messages.indexWhere((item) => item.id == messageId);
    if (index < 0) return false;

    // Receipts can arrive out of order; "đã xem" must not step back to "đã
    // nhận". Handled (true) rather than refetched: the screen is already ahead.
    final before = _deliveryRank(current.messages[index].status);
    final after = _deliveryRank(status);
    if (before > 0 && after > 0 && after < before) return true;

    state = AsyncData(
      current.copyWith(
        messages: [
          for (final item in current.messages)
            item.id == messageId ? item.copyWith(status: status) : item,
        ],
      ),
    );
    return true;
  }

  static int _deliveryRank(DeliveryStatus status) => switch (status) {
    DeliveryStatus.sent => 1,
    DeliveryStatus.delivered => 2,
    DeliveryStatus.read => 3,
    _ => 0,
  };

  void mergeMessages(List<Message> found) {
    final current = state.valueOrNull;
    if (current == null || found.isEmpty) return;
    final byId = <String, Message>{
      for (final message in [...current.messages, ...found])
        message.id: message,
    };
    state = AsyncData(
      current.copyWith(messages: byId.values.toList()..sort(compareMessages)),
    );
  }

  static int compareMessages(Message a, Message b) {
    final left = a.sentAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final right = b.sentAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return left.compareTo(right);
  }

  /// Puts [draft] in the outbox, then swaps in whatever the server answers.
  ///
  /// [replacing] is the id of an outbox entry this attempt supersedes (a failed
  /// one being retried); leave it null to add a new entry.
  ///
  /// [surfaceUnsupported] (tin MỚI): 422 `channel_send_unsupported` nghĩa là
  /// server không tạo tin — rút bong bóng và ném lại, để composer giữ nháp và
  /// hiện câu của server. Bong bóng "Gửi lại" không bao giờ thành công thì
  /// không có ích gì.
  Future<void> _dispatch({
    required Message draft,
    required Future<Message> Function() call,
    String? replacing,
    bool surfaceUnsupported = false,
  }) async {
    _enqueue(draft, replacing: replacing);

    try {
      _settle(draft.id, await call());
    } on ValidationException catch (error) {
      if (error.reason == kChannelSendUnsupported) _refreshCapabilities();
      if (surfaceUnsupported && error.reason == kChannelSendUnsupported) {
        discard(draft.id);
        rethrow;
      }
      _fail(
        draft.id,
        error.message,
        errorCode: error.reason == kChannelSendUnsupported
            ? kChannelSendUnsupported
            : null,
      );
    } on AppException catch (error) {
      _fail(draft.id, error.message);
    } on Object catch (error, stackTrace) {
      // Anything that is not an AppException is a bug, not a network condition
      // — but it must still land the bubble on `failed`. Letting it escape left
      // the bubble on "đang gửi" with no error and no retry, which reads to the
      // rep as "sent". The exception is still surfaced for a crash reporter to
      // pick up rather than swallowed.
      _fail(draft.id, 'Không gửi được. Vui lòng thử lại.');
      CrashReporting.recordHandled(
        error,
        stackTrace,
        reason: 'inbox: sending a message',
      );
    }
  }

  /// Đưa [draft] vào hộp gửi đi (phần đầu của [_dispatch]), thay bản có id
  /// [replacing] nếu có.
  void _enqueue(Message draft, {String? replacing}) {
    final current = state.valueOrNull ?? ThreadState();
    final superseded = replacing ?? draft.id;
    state = AsyncData(
      current.copyWith(
        pending: [
          for (final message in current.pending)
            if (message.id != superseded) message,
          draft,
        ],
        // A retry of a message the server had already stored and rejected drops
        // the settled failure from history; the new attempt stands in for it.
        messages: [
          for (final message in current.messages)
            if (message.id != superseded) message,
        ],
      ),
    );
  }

  /// The send succeeded: move the bubble out of the outbox and into history.
  void _settle(String draftId, Message resolved) {
    if (_disposed) return;
    final current = state.valueOrNull;
    if (current == null) return;

    final draft = current.pending.cast<Message?>().firstWhere(
      (message) => message?.id == draftId,
      orElse: () => null,
    );

    // The API does not echo quoted-reply metadata for every channel, so carry
    // over what the draft knew rather than losing the quote on resolution.
    final saved = draft != null && resolved.replyToMessageId == null
        ? resolved.copyWith(
            replyToMessageId: draft.replyToMessageId,
            replyToText: draft.replyToText,
            replyToAuthorName: draft.replyToAuthorName,
          )
        : resolved;

    final byId = <String, Message>{
      for (final message in [...current.messages, saved]) message.id: message,
    };

    state = AsyncData(
      current.copyWith(
        messages: byId.values.toList()..sort(compareMessages),
        pending: [
          for (final message in current.pending)
            if (message.id != draftId) message,
        ],
      ),
    );
  }

  /// The send failed: keep the bubble in the outbox, carrying the reason.
  void _fail(String draftId, String reason, {String? errorCode}) {
    if (_disposed) return;
    final current = state.valueOrNull;
    if (current == null) return;

    state = AsyncData(
      current.copyWith(
        pending: [
          for (final message in current.pending)
            if (message.id == draftId)
              message.copyWith(
                status: DeliveryStatus.failed,
                error: reason,
                errorCode: errorCode,
              )
            else
              message,
        ],
      ),
    );
  }

  /// Drops a failed bubble the rep chose not to retry.
  void discard(String messageId) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        pending: [
          for (final message in current.pending)
            if (message.id != messageId) message,
        ],
        messages: [
          for (final message in current.messages)
            if (message.id != messageId) message,
        ],
      ),
    );
  }
}

final threadProvider =
    AutoDisposeAsyncNotifierProvider.family<
      ThreadController,
      ThreadState,
      String
    >(ThreadController.new);
