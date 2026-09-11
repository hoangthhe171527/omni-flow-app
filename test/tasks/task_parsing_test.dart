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

  group('ảnh người', () {
    // API gắn ảnh THẲNG HÀNG với `assignee_ids` (null cho người chưa có ảnh).
    // Đọc bằng `strList` sẽ nuốt null và làm lệch hàng — ảnh của Luận nhảy
    // sang mặt Hằng Ni. Nên có một hàm đọc riêng, và một bài kiểm cho nó.
    test('ảnh người nhận thẳng hàng với id, giữ chỗ null', () {
      final task = Task.fromJson({
        'id': 't1',
        'title': 'x',
        'assignee_ids': ['u1', 'u2', 'u3'],
        'assignee_names': ['Hằng Ni', 'Luận', 'Minh'],
        'assignee_avatars': ['https://x/hn.png', null, 'https://x/m.png'],
      });

      expect(task.assigneeAvatars, [
        'https://x/hn.png',
        null,
        'https://x/m.png',
      ]);
      expect(task.assigneeAvatarAt(0), 'https://x/hn.png');
      expect(task.assigneeAvatarAt(1), isNull);
      expect(task.assigneeAvatarAt(2), 'https://x/m.png');
    });

    test('API cũ không gửi mảng ảnh thì không ai có ảnh, không văng', () {
      final task = Task.fromJson({
        'id': 't1',
        'title': 'x',
        'assignee_ids': ['u1'],
        'assignee_names': ['Hằng Ni'],
      });

      expect(task.assigneeAvatarAt(0), isNull);
      expect(task.assigneeAvatarAt(7), isNull);
    });

    test('chuỗi rỗng đọc thành null, không thành thẻ ảnh trỏ vào hư không', () {
      final task = Task.fromJson({
        'id': 't1',
        'title': 'x',
        'assignee_ids': ['u1'],
        'assignee_avatars': [''],
      });

      expect(task.assigneeAvatarAt(0), isNull);
    });

    test('công đoạn, bình luận, người xem mang theo ảnh', () {
      final task = Task.fromJson({
        'id': 't1',
        'title': 'x',
        'checklist': [
          {
            'id': 's1',
            'title': 'Nắp phím',
            'assignee_id': 'u1',
            'assignee_name': 'Hằng Ni',
            'assignee_avatar': 'https://x/hn.png',
          },
        ],
        'comments': [
          {
            'id': 'c1',
            'body': 'QC trượt',
            'user_id': 'u1',
            'user_name': 'Hằng Ni',
            'user_avatar': 'https://x/hn.png',
          },
        ],
        'viewers': [
          {'user_id': 'u1', 'name': 'Hằng Ni', 'avatar': 'https://x/hn.png'},
        ],
      });

      expect(task.subtasks.single.assigneeAvatar, 'https://x/hn.png');
      expect(task.comments.single.userAvatar, 'https://x/hn.png');
      expect(task.viewers.single.avatar, 'https://x/hn.png');
    });

    test('copyWith giữ nguyên mảng ảnh', () {
      // Tick một việc con đi qua copyWith; bản đầu của copyWith từng làm rơi
      // ba trường. Ảnh không được là trường thứ tư.
      final task = Task.fromJson({
        'id': 't1',
        'title': 'x',
        'assignee_ids': ['u1'],
        'assignee_avatars': ['https://x/hn.png'],
      });

      expect(task.copyWith(status: 'done').assigneeAvatars, [
        'https://x/hn.png',
      ]);
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
