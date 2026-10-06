import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// Money, dates and relative times — one place, so a screen never hand-rolls a
/// format and two screens never disagree.
abstract final class Formatters {
  static final _money = NumberFormat.decimalPattern('vi_VN');
  static final _compact1 = NumberFormat.decimalPattern('vi_VN')
    ..maximumFractionDigits = 1;
  static final _compact0 = NumberFormat.decimalPattern('vi_VN')
    ..maximumFractionDigits = 0;
  static final _dayMonth = DateFormat('dd/MM', 'vi_VN');
  static final _dayMonthYear = DateFormat('dd/MM/yyyy', 'vi_VN');
  static final _time = DateFormat('HH:mm', 'vi_VN');
  static final _dayHeader = DateFormat("EEEE, dd 'th'MM", 'vi_VN');

  /// Biên dịch MỘT lần: [initials] chạy trong build của mọi avatar trên màn,
  /// và `RegExp(...)` inline là biên dịch lại biểu thức cho mỗi khung hình.
  static final _whitespace = RegExp(r'\s+');

  /// `34990000` → `34.990.000đ`
  static String vnd(num? amount) {
    if (amount == null) return '—';
    return '${_money.format(amount)}đ';
  }

  /// Tiền rút gọn cho thẻ dày đặc — kiểu vi-VN như `formatMoneyCompact` của
  /// web: `34,9 tr`, `1,2 tỷ`, `12k` (APP-I14).
  static String vndCompact(num? amount) {
    if (amount == null) return '—';
    final value = amount.abs();
    if (value >= 1000000000) {
      return '${_compact1.format(amount / 1000000000)} tỷ';
    }
    if (value >= 1000000) {
      return '${_compact1.format(amount / 1000000)} tr';
    }
    if (value >= 1000) {
      return '${_compact0.format(amount / 1000)}k';
    }
    return _money.format(amount);
  }

  static String date(DateTime? value) =>
      value == null ? '—' : _dayMonthYear.format(VnTime.of(value));

  static String time(DateTime? value) =>
      value == null ? '' : _time.format(VnTime.of(value));

  /// Tiêu đề nhóm theo ngày — "Hôm nay"/"Hôm qua" so theo NGÀY VN.
  static String dayHeader(
    DateTime value, {
    @visibleForTesting DateTime? clock,
  }) {
    final diff = VnTime.today(clock).difference(VnTime.day(value)).inDays;
    if (diff == 0) return 'Hôm nay';
    if (diff == 1) return 'Hôm qua';
    return _dayHeader.format(VnTime.of(value)).toUpperCase();
  }

  /// `5 phút`, `2 giờ`, `Hôm qua`, `12/03`. Used on every list row. Ngày so
  /// theo giờ VN, không theo múi giờ của máy (APP-I14).
  static String relative(
    DateTime? value, {
    @visibleForTesting DateTime? clock,
  }) {
    if (value == null) return '';
    final local = VnTime.of(value);
    final now = VnTime.now(clock);
    final diff = now.difference(local);
    final sameDay = VnTime.day(value) == VnTime.today(clock);

    if (diff.inSeconds < 60) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút';
    if (diff.inHours < 24 && sameDay) return '${diff.inHours} giờ';
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
    final parts = (name ?? '').trim().split(_whitespace)
      ..removeWhere((p) => p.isEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters2();
    return '${parts[parts.length - 2][0]}${parts.last[0]}'.toUpperCase();
  }
}

/// Giờ nghiệp vụ là Asia/Ho_Chi_Minh (UTC+7, không đổi giờ mùa hè) — như web và
/// API (`BusinessClock`). Không theo múi giờ của máy (APP-I14).
///
/// Giờ VN được biểu diễn bằng một DateTime **UTC** có các trường y/m/d/h/m bằng
/// giờ VN, để `DateFormat` in đúng chữ số.
abstract final class VnTime {
  static const offset = Duration(hours: 7);

  /// Một giá trị → giờ VN.
  /// - Mốc `isUtc` (API trả ISO có `Z`): cộng 7 giờ.
  /// - Giá trị cục bộ đúng 00:00:00.000 (ngày `YYYY-MM-DD` parse ra, ngày chọn
  ///   trong lịch) là NGÀY LỊCH: giữ nguyên ngày, không quy đổi — để hạn chốt
  ///   không lệch ngày ở múi nào.
  /// - Giá trị cục bộ khác (vd `DateTime.now()` của bản nháp) là một mốc thật:
  ///   quy về UTC rồi cộng 7 giờ.
  ///
  /// Quy ước cho chỗ gọi: MỐC THẬT phải đưa vào ở dạng UTC (ISO có `Z`) hoặc
  /// `DateTime.now()`, không qua `toLocal()`/`fromMillisecondsSinceEpoch`
  /// cục bộ — một mốc cục bộ rơi đúng nửa đêm máy sẽ bị đọc thành ngày lịch.
  /// Chuỗi ngày giờ KHÔNG múi bị coi là giờ của máy (review M4).
  static DateTime of(DateTime value) {
    if (value.isUtc) return value.add(offset);
    if (_isCalendarDate(value)) {
      return DateTime.utc(value.year, value.month, value.day);
    }
    return value.toUtc().add(offset);
  }

  static DateTime now([DateTime? clock]) =>
      (clock ?? DateTime.now()).toUtc().add(offset);

  /// Ngày VN (00:00, biểu diễn UTC) của một giá trị.
  static DateTime day(DateTime value) {
    final v = of(value);
    return DateTime.utc(v.year, v.month, v.day);
  }

  /// Hôm nay theo giờ VN (00:00, biểu diễn UTC).
  static DateTime today([DateTime? clock]) {
    final n = now(clock);
    return DateTime.utc(n.year, n.month, n.day);
  }

  static bool _isCalendarDate(DateTime v) =>
      v.hour == 0 &&
      v.minute == 0 &&
      v.second == 0 &&
      v.millisecond == 0 &&
      v.microsecond == 0;
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
