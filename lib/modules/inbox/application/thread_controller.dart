import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../data/inbox_api.dart';
import '../domain/message.dart';

class ThreadState {
  const ThreadState({
    this.messages = const [],
    this.hasMore = false,
    this.nextBefore,
    this.loadingOlder = false,
  });

  /// Oldest first — the order the thread renders in.
  final List<Message> messages;
  final bool hasMore;
  final String? nextBefore;
  final bool loadingOlder;

  ThreadState copyWith({
    List<Message>? messages,
    bool? hasMore,
    String? nextBefore,
    bool? loadingOlder,
  }) {
    return ThreadState(
      messages: messages ?? this.messages,
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
  @override
  Future<ThreadState> build(String conversationId) async {
    final page = await ref.watch(inboxApiProvider).messages(conversationId);
    return ThreadState(
      // The API returns newest-first; the thread reads oldest-first.
      messages: page.messages.reversed.toList(),
      hasMore: page.cursor.hasMore,
      nextBefore: page.cursor.nextBefore,
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
      final byId = <String, Message>{
        for (final message in [...page.messages.reversed, ...current.messages])
          message.id: message,
      };
      state = AsyncData(
        ThreadState(
          messages: byId.values.toList()
            ..sort(_compareMessages),
          hasMore: page.cursor.hasMore,
          nextBefore: page.cursor.nextBefore,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(loadingOlder: false));
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
  /// appended: two bubbles for one message is exactly the confusion a rep
  /// cannot afford, and the old one carried a failure reason that no longer
  /// applies. [Message.requeued] decides whether the original idempotency key is
  /// reused — see it for why that is not unconditional.
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
      call: () async => ref.read(inboxApiProvider).send(
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
    final message = current?.messages.firstWhere(
      (item) => item.id == messageId,
      orElse: () => throw StateError('Message not found'),
    );
    if (message == null) return false;

    final pinned = await ref.read(inboxApiProvider).togglePin(arg, messageId);
    final latest = state.valueOrNull;
    if (latest != null) {
      state = AsyncData(
        latest.copyWith(
          messages: [
            for (final item in latest.messages)
              item.id == messageId ? item.copyWith(pinned: pinned) : item,
          ],
        ),
      );
    }
    return pinned;
  }

  void mergeMessages(List<Message> found) {
    final current = state.valueOrNull;
    if (current == null || found.isEmpty) return;
    final byId = <String, Message>{
      for (final message in [...current.messages, ...found]) message.id: message,
    };
    final merged = byId.values.toList()..sort(_compareMessages);
    state = AsyncData(current.copyWith(messages: merged));
  }

  static int _compareMessages(Message a, Message b) {
    final left = a.sentAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final right = b.sentAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return left.compareTo(right);
  }

  /// Shows [draft] immediately, then swaps in whatever the server answers.
  ///
  /// [replacing] is the id of a bubble this attempt supersedes (a failed one
  /// being retried); leave it null to append.
  Future<void> _dispatch({
    required Message draft,
    required Future<Message> Function() call,
    String? replacing,
  }) async {
    final current = state.valueOrNull ?? const ThreadState();
    final superseded = replacing ?? draft.id;
    final messages = [
      for (final message in current.messages)
        if (message.id != superseded) message,
      draft,
    ];
    state = AsyncData(current.copyWith(messages: messages));

    try {
      final saved = await call();
      _replace(draft.id, saved);
    } on AppException catch (error) {
      _replace(
        draft.id,
        draft.copyWith(status: DeliveryStatus.failed, error: error.message),
      );
    }
  }

  void _replace(String localId, Message resolved) {
    final current = state.valueOrNull;
    if (current == null) return;
    final draft = current.messages.cast<Message?>().firstWhere(
      (message) => message?.id == localId,
      orElse: () => null,
    );
    final saved = draft != null && resolved.replyToMessageId == null
        ? resolved.copyWith(
            replyToMessageId: draft.replyToMessageId,
            replyToText: draft.replyToText,
            replyToAuthorName: draft.replyToAuthorName,
          )
        : resolved;
    state = AsyncData(
      current.copyWith(
        messages: [
          for (final message in current.messages)
            if (message.id == localId) saved else message,
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
        messages: current.messages
            .where((message) => message.id != messageId)
            .toList(),
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
