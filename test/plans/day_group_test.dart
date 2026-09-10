import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/plans/domain/day_group.dart';
import 'package:omni_app/modules/plans/domain/feed_entry.dart';

/// Dòng việc trả lời "HÔM NAY ai xong cái gì".
///
/// Bản trước gom theo CÂY ĐÀN, nên để biết hôm nay xưởng làm được bao nhiêu
/// thì phải tự cộng lại trong đầu qua nhiều thẻ. Gom theo ngày là đổi câu hỏi
/// màn hình trả lời, không phải đổi cách sắp xếp.
void main() {
  FeedEntry entry(String id, FeedKind kind, String day) =>
      FeedEntry(id: id, kind: kind, taskId: 't-1', taskTitle: 'K35', day: day);

  String iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  test('gom theo ngày, ngày mới nhất trước', () {
    final groups = DayGroup.from([
      entry('a', FeedKind.subtaskCompleted, '2026-09-10'),
      entry('b', FeedKind.pianoDone, '2026-09-10'),
      entry('c', FeedKind.subtaskCompleted, '2026-09-09'),
    ]);

    expect(groups.map((g) => g.day), ['2026-09-10', '2026-09-09']);
    expect(groups.first.entries.length, 2);
  });

  test('đếm hai loại RIÊNG, không gộp thành một số', () {
    // Thẻ KPI ngay phía trên chỉ đếm CÂY, và đếm mỗi cây một lần/tháng kể cả
    // khi QC trả về rồi vào lại. Gộp hai loại thành "12 việc xong" là để hai
    // con số cạnh nhau trên cùng một màn hình nói ngược nhau.
    final groups = DayGroup.from([
      entry('a', FeedKind.subtaskCompleted, '2026-09-10'),
      entry('b', FeedKind.subtaskCompleted, '2026-09-10'),
      entry('c', FeedKind.pianoDone, '2026-09-10'),
    ]);

    expect(groups.first.stageCount, 2);
    expect(groups.first.pianoCount, 1);
  });

  test('ảnh gửi lẻ vẫn hiện nhưng không bị đếm là việc xong', () {
    final groups = DayGroup.from([
      entry('a', FeedKind.subtaskCompleted, '2026-09-10'),
      entry('b', FeedKind.attachmentAdded, '2026-09-10'),
    ]);

    expect(groups.first.entries.length, 2);
    expect(groups.first.stageCount, 1);
    expect(groups.first.pianoCount, 0);
  });

  test('nhãn ngày đọc được', () {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));

    final groups = DayGroup.from([
      entry('a', FeedKind.subtaskCompleted, iso(today)),
      entry('b', FeedKind.subtaskCompleted, iso(yesterday)),
      entry('c', FeedKind.subtaskCompleted, '2026-01-05'),
    ]);

    expect(groups[0].label, 'HÔM NAY');
    expect(groups[1].label, 'HÔM QUA');
    expect(groups[2].label, '05/01');
  });

  test('dòng không có ngày thì BỎ QUA chứ không đoán', () {
    // Đặt nó vào một ngày tuỳ ý là nói dối về khi nào việc đó xảy ra, và đây
    // là màn hình người ta dùng để đối chiếu với ca làm.
    final groups = DayGroup.from([entry('a', FeedKind.subtaskCompleted, '')]);

    expect(groups, isEmpty);
  });

  test('giữ nguyên thứ tự server đã sắp trong từng ngày', () {
    // Server trả về mới nhất trước. Sắp lại ở client là tạo cơ hội cho hai
    // client hiện hai thứ tự khác nhau cho cùng một dữ liệu.
    final groups = DayGroup.from([
      entry('a', FeedKind.subtaskCompleted, '2026-09-10'),
      entry('b', FeedKind.subtaskCompleted, '2026-09-10'),
      entry('c', FeedKind.subtaskCompleted, '2026-09-10'),
    ]);

    expect(groups.first.entries.map((e) => e.id), ['a', 'b', 'c']);
  });
}
