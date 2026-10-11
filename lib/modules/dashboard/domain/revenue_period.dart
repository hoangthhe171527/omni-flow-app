/// Kỳ doanh thu cho Tổng quan: mốc tính theo giờ VN (UTC+7), không theo giờ máy.
library;

enum RevenueRange {
  week('Tuần'),
  month('Tháng'),
  year('Năm');

  const RevenueRange(this.label);
  final String label;
}

/// Mốc kỳ (ms epoch, `to` loại trừ) gửi lên `/sales-overview/revenue-series`.
class RevenueWindow {
  const RevenueWindow({
    required this.from,
    required this.to,
    required this.prevFrom,
    required this.prevTo,
    required this.now,
    required this.slots,
    required this.axisLabels,
  });

  final int from, to, prevFrom, prevTo, now;

  /// Số ô của kỳ: 7 (tuần), số ngày (tháng), 12 (năm).
  final int slots;
  final List<String> axisLabels;
}

const _vnOffset = Duration(hours: 7);

/// Nửa đêm VN của ngày (y, m, d) — chuẩn hoá tràn tháng/năm như DateTime.
int _vnMidnight(int y, int m, int d) =>
    DateTime.utc(y, m, d).subtract(_vnOffset).millisecondsSinceEpoch;

RevenueWindow revenueWindow(RevenueRange r, DateTime nowUtc) {
  final vn = nowUtc.toUtc().add(_vnOffset); // trường ngày giờ = giờ VN
  final now = nowUtc.millisecondsSinceEpoch;
  switch (r) {
    case RevenueRange.week:
      final d = vn.day - (vn.weekday - DateTime.monday);
      return RevenueWindow(
        from: _vnMidnight(vn.year, vn.month, d),
        to: _vnMidnight(vn.year, vn.month, d + 7),
        prevFrom: _vnMidnight(vn.year, vn.month, d - 7),
        prevTo: _vnMidnight(vn.year, vn.month, d),
        now: now,
        slots: 7,
        axisLabels: const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'],
      );
    case RevenueRange.month:
      final days = DateTime.utc(vn.year, vn.month + 1, 0).day;
      return RevenueWindow(
        from: _vnMidnight(vn.year, vn.month, 1),
        to: _vnMidnight(vn.year, vn.month + 1, 1),
        prevFrom: _vnMidnight(vn.year, vn.month - 1, 1),
        prevTo: _vnMidnight(vn.year, vn.month, 1),
        now: now,
        slots: days,
        axisLabels: [for (var i = 1; i <= days; i++) '$i'],
      );
    case RevenueRange.year:
      return RevenueWindow(
        from: _vnMidnight(vn.year, 1, 1),
        to: _vnMidnight(vn.year + 1, 1, 1),
        prevFrom: _vnMidnight(vn.year - 1, 1, 1),
        prevTo: _vnMidnight(vn.year, 1, 1),
        now: now,
        slots: 12,
        axisLabels: [for (var i = 1; i <= 12; i++) 'T$i'],
      );
  }
}
