import 'feed_entry.dart';

/// Một ngày làm việc của xưởng, và những gì đã xong trong ngày đó.
///
/// Gom theo NGÀY chứ không theo cây đàn: câu hỏi người ta mở màn này để hỏi là
/// "hôm nay ai xong cái gì", và gom theo cây đàn bắt họ tự cộng lại trong đầu
/// qua nhiều thẻ.
class DayGroup {
  const DayGroup({
    required this.day,
    required this.entries,
    required this.stageCount,
    required this.pianoCount,
  });

  /// `YYYY-MM-DD`, do SERVER tính theo giờ xưởng.
  ///
  /// Không suy lại từ `at` của từng dòng: máy chủ chạy UTC, ca chiều rơi sang
  /// ngày hôm sau theo giờ đó, và một điện thoại đặt sai múi giờ đủ làm hai
  /// người nhìn hai ngày khác nhau trên cùng một sự kiện.
  final String day;

  final List<FeedEntry> entries;

  /// Số công đoạn xong trong ngày.
  ///
  /// Đếm RIÊNG với [pianoCount]: thẻ KPI ngay phía trên chỉ đếm CÂY, và đếm
  /// mỗi cây một lần/tháng kể cả khi QC trả về rồi vào lại (§B3). Một con số
  /// gộp sẽ nói ngược với nó trên cùng một màn hình.
  final int stageCount;

  /// Số cây đàn hoàn thành trong ngày.
  final int pianoCount;

  static List<DayGroup> from(List<FeedEntry> entries) {
    final byDay = <String, List<FeedEntry>>{};

    for (final entry in entries) {
      // Không có ngày thì bỏ qua. Đặt nó vào một ngày tuỳ ý là nói dối về khi
      // nào việc đó xảy ra, và đây là màn hình dùng để đối chiếu với ca làm.
      if (entry.day.isEmpty) continue;
      byDay.putIfAbsent(entry.day, () => []).add(entry);
    }

    // Chuỗi `YYYY-MM-DD` sắp theo chữ cái đúng bằng sắp theo thời gian, nên
    // không cần phân tích ra DateTime chỉ để so sánh.
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    return [
      for (final day in days)
        DayGroup(
          day: day,
          // Giữ nguyên thứ tự server đã sắp. Sắp lại ở client là tạo cơ hội
          // cho hai client hiện hai thứ tự khác nhau cho cùng dữ liệu.
          entries: byDay[day]!,
          stageCount: byDay[day]!
              .where((e) => e.kind == FeedKind.subtaskCompleted)
              .length,
          pianoCount: byDay[day]!
              .where((e) => e.kind == FeedKind.pianoDone)
              .length,
        ),
    ];
  }

  /// `HÔM NAY` / `HÔM QUA` / `05/01`.
  ///
  /// Hai ngày gần nhất gọi bằng tên vì đó là hai ngày người ta thật sự hỏi;
  /// xa hơn thì một con số ngày/tháng đọc nhanh hơn "3 ngày trước".
  String get label {
    final now = DateTime.now();

    String iso(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

    if (day == iso(now)) return 'HÔM NAY';
    if (day == iso(now.subtract(const Duration(days: 1)))) return 'HÔM QUA';

    final parts = day.split('-');

    return parts.length == 3 ? '${parts[2]}/${parts[1]}' : day;
  }

  /// `HÔM NAY · 12 công đoạn · 2 cây xong`
  ///
  /// Bỏ vế nào bằng 0: khoe một số 0 làm dòng dài ra mà không nói thêm gì, và
  /// một ngày chỉ có công đoạn xong là ngày bình thường của xưởng.
  String get summary => [
    label,
    if (stageCount > 0) '$stageCount công đoạn',
    if (pianoCount > 0) '$pianoCount cây xong',
  ].join(' · ');
}
