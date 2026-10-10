import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/dashboard/domain/revenue_period.dart';
import 'package:omni_app/modules/dashboard/domain/revenue_series.dart';

RevenueSeries s(
  List<double> c,
  List<double> p, {
  double? target,
  int slots = 31,
}) => RevenueSeries(
  range: RevenueRange.month,
  current: c,
  previous: p,
  target: target,
  slots: slots,
);

void main() {
  test('cộng dồn', () {
    final x = s([1, 2, 3], [4, 0, 1]);
    expect(x.cumCurrent, [1, 3, 6]);
    expect(x.cumPrevious, [4, 4, 5]);
    expect(x.headline, 6);
  });

  test('deltaRatio so cùng chỉ số k', () {
    final x = s([10, 10], [5, 5, 100]);
    expect(x.deltaRatio, closeTo(20 / 10 - 1, 1e-9));
  });

  test('kỳ trước ngắn hơn → phần tử cuối', () {
    final x = s(List.filled(30, 1), List.filled(28, 1));
    expect(x.deltaRatio, closeTo(30 / 28 - 1, 1e-9));
  });

  test('kỳ trước cộng dồn 0 → null; rỗng → null', () {
    expect(s([5], [0, 3]).deltaRatio, isNull);
    expect(s([5], []).deltaRatio, isNull);
    expect(s([], [1]).deltaRatio, isNull);
    expect(s([], [1]).headline, 0);
    expect(s([], [1]).projectedEnd, 0);
  });

  test('targetRatio', () {
    expect(s([5], [1]).targetRatio, isNull);
    expect(s([50], [1], target: 200).targetRatio, 0.25);
  });

  test('ngày 1 (k=0) dự kiến = headline × slots', () {
    expect(s([2], [1]).projectedEnd, 62);
    expect(s([2, 2], [1], slots: 30).projectedEnd, 60);
  });

  test('valueAt/previousAt', () {
    final x = s([1, 2], [3]);
    expect(x.valueAt(1), 3);
    expect(x.valueAt(2), isNull);
    expect(x.valueAt(-1), isNull);
    expect(x.previousAt(0), 3);
    expect(x.previousAt(1), isNull);
  });

  test('fromJson theo hình server', () {
    final x = RevenueSeries.fromJson(
      {
        'bucket': 'day',
        'current': [100, 50.5],
        'previous': [1, 2, 3],
        'target': 150,
        'currency': 'VND',
      },
      RevenueRange.month,
      31,
    );
    expect(x.current, [100, 50.5]);
    expect(x.target, 150);
    expect(x.slots, 31);
    final y = RevenueSeries.fromJson(
      {'current': [], 'previous': [], 'target': null},
      RevenueRange.week,
      7,
    );
    expect(y.target, isNull);
    expect(
      () => RevenueSeries.fromJson({'previous': []}, RevenueRange.month, 31),
      throwsFormatException,
    );
    expect(
      () => RevenueSeries.fromJson(
        {
          'current': ['x'],
          'previous': [],
        },
        RevenueRange.month,
        31,
      ),
      throwsFormatException,
    );
  });

  test('formatCompactVnd', () {
    expect(formatCompactVnd(1.25e9), '1,25 tỷ');
    expect(formatCompactVnd(1.1e9), '1,1 tỷ');
    expect(formatCompactVnd(2e9), '2 tỷ');
    expect(formatCompactVnd(8.3e8), '830 tr');
    expect(formatCompactVnd(1.5e6), '1,5 tr');
    expect(formatCompactVnd(0), '0 đ');
    expect(formatCompactVnd(25000), '25.000 đ');
    expect(formatCompactVnd(-8.3e8), '-830 tr');
  });

  test('summary có/không chỉ tiêu', () {
    final x = RevenueSeries(
      range: RevenueRange.month,
      current: [8.3e8],
      previous: [8.3e8 / 1.12 * 1.0],
      target: 1.2e9,
      slots: 1,
    );
    expect(
      x.summary(),
      'Tháng này 830 tr, tăng 12% so với cùng kỳ; dự kiến 830 tr; đạt 69% chỉ tiêu',
    );
    final y = s([100e6], [200e6], slots: 2);
    expect(
      y.summary(),
      'Tháng này 100 tr, giảm 50% so với cùng kỳ; dự kiến 200 tr',
    );
    final z = RevenueSeries(
      range: RevenueRange.week,
      current: [1e6],
      previous: [0],
      target: null,
      slots: 7,
    );
    expect(z.summary(), 'Tuần này 1 tr; dự kiến 7 tr');
  });
}
