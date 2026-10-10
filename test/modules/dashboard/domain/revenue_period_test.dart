import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/dashboard/domain/revenue_period.dart';

int vn(int y, int m, int d) => DateTime.utc(
  y,
  m,
  d,
).subtract(const Duration(hours: 7)).millisecondsSinceEpoch;

void main() {
  test('nhãn kỳ', () {
    expect(RevenueRange.week.label, 'Tuần');
    expect(RevenueRange.month.label, 'Tháng');
    expect(RevenueRange.year.label, 'Năm');
  });

  test('tháng theo giờ VN: 17:30 UTC 30/9 là 1/10 VN', () {
    final now = DateTime.utc(2026, 9, 30, 17, 30);
    final w = revenueWindow(RevenueRange.month, now);
    expect(w.from, vn(2026, 10, 1));
    expect(w.to, vn(2026, 11, 1));
    expect(w.prevFrom, vn(2026, 9, 1));
    expect(w.prevTo, vn(2026, 10, 1));
    expect(w.now, now.millisecondsSinceEpoch);
    expect(w.slots, 31);
    expect(w.axisLabels.length, 31);
    expect(w.axisLabels.first, '1');
  });

  test('tháng 1 → kỳ trước là tháng 12 năm trước', () {
    final w = revenueWindow(RevenueRange.month, DateTime.utc(2026, 1, 15));
    expect(w.prevFrom, vn(2025, 12, 1));
    expect(w.slots, 31);
  });

  test('tuần bắt đầu thứ Hai (giờ VN)', () {
    // Chủ nhật 11/10/2026 VN
    final w = revenueWindow(RevenueRange.week, DateTime.utc(2026, 10, 11, 10));
    expect(w.from, vn(2026, 10, 5));
    expect(w.to, vn(2026, 10, 12));
    expect(w.prevFrom, vn(2026, 9, 28));
    expect(w.prevTo, vn(2026, 10, 5));
    expect(w.slots, 7);
    expect(w.axisLabels, ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']);
    // 17:00 UTC Chủ nhật = 0:00 thứ Hai VN → tuần mới
    final w2 = revenueWindow(RevenueRange.week, DateTime.utc(2026, 10, 11, 17));
    expect(w2.from, vn(2026, 10, 12));
  });

  test('năm', () {
    final w = revenueWindow(RevenueRange.year, DateTime.utc(2026, 12, 31, 18));
    expect(w.from, vn(2027, 1, 1));
    expect(w.prevFrom, vn(2026, 1, 1));
    expect(w.slots, 12);
    expect(w.axisLabels.first, 'T1');
  });
}
