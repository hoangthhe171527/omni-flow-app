import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/tasks/application/task_controller.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';

/// A tick that has not reached the server yet.
///
/// The workshop has poor wifi and a worker ticks a stage with dirty hands and
/// walks away. Two failures matter here and neither looks like a crash: the box
/// springing back under their hand, and a failed tick disappearing on the next
/// refresh while they believe the stage is done. The second one is how a piano
/// gets skipped.
///
/// This is the same shape as the inbox outbox, for the same reason.
void main() {
  Task taskWith(List<Map<String, dynamic>> checklist) => Task.fromJson({
    'id': 't1',
    'title': 'KAWAI HAT-5 2308512',
    'checklist': checklist,
  });

  final base = taskWith([
    {'id': 'a', 'title': 'Body', 'done': false},
    {'id': 'b', 'title': 'Nắp phím', 'done': false},
  ]);

  group('what the screen shows', () {
    test('a pending tick is applied on top of the server copy', () {
      // The box moves immediately. Waiting for a round trip on workshop wifi
      // makes the app feel broken.
      final state = TaskDetailState(
        task: base,
        pending: const [
          PendingTick(subtaskId: 'a', done: true, clientRequestId: 'c1'),
        ],
      );

      expect(state.visible.subtasks[0].done, isTrue);
      expect(state.visible.doneCount, 1);
      expect(
        state.task.subtasks[0].done,
        isFalse,
        reason: 'server copy is untouched',
      );
    });

    test('a failed tick keeps showing what the worker chose', () {
      // Reverting under their hand reads as "it saved then unsaved". The row
      // has to keep their state and say it did not go through.
      final state = TaskDetailState(
        task: base,
        pending: const [
          PendingTick(
            subtaskId: 'a',
            done: true,
            clientRequestId: 'c1',
            error: 'Không có kết nối mạng',
          ),
        ],
      );

      expect(state.visible.subtasks[0].done, isTrue);
      expect(state.pendingFor('a')!.failed, isTrue);
    });

    test('with nothing pending it is exactly the server copy', () {
      expect(TaskDetailState(task: base).visible.doneCount, 0);
    });
  });

  group('surviving a refresh', () {
    test('a failed tick is not wiped by fresh server data', () {
      // This is the whole point of keeping the outbox outside the task. A
      // refresh replaces the server's copy every time realtime fires; anything
      // living inside it would be gone before the worker could retry.
      const failed = PendingTick(
        subtaskId: 'a',
        done: true,
        clientRequestId: 'c1',
        error: 'Hết thời gian chờ',
      );
      final before = TaskDetailState(task: base, pending: const [failed]);

      final afterRefresh = TaskDetailState(
        task: taskWith([
          {'id': 'a', 'title': 'Body', 'done': false},
          {'id': 'b', 'title': 'Nắp phím', 'done': true},
        ]),
        pending: before.pending,
      );

      expect(afterRefresh.pendingFor('a')!.failed, isTrue);
      expect(
        afterRefresh.visible.subtasks[0].done,
        isTrue,
        reason: 'still theirs',
      );
      expect(
        afterRefresh.visible.subtasks[1].done,
        isTrue,
        reason: 'and the new server fact',
      );
    });
  });

  group('idempotency', () {
    test('a retry reuses the key of the attempt it retries', () {
      // A stage counted twice moves the monthly piano count the team bonus is
      // paid on, so a repeat has to resolve to the same completion.
      const first = PendingTick(
        subtaskId: 'a',
        done: true,
        clientRequestId: 'c1',
        error: 'Hết thời gian chờ',
      );

      final retried = PendingTick(
        subtaskId: first.subtaskId,
        done: first.done,
        clientRequestId: first.clientRequestId,
      );

      expect(retried.clientRequestId, 'c1');
      expect(
        retried.failed,
        isFalse,
        reason: 'the old reason no longer applies',
      );
    });
  });

  group('discarding', () {
    test('dropping a failed tick returns the row to the server state', () {
      final state = TaskDetailState(
        task: base,
        pending: const [
          PendingTick(
            subtaskId: 'a',
            done: true,
            clientRequestId: 'c1',
            error: 'x',
          ),
        ],
      );

      final dropped = state.copyWith(pending: const []);

      expect(dropped.visible.subtasks[0].done, isFalse);
      expect(dropped.pendingFor('a'), isNull);
    });
  });
}
