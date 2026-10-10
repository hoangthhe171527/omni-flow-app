/// Chuỗi doanh thu (hàm thuần): server trả doanh thu TỪNG ô (chưa cộng dồn);
/// `current` đã cắt tới ô chứa `now`, nên k = current.length - 1.
library;

import 'package:flutter/foundation.dart' show listEquals;

import 'revenue_period.dart';

class RevenueSeries {
  RevenueSeries({
    required this.range,
    required List<double> current,
    required List<double> previous,
    required this.target,
    required this.slots,
  }) : current = List.unmodifiable(current),
       previous = List.unmodifiable(previous),
       cumCurrent = _cum(current),
       cumPrevious = _cum(previous);

  final RevenueRange range;
  final List<double> current, previous;
  final double? target;
  final int slots;
  final List<double> cumCurrent, cumPrevious;

  static List<double> _cum(List<double> xs) {
    var acc = 0.0;
    return List.unmodifiable([for (final x in xs) acc += x]);
  }

  /// So theo giá trị: provider tải lại ra chuỗi y hệt thì biểu đồ không vẽ lại.
  @override
  bool operator ==(Object other) =>
      other is RevenueSeries &&
      other.range == range &&
      other.target == target &&
      other.slots == slots &&
      listEquals(other.current, current) &&
      listEquals(other.previous, previous);

  @override
  int get hashCode => Object.hash(
    range,
    target,
    slots,
    Object.hashAll(current),
    Object.hashAll(previous),
  );

  double get headline => cumCurrent.isEmpty ? 0 : cumCurrent.last;

  double? get deltaRatio {
    if (cumCurrent.isEmpty || cumPrevious.isEmpty) return null;
    final k = cumCurrent.length - 1;
    final base =
        cumPrevious[k < cumPrevious.length ? k : cumPrevious.length - 1];
    if (base == 0) return null;
    return cumCurrent[k] / base - 1;
  }

  double? get targetRatio {
    final t = target;
    if (t == null || t == 0) return null;
    return headline / t;
  }

  double get projectedEnd =>
      cumCurrent.isEmpty ? 0 : headline / cumCurrent.length * slots;

  double? valueAt(int i) =>
      i >= 0 && i < cumCurrent.length ? cumCurrent[i] : null;
  double? previousAt(int i) =>
      i >= 0 && i < cumPrevious.length ? cumPrevious[i] : null;

  String summary() {
    final period = switch (range) {
      RevenueRange.week => 'Tuần này',
      RevenueRange.month => 'Tháng này',
      RevenueRange.year => 'Năm nay',
    };
    final b = StringBuffer('$period ${formatCompactVnd(headline)}');
    final d = deltaRatio;
    if (d != null) {
      final pct = (d.abs() * 100).round();
      b.write(', ${d >= 0 ? 'tăng' : 'giảm'} $pct% so với cùng kỳ');
    }
    b.write('; dự kiến ${formatCompactVnd(projectedEnd)}');
    final t = targetRatio;
    if (t != null) b.write('; đạt ${(t * 100).round()}% chỉ tiêu');
    return b.toString();
  }

  /// Hình server: `{bucket, current: [num], previous: [num], target: num|null, currency}`.
  static RevenueSeries fromJson(
    Map<String, dynamic> j,
    RevenueRange r,
    int slots,
  ) {
    List<double> list(String key) {
      final v = j[key];
      if (v is! List) throw FormatException('revenue-series: thiếu "$key"');
      return [
        for (final e in v)
          if (e is num)
            e.toDouble()
          else
            throw FormatException(
              'revenue-series: "$key" có phần tử không phải số',
            ),
      ];
    }

    // Server: year → 'month', week/month → 'day'. Lệch là hiểu sai trục x.
    final want = r == RevenueRange.year ? 'month' : 'day';
    if (j['bucket'] != want) {
      throw FormatException(
        'revenue-series: "bucket" phải là "$want" cho ${r.name}',
      );
    }
    final t = j['target'];
    if (t != null && t is! num) {
      throw const FormatException('revenue-series: "target" không phải số');
    }
    return RevenueSeries(
      range: r,
      current: list('current'),
      previous: list('previous'),
      target: (t as num?)?.toDouble(),
      slots: slots,
    );
  }
}

String _trim(double v, int decimals) {
  var s = v.toStringAsFixed(decimals);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s.replaceAll('.', ',');
}

String _group(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

/// 1.25e9 → '1,25 tỷ', 8.3e8 → '830 tr', 25000 → '25.000 đ', 0 → '0 đ'.
String formatCompactVnd(double v) {
  final sign = v < 0 ? '-' : '';
  final a = v.abs();
  // Làm tròn TRƯỚC khi chọn đơn vị: 999.999.999 → '1 tỷ', 999.999,6 → '1 tr'.
  final r = a.round();
  if (r >= 1e6) {
    final m = a / 1e6;
    final f = m >= 100 ? 1 : 10;
    final rm = (m * f).round() / f;
    if (rm < 1000) return '$sign${_trim(rm, f == 1 ? 0 : 1)} tr';
    return '$sign${_trim(a / 1e9, 2)} tỷ';
  }
  return r == 0 ? '0 đ' : '$sign${_group(r)} đ';
}
