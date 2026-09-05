import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/notifications/application/push_notifications.dart';

/// Where a tapped push lands.
///
/// The payload is written by the server and arrives from outside the app, so
/// this is also the boundary where a malformed or unknown message has to stop
/// being anything at all. Nothing here may throw: the alternative is a crash on
/// launch when the OS hands the app a notification it does not understand.
void main() {
  group('the four types the server sends', () {
    test('an inbox message opens its conversation', () {
      final intent = PushIntent.fromData({
        'type': 'inbox_message',
        'conversation_id': 'c-1',
      });

      expect(intent, isNotNull);
      expect(intent!.target, PushTarget.conversation);
      expect(intent.id, 'c-1');
    });

    test('being given work opens that task', () {
      final intent = PushIntent.fromData({
        'type': 'task_assigned',
        'task_id': 't-1',
      });

      expect(intent!.target, PushTarget.task);
      expect(intent.id, 't-1');
    });

    test('an open stage opens the task it belongs to', () {
      // Not the subtask: a stage is not a screen of its own, and the worker
      // needs the surrounding work to decide whether to take it.
      final intent = PushIntent.fromData({
        'type': 'task_stage_open',
        'task_id': 't-1',
        'subtask_id': 's-2',
      });

      expect(intent!.target, PushTarget.task);
      expect(intent.id, 't-1');
    });

    test('a completion opens the finished task', () {
      final intent = PushIntent.fromData({
        'type': 'task_completed',
        'task_id': 't-1',
      });

      expect(intent!.target, PushTarget.task);
      expect(intent.id, 't-1');
    });
  });

  group('anything else is nothing', () {
    test('a type this build does not know resolves to null', () {
      // A newer server may send types this app has never heard of. The tap
      // does nothing, which is the correct outcome — it must not crash, and it
      // must not guess a destination.
      expect(
        PushIntent.fromData({'type': 'piano_delivered', 'order_id': 'o-1'}),
        isNull,
      );
    });

    test('a known type with no id resolves to null', () {
      // Navigating to /tasks/ lands on a broken screen.
      expect(PushIntent.fromData({'type': 'task_assigned'}), isNull);
      expect(
        PushIntent.fromData({'type': 'task_assigned', 'task_id': ''}),
        isNull,
      );
      expect(PushIntent.fromData({'type': 'inbox_message'}), isNull);
    });

    test('an empty or typeless payload resolves to null', () {
      expect(PushIntent.fromData(const {}), isNull);
      expect(PushIntent.fromData({'task_id': 't-1'}), isNull);
    });

    test('a non-string id is read rather than rejected', () {
      // FCM flattens every value to a string in transit, but a locally shown
      // notification round-trips through JSON and can keep a number.
      final intent = PushIntent.fromData({
        'type': 'task_assigned',
        'task_id': 12345,
      });

      expect(intent!.id, '12345');
    });
  });

  group('what a foreground message refreshes', () {
    test('only an inbox push refreshes the inbox', () {
      // A task notification arriving while the app is open must not trigger an
      // inbox refetch; that was a pointless request on every assignment.
      expect(
        PushIntent.fromData({
          'type': 'inbox_message',
          'conversation_id': 'c-1',
        })!.target,
        PushTarget.conversation,
      );
      expect(
        PushIntent.fromData({
          'type': 'task_assigned',
          'task_id': 't-1',
        })!.target,
        isNot(PushTarget.conversation),
      );
    });
  });
}
