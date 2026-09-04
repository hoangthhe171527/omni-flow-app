import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/utils/client_id.dart';
import 'package:omni_app/modules/inbox/domain/message.dart';

/// Not sending the customer the same message twice.
///
/// The app's receive timeout is 30s. On a flaky mobile network a send can time
/// out *after* the API accepted it: the bubble flips to `failed`, the rep taps
/// "Gửi lại", and without a stable idempotency key that retry is a brand new
/// send — the customer reads the message twice. These tests pin the rules that
/// decide what key a retry carries.
void main() {
  group('client id', () {
    test('is unique per message', () {
      final ids = {for (var i = 0; i < 500; i++) newClientId()};

      expect(ids.length, 500);
    });

    test('fits the 64-character cap the API validates against', () {
      expect(newClientId().length, lessThanOrEqualTo(64));
    });
  });

  group('optimistic bubble', () {
    test('is its own idempotency key until the server answers', () {
      final draft = Message.optimistic(text: 'Còn hàng không shop?');

      expect(draft.clientId, isNotNull);
      expect(draft.clientId, draft.id);
      expect(draft.isPending, isTrue);
      expect(draft.status, DeliveryStatus.queued);
    });

    test('reuses a key it is handed', () {
      final draft = Message.optimistic(text: 'Hi', clientId: 'cm-fixed');

      expect(draft.clientId, 'cm-fixed');
      expect(draft.id, 'cm-fixed');
    });

    test('two sends never share a key', () {
      final first = Message.optimistic(text: 'Hi');
      final second = Message.optimistic(text: 'Hi');

      expect(first.clientId, isNot(second.clientId));
    });
  });

  group('retry of a bubble the server never answered for', () {
    late Message failed;

    setUp(() {
      failed = Message.optimistic(
        text: 'Dạ bên em gửi ạ',
        replyTo: const Message(
          id: 'srv-1',
          author: MessageAuthor.customer,
          text: 'Cho mình hỏi giá',
          sentAt: null,
          senderName: 'Khách',
        ),
      ).copyWith(status: DeliveryStatus.failed, error: 'Hết thời gian chờ');
    });

    test('reuses the original key, because the outcome is unknown', () {
      // This is the whole defence: the first attempt may have been accepted and
      // only its response lost. Same key, so the API hands back the message it
      // already queued rather than queueing a second delivery.
      expect(failed.requeued().clientId, failed.clientId);
    });

    test('clears the previous failure reason and queues again', () {
      final retried = failed.requeued();

      expect(retried.status, DeliveryStatus.queued);
      expect(retried.error, isNull);
    });

    test('keeps the reply the rep was answering', () {
      final retried = failed.requeued();

      expect(retried.replyToMessageId, 'srv-1');
      expect(retried.replyToText, 'Cho mình hỏi giá');
      expect(retried.replyToAuthorName, 'Khách');
    });

    test('keeps its id equal to its key, so it replaces the failed bubble', () {
      final retried = failed.requeued();

      expect(retried.id, failed.id);
      expect(retried.isPending, isTrue);
    });
  });

  group('retry of a message the server did answer for', () {
    test('starts a new attempt instead of replaying a settled failure', () {
      // The server stored this one and the platform rejected it — that verdict
      // is final. Reusing the key would resolve to the same failure forever,
      // leaving a retry button that can never succeed.
      final rejected = Message.fromJson({
        'id': 'srv-9',
        'client_message_id': 'cm-original',
        'from': 'agent',
        'text': 'Hi',
        'status': 'failed',
        'error': 'Ngoài khung giờ chăm sóc',
      });

      expect(rejected.isPending, isFalse);
      expect(rejected.requeued().clientId, isNot('cm-original'));
      expect(rejected.requeued().status, DeliveryStatus.queued);
    });
  });

  group('parsing', () {
    test('reads the key the API echoes back', () {
      final message = Message.fromJson({
        'id': 'srv-1',
        'client_message_id': 'cm-abc',
        'from': 'agent',
        'text': 'Hi',
      });

      expect(message.clientId, 'cm-abc');
      expect(message.isPending, isFalse);
    });

    test('leaves inbound messages without a key', () {
      final message = Message.fromJson({
        'id': 'srv-2',
        'from': 'customer',
        'text': 'Hi',
      });

      expect(message.clientId, isNull);
      expect(message.isPending, isFalse);
    });
  });
}
