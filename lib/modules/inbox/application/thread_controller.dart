import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/error/crash_reporting.dart';
import '../data/inbox_api.dart';
import '../domain/message.dart';

class ThreadState {
  const ThreadState({
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
  List<Message> get visible =>
      [...messages, ...pending]..sort(ThreadController.compareMessages);

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
  /// The retried bubble replaces the failed one in place rather than being
  /// appended: two bubbles for one message is exactly the confusion a rep cannot
  /// afford, and the old one carried a failure reason that no longer applies.
  /// [Message.requeued] decides whether the original idempotency key is reused —
  /// see it for why that is not unconditional.
  Future<void> retry(Message failed) {
    final draft = failed.requeued();
    if (draft.isNote) {
      return _dispatch(
        draft: draft,
        replacing: failed.id,
        call: () => ref
            .read(inboxApiProvider)
            .addNote(arg, draft.text, clientMessageId: draft.clientId),
      );
    }
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
  Future<void> sendAfterUpload(
    String text, {
    required Future<List<MessageAttachment>> attachments,
    Message? replyTo,
  }) {
    final draft = Message.optimistic(text: text, replyTo: replyTo);
    return _dispatch(
      draft: draft,
      call: () async => ref
          .read(inboxApiProvider)
          .send(
            arg,
            text: text,
            attachments: await attachments,
            replyToMessageId: replyTo?.id,
            clientMessageId: draft.clientId,
          ),
    );
  }

  Future<void> addNote(String text) {
    final draft = Message.optimistic(text: text, asNote: true);
    return _dispatch(
      draft: draft,
      call: () => ref
          .read(inboxApiProvider)
          .addNote(arg, text, clientMessageId: draft.clientId),
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
  Future<void> _dispatch({
    required Message draft,
    required Future<Message> Function() call,
    String? replacing,
  }) async {
    final current = state.valueOrNull ?? const ThreadState();
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

    try {
      _settle(draft.id, await call());
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
  void _fail(String draftId, String reason) {
    if (_disposed) return;
    final current = state.valueOrNull;
    if (current == null) return;

    state = AsyncData(
      current.copyWith(
        pending: [
          for (final message in current.pending)
            if (message.id == draftId)
              message.copyWith(status: DeliveryStatus.failed, error: reason)
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
