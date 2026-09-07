import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/plans/domain/feed_entry.dart';
import 'package:omni_app/modules/plans/domain/feed_group.dart';

/// Gộp hoạt động của cùng một cây đàn, nhưng chỉ khi chúng KỀ NHAU.
void main() {
  var seq = 0;

  FeedEntry on(
    String taskId, {
    String title = '',
    String type = 'section_id',
  }) => FeedEntry.fromJson({
    'id': 'a${seq++}',
    'type': type,
    'task_id': taskId,
    'task_title': title.isEmpty ? 'Cây $taskId' : title,
    'created_at': '2026-09-07T08:00:00Z',
    'user_name': 'Hằng Ni',
  });

  test('nhiều hoạt động của một cây đàn gộp thành một khối', () {
    // Một cây qua tay nhiều người trong một buổi. Để rời thì tên cây lặp lại
    // năm bảy lần liền nhau và màn hình đọc thành cuốn sổ, không phải tóm tắt.
    final groups = FeedGroup.from([on('t1'), on('t1'), on('t1')]);

    expect(groups.length, 1);
    expect(groups.first.entries.length, 3);
    expect(groups.first.taskId, 't1');
  });

  test('cây khác nhau thì khối khác nhau', () {
    final groups = FeedGroup.from([on('t1'), on('t2'), on('t3')]);

    expect(groups.length, 3);
  });

  test('CHỈ gộp những dòng kề nhau', () {
    // t1 xuất hiện hai lần, cách nhau bởi t2. Gộp chúng lại sẽ kéo dòng cũ
    // của t1 lên nằm trên dòng mới hơn của t2 — tức nói sai thứ tự việc đã xảy
    // ra, đúng thứ một dòng thời gian không được phép sai.
    final groups = FeedGroup.from([on('t1'), on('t2'), on('t1')]);

    expect(groups.map((g) => g.taskId).toList(), ['t1', 't2', 't1']);
    expect(groups.every((g) => g.entries.length == 1), isTrue);
  });

  test('dòng không biết thuộc cây nào thì đứng riêng', () {
    // Gộp chúng lại tạo ra một khối giả gồm những việc không liên quan.
    final groups = FeedGroup.from([on(''), on(''), on('')]);

    expect(groups.length, 3);
  });

  test('rỗng ra rỗng', () {
    expect(FeedGroup.from([]), isEmpty);
  });

  test('giữ nguyên thứ tự hoạt động trong khối', () {
    // Khối đứng ở chỗ của dòng MỚI NHẤT, và dòng đó phải nằm trên cùng.
    final first = on('t1', type: 'subtask_completed');
    final second = on('t1', type: 'attachment_added');

    final groups = FeedGroup.from([first, second]);

    expect(groups.first.entries.first.kind, FeedKind.subtaskCompleted);
    expect(groups.first.entries.last.kind, FeedKind.attachmentAdded);
    expect(groups.first.at, first.at);
  });

  test('tiêu đề khối lấy từ dòng đầu tiên của nó', () {
    final groups = FeedGroup.from([
      on('t1', title: 'KAWAI HAT-5 — SN 2308512'),
      on('t1', title: 'KAWAI HAT-5 — SN 2308512'),
    ]);

    expect(groups.first.taskTitle, 'KAWAI HAT-5 — SN 2308512');
  });
}
