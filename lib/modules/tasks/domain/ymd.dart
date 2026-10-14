/// `YYYY-MM-DD` theo ngày lịch của [date] (không đổi múi giờ) — dạng ngày mà
/// API việc nhận.
String ymd(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
