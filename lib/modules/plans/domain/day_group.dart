import 'feed_entry.dart';

/// Một ngày làm việc của xưởng, và những gì đã xong trong ngày đó.
///
/// Gom theo NGÀY chứ không theo cây đàn: câu hỏi người ta mở màn này để hỏi là
/// "hôm nay ai xong cái gì", và gom theo cây đàn bắt họ tự cộng lại trong đầu
/// qua nhiều thẻ.
class DayGroup {
  const DayGroup({required this.day, required this.entries});

  /// `YYYY-MM-DD`, do SERVER tính theo giờ xưởng.
  ///
  /// Không suy lại từ `at` của từng dòng: máy chủ chạy UTC, ca chiều rơi sang
  /// ngày hôm sau theo giờ đó, và một điện thoại đặt sai múi giờ đủ làm hai
  /// người nhìn hai ngày khác nhau trên cùng một sự kiện.
  final String day;

  final List<FeedEntry> entries;

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
        ),
    ];
  }

  /// `Hôm nay` / `Hôm qua` / `Thứ Tư 07/10`.
  ///
  /// Hai ngày gần nhất gọi bằng tên vì đó là hai ngày người ta thật sự hỏi;
  /// xa hơn thì thứ + ngày/tháng đọc nhanh hơn "3 ngày trước". Chữ HOA là việc
  /// của tiêu đề (`DayHeader`), không phải của dữ liệu.
  String get label {
    final now = DateTime.now();

    String iso(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

    if (day == iso(now)) return 'Hôm nay';
    if (day == iso(now.subtract(const Duration(days: 1)))) return 'Hôm qua';

    final parts = day.split('-');
    if (parts.length != 3) return day;

    final date = DateTime.tryParse(day);
    const weekdays = [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ Nhật',
    ];

    return date == null
        ? '${parts[2]}/${parts[1]}'
        : '${weekdays[date.weekday - 1]} ${parts[2]}/${parts[1]}';
  }
}
