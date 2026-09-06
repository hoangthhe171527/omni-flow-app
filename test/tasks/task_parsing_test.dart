import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';

/// Reading what the API actually sends, and the arithmetic the card leads with.
///
/// Tasks come out of a schema-less Mongo collection, so almost any field can be
/// missing and the same fact can arrive under more than one key. Progress is
/// the number a worker opens the app to see, so getting it wrong is not a
/// cosmetic bug.
void main() {
  group('progress', () {
    test('counts finished stages against the total', () {
      final task = Task.fromJson({
        'id': 't1',
        'title': 'KAWAI HAT-5 2308512',
        'checklist': [
          {'id': 'a', 'title': 'Lấy đàn ra', 'done': true},
          {'id': 'b', 'title': 'Body', 'done': false},
          {'id': 'c', 'title': 'Nắp phím', 'done': true},
          {'id': 'd', 'title': 'Bộ máy', 'done': false},
        ],
      });

      expect(task.doneCount, 2);
      expect(task.totalCount, 4);
      expect(task.progress, 0.5);
    });

    test('a task with no stages is 0, not a division by zero', () {
      // A NaN here renders as a broken progress bar rather than an empty one.
      final task = Task.fromJson({'id': 't1', 'title': 'x'});

      expect(task.totalCount, 0);
      expect(task.progress, 0);
      expect(task.hasSubtasks, isFalse);
    });
  });

  group('deadline', () {
    test('reads due_date, and falls back to the older deadline key', () {
      // Both keys exist in the collection. Reading only one is how a whole
      // column silently shows "no date".
      expect(
        Task.fromJson({'id': 't1', 'due_date': '2026-09-10'}).dueDate,
        isNotNull,
      );
      expect(
        Task.fromJson({'id': 't1', 'deadline': '2026-09-10'}).dueDate,
        isNotNull,
      );
    });

    test('overdue is measured in whole days, not hours', () {
      // A task due today at 09:00 is not overdue at 10:00 to somebody standing
      // at a workbench.
      final today = DateTime.now();
      final task = Task.fromJson({
        'id': 't1',
        'due_date': DateTime(
          today.year,
          today.month,
          today.day,
          9,
        ).toIso8601String(),
      });

      expect(task.isOverdue, isFalse);
      expect(task.isDueToday, isTrue);
    });

    test('counts the days a task is late', () {
      final task = Task.fromJson({
        'id': 't1',
        'due_date': DateTime.now()
            .subtract(const Duration(days: 2))
            .toIso8601String(),
      });

      expect(task.daysOverdue, 2);
      expect(task.isOverdue, isTrue);
    });

    test('a finished task is never overdue', () {
      // Nagging somebody about work they already did is the fastest way to
      // teach them to ignore the app.
      final task = Task.fromJson({
        'id': 't1',
        'status': 'done',
        'due_date': DateTime.now()
            .subtract(const Duration(days: 5))
            .toIso8601String(),
      });

      expect(task.isOverdue, isFalse);
      expect(task.daysOverdue, isNull);
    });
  });

  group('subtasks', () {
    test('carry their own owner and date', () {
      // The workshop assigns stages, not whole pianos: "Nắp phím (Hằng Ni)".
      final task = Task.fromJson({
        'id': 't1',
        'checklist': [
          {
            'id': 'a',
            'title': 'Nắp phím',
            'done': false,
            'assignee_id': 'u-2',
            'assignee_name': 'Hằng Ni',
            'due_date': '2026-09-08',
          },
        ],
      });

      final subtask = task.subtasks.single;
      expect(subtask.title, 'Nắp phím');
      expect(subtask.assigneeId, 'u-2');
      expect(subtask.assigneeName, 'Hằng Ni');
      expect(subtask.dueDate, isNotNull);
    });

    test('an unassigned stage parses without an owner', () {
      // Unclaimed stages are normal — the workshop is pull-based.
      final task = Task.fromJson({
        'id': 't1',
        'checklist': [
          {'id': 'a', 'title': 'Body', 'done': false},
        ],
      });

      expect(task.subtasks.single.assigneeId, isNull);
    });
  });

  group('resilience', () {
    test('an almost-empty document still parses', () {
      // Mongo is schema-less and old rows predate most of these fields. A
      // missing key must not take the whole list down.
      final task = Task.fromJson({'id': 't1'});

      expect(task.id, 't1');
      expect(task.title, '');
      expect(task.status, 'todo');
      expect(task.assigneeIds, isEmpty);
      expect(task.subtasks, isEmpty);
    });

    test('only "done" counts as finished', () {
      // Every other status id is defined by the project, so a hardcoded list
      // of "closed" states would be wrong per tenant.
      expect(Task.fromJson({'id': 't', 'status': 'done'}).isDone, isTrue);
      expect(Task.fromJson({'id': 't', 'status': 'review'}).isDone, isFalse);
    });
  });
}
