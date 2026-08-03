import 'package:intl/intl.dart';

/// Money, dates and relative times — one place, so a screen never hand-rolls a
/// format and two screens never disagree.
abstract final class Formatters {
  static final _money = NumberFormat.decimalPattern('vi_VN');
  static final _dayMonth = DateFormat('dd/MM', 'vi_VN');
  static final _dayMonthYear = DateFormat('dd/MM/yyyy', 'vi_VN');
  static final _time = DateFormat('HH:mm', 'vi_VN');
  static final _dayHeader = DateFormat("EEEE, dd 'th'MM", 'vi_VN');

  /// `34990000` → `34.990.000đ`
  static String vnd(num? amount) {
    if (amount == null) return '—';
    return '${_money.format(amount)}đ';
  }

  /// Compact money for dense cards: `34.9 tr`, `1.2 tỷ`.
  static String vndCompact(num? amount) {
    if (amount == null) return '—';
    final value = amount.abs();
    if (value >= 1000000000) {
      return '${_trim(amount / 1000000000)} tỷ';
    }
    if (value >= 1000000) {
      return '${_trim(amount / 1000000)} tr';
    }
    if (value >= 1000) {
      return '${_trim(amount / 1000)} k';
    }
    return _money.format(amount);
  }

  static String date(DateTime? value) =>
      value == null ? '—' : _dayMonthYear.format(value.toLocal());

  static String time(DateTime? value) =>
      value == null ? '' : _time.format(value.toLocal());

  static String dayHeader(DateTime value) {
    final local = value.toLocal();
    final today = DateUtilsX.startOfDay(DateTime.now());
    final day = DateUtilsX.startOfDay(local);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Hôm nay';
    if (diff == 1) return 'Hôm qua';
    return _dayHeader.format(local).toUpperCase();
  }

  /// `5 phút`, `2 giờ`, `Hôm qua`, `12/03`. Used on every list row.
  static String relative(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);

    if (diff.inSeconds < 60) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút';
    if (diff.inHours < 24 && now.day == local.day) return '${diff.inHours} giờ';
    if (diff.inDays < 2) return 'Hôm qua';
    if (diff.inDays < 7) return '${diff.inDays} ngày';
    if (now.year == local.year) return _dayMonth.format(local);
    return _dayMonthYear.format(local);
  }

  /// Waiting time on an unanswered thread — drives the SLA warning.
  static String duration(Duration value) {
    if (value.inMinutes < 60) return '${value.inMinutes}p';
    if (value.inHours < 24) return '${value.inHours}h';
    return '${value.inDays}n';
  }

  /// Two-letter avatar fallback: "Nguyễn Thu Hà" → "TH".
  static String initials(String? name) {
    final parts = (name ?? '').trim().split(RegExp(r'\s+'))
      ..removeWhere((p) => p.isEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters2();
    return '${parts[parts.length - 2][0]}${parts.last[0]}'.toUpperCase();
  }

  static String _trim(double value) {
    final rounded = value.toStringAsFixed(1);
    return rounded.endsWith('.0') ? rounded.substring(0, rounded.length - 2) : rounded;
  }
}

extension on String {
  String characters2() =>
      (length >= 2 ? substring(0, 2) : substring(0, 1)).toUpperCase();
}

abstract final class DateUtilsX {
  static DateTime startOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  /// Parses the ISO strings the API returns; tolerates nulls and junk.
  static DateTime? parse(Object? value) {
    if (value is DateTime) return value;
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
