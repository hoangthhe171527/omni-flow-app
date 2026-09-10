import 'feed_entry.dart';

/// Nhiều hoạt động LIÊN TIẾP trên cùng một cây đàn, gộp thành một khối.
///
/// Một cây đàn qua tay nhiều người trong một buổi: người tick công đoạn, người
/// gửi ảnh, người chuyển cột. Để rời từng dòng thì tên cây đàn lặp lại năm bảy
/// lần liền nhau, và màn hình đọc thành một cuốn sổ thay vì một bản tóm tắt —
/// trong khi cả lý do màn này tồn tại là "xem tổng quan hoạt động của mọi
/// người".
///
/// Chỉ gộp những dòng **kề nhau**. Dòng thời gian xếp theo thời điểm, nên gộp
/// hai đợt hoạt động cách nhau nửa ngày sẽ đặt một dòng cũ lên trên những dòng
/// mới hơn của cây khác — tức là nói sai về thứ tự việc đã xảy ra, đúng thứ
/// một dòng thời gian không được phép sai.
class FeedGroup {
  const FeedGroup({
    required this.taskId,
    required this.taskTitle,
    required this.entries,
  });

  final String taskId;
  final String taskTitle;
  final List<FeedEntry> entries;

  /// Thời điểm mới nhất trong khối — cũng là thời điểm khối này đứng chỗ.
  DateTime? get at => entries.first.at;

  /// Dự án của cây đàn này, lấy từ dòng đầu tiên biết nó.
  ///
  /// Mọi dòng trong khối đều thuộc cùng một công việc nên cùng một dự án;
  /// dòng nào không mang tên (loại hoạt động cũ) thì lấy của dòng khác.
  String? get planName => entries
      .map((e) => e.planName)
      .where((name) => name != null && name.isNotEmpty)
      .firstOrNull;

  /// Gộp một danh sách đã xếp theo thời gian (mới nhất trước).
  static List<FeedGroup> from(List<FeedEntry> rows) {
    final groups = <FeedGroup>[];

    for (final entry in rows) {
      final last = groups.isEmpty ? null : groups.last;

      // taskId rỗng nghĩa là không biết dòng này thuộc cây nào. Gộp chúng lại
      // với nhau sẽ tạo ra một khối giả gồm những việc không liên quan, nên để
      // riêng từng dòng.
      final joinable =
          last != null &&
          entry.taskId.isNotEmpty &&
          last.taskId == entry.taskId;

      if (joinable) {
        last.entries.add(entry);
      } else {
        groups.add(
          FeedGroup(
            taskId: entry.taskId,
            taskTitle: entry.taskTitle,
            entries: [entry],
          ),
        );
      }
    }

    return groups;
  }
}
