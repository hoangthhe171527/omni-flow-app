import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/config/app_config.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/modules/inbox/application/thread_controller.dart';
import 'package:omni_app/modules/inbox/data/inbox_api.dart';
import 'package:omni_app/modules/inbox/domain/message.dart';

/// The outbox has to survive the catch-up poll.
///
/// The thread polls for changes every 8 seconds and used to answer them with
/// `ref.invalidate(threadProvider(...))` — a full rebuild from the server. That
/// erased everything the server does not know about: a send that had failed and
/// was waiting for the rep to retry it simply disappeared, and the rep went on
/// believing the customer had been answered. It also threw away every older page
/// they had scrolled back through.
///
/// These tests hold the line that a refresh may only ever replace server
/// history, never the outbox.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeInboxApi api;
  late ProviderContainer container;

  setUp(() {
    api = _FakeInboxApi();
    container = ProviderContainer(
      overrides: [inboxApiProvider.overrideWithValue(api)],
    );
  });

  tearDown(() => container.dispose());

  /// Subscribes and waits for the first load. Called only after a test has set
  /// up `api`, because listening is what starts the build.
  Future<void> open() {
    // AutoDispose: without a listener the provider is torn down between reads.
    container.listen(threadProvider('c1'), (_, _) {});
    return container.read(threadProvider('c1').future);
  }

  ThreadController controller() =>
      container.read(threadProvider('c1').notifier);

  ThreadState read() => container.read(threadProvider('c1')).requireValue;

  group('a failed send', () {
    test('survives the refresh the catch-up poll triggers', () async {
      api.history = [_serverMessage('m1', 'Chào shop')];
      await open();

      api.failNextSend = true;
      await controller().send('Dạ em gửi ạ');

      final failed = read().pending.single;
      expect(failed.status, DeliveryStatus.failed);
      expect(failed.error, 'Không có kết nối mạng.');

      // The poll finds a new inbound message and refreshes.
      api.history = [
        _serverMessage('m1', 'Chào shop'),
        _serverMessage('m2', 'Alo shop ơi'),
      ];
      await controller().refresh();

      expect(
        read().pending.single.id,
        failed.id,
        reason: 'The failed send must still be there to retry.',
      );
      expect(read().messages.map((m) => m.id), ['m1', 'm2']);
      expect(read().visible, hasLength(3));
    });

    test('is rendered in time order alongside server history', () async {
      api.history = [_serverMessage('m1', 'Chào shop')];
      await open();
      api.failNextSend = true;
      await controller().send('Dạ em gửi ạ');

      // The day separators and sender grouping in the message list read
      // neighbouring entries, so `visible` has to be chronological.
      final times = read().visible.map((m) => m.sentAt!).toList();
      expect(times, orderedEquals(List.of(times)..sort()));
      expect(read().visible.last.status, DeliveryStatus.failed);
    });

    test('leaves the outbox once a retry succeeds', () async {
      await open();
      api.failNextSend = true;
      await controller().send('Dạ em gửi ạ');

      await controller().retry(read().pending.single);

      expect(read().pending, isEmpty);
      expect(read().messages.single.text, 'Dạ em gửi ạ');
    });
  });

  group('refresh', () {
    test('keeps older pages the rep scrolled back through', () async {
      api.history = [_serverMessage('m3', 'c'), _serverMessage('m4', 'd')];
      api.hasMore = true;
      await open();
      api.older = [_serverMessage('m1', 'a'), _serverMessage('m2', 'b')];
      await controller().loadOlder();
      expect(read().messages, hasLength(4));

      await controller().refresh();

      expect(read().messages.map((m) => m.id), [
        'm1',
        'm2',
        'm3',
        'm4',
      ], reason: 'A refresh must not collapse the thread back to one page.');
    });

    test('advances a delivery status that moved on the server', () async {
      api.history = [_serverMessage('m1', 'Hi', status: 'sent')];
      await open();
      expect(read().messages.single.status, DeliveryStatus.sent);

      api.history = [_serverMessage('m1', 'Hi', status: 'read')];
      await controller().refresh();

      expect(read().messages.single.status, DeliveryStatus.read);
    });

    test('restarts history when the page no longer overlaps', () async {
      // More arrived than one page holds — typically after a long offline
      // stretch. Merging would leave an invisible hole between the two blocks.
      api.history = [_serverMessage('m1', 'a')];
      await open();
      api.failNextSend = true;
      await controller().send('pending');

      api.history = [_serverMessage('m90', 'far later')];
      await controller().refresh();

      expect(read().messages.map((m) => m.id), ['m90']);
      expect(
        read().pending,
        hasLength(1),
        reason: 'The outbox is not history.',
      );
    });

    test(
      'does not resurrect a send that settled while it was in flight',
      () async {
        await open();

        // Hold the refresh open, let a send complete underneath it, then release.
        final gate = Completer<void>();
        api.holdNextFetch = gate;
        final refreshing = controller().refresh();
        await controller().send('Dạ em gửi ạ');
        expect(read().pending, isEmpty);
        gate.complete();
        await refreshing;

        expect(
          read().pending,
          isEmpty,
          reason: 'A pre-request snapshot must not be written back afterwards.',
        );
        expect(
          read().messages.single.text,
          'Dạ em gửi ạ',
          reason: 'Nor may the refresh drop what settled while it waited.',
        );
      },
    );

    test('an empty page leaves the thread alone', () async {
      // Nothing new arrived. That is not the same as a gap, and must not be
      // treated as one — blanking a thread the rep is reading is far worse than
      // showing history that is a few seconds stale.
      api.history = [_serverMessage('m1', 'a'), _serverMessage('m2', 'b')];
      await open();

      api.history = const [];
      await controller().refresh();

      expect(read().messages.map((m) => m.id), ['m1', 'm2']);
    });
  });
}

/// Server messages are minute-stamped from the digits in their id, so `m1`
/// always sorts before `m2` and a test can assert on order.
Message _serverMessage(String id, String text, {String status = 'sent'}) {
  final minute = int.parse(id.replaceAll(RegExp(r'\D'), ''));
  return Message.fromJson({
    'id': id,
    'from': 'customer',
    'text': text,
    'status': status,
    'sent_at': DateTime.utc(2026, 1, 1, 8, minute).toIso8601String(),
  });
}

/// Stands in for the HTTP layer. Subclasses the real client because the app
/// wires a concrete [InboxApi] rather than an interface; the [ApiClient] handed
/// to `super` is never used, since every method a test reaches is overridden.
class _FakeInboxApi extends InboxApi {
  _FakeInboxApi() : super(ApiClient(Dio()));

  List<Message> history = const [];
  List<Message> older = const [];
  bool hasMore = false;
  bool failNextSend = false;

  /// Blocks the next history fetch until completed, so a test can interleave.
  Completer<void>? holdNextFetch;

  int _sent = 0;

  @override
  Future<MessagePage> messages(
    String id, {
    String? before,
    int perPage = AppConfig.messagePageSize,
  }) async {
    final gate = holdNextFetch;
    if (gate != null) {
      holdNextFetch = null;
      await gate.future;
    }
    final isFirstPage = before == null;
    return MessagePage(
      // The API answers newest-first; the controller reverses it.
      messages: (isFirstPage ? history : older).reversed.toList(),
      cursor: CursorPage(
        perPage: perPage,
        hasMore: isFirstPage && hasMore,
        nextBefore: isFirstPage && hasMore ? 'cursor-1' : null,
      ),
    );
  }

  @override
  Future<Message> send(
    String id, {
    String? text,
    List<MessageAttachment> attachments = const [],
    String? replyToMessageId,
    String? clientMessageId,
  }) async {
    if (failNextSend) {
      failNextSend = false;
      throw const NetworkException('Không có kết nối mạng.');
    }
    return Message.fromJson({
      'id': 'srv-${++_sent}',
      'client_message_id': clientMessageId,
      'from': 'agent',
      'text': text,
      'status': 'sent',
      'sent_at': DateTime.utc(2026, 1, 1, 9, _sent).toIso8601String(),
    });
  }

  @override
  Future<Message> addNote(
    String id,
    String text, {
    String? clientMessageId,
  }) async {
    return Message.fromJson({
      'id': 'note-${++_sent}',
      'client_message_id': clientMessageId,
      'from': 'note',
      'text': text,
      'sent_at': DateTime.utc(2026, 1, 1, 9, _sent).toIso8601String(),
    });
  }
}
