import 'package:intl/intl.dart';

import '../../../core/utils/formatters.dart';

/// Định dạng chung của phân hệ Nhân sự. Tiền LUÔN đủ số và có khoảng trắng
/// trước "đ" như bản đã duyệt (`19.566.000 đ`), không viết tắt.
abstract final class HrFormat {
  static final _money = NumberFormat.decimalPattern('vi_VN');

  static const _weekdays = [
    'Thứ Hai',
    'Thứ Ba',
    'Thứ Tư',
    'Thứ Năm',
    'Thứ Sáu',
    'Thứ Bảy',
    'Chủ nhật',
  ];

  /// `19566000` → `19.566.000 đ`. Số âm giữ dấu trừ thật (−).
  static String money(num amount) {
    final abs = _money.format(amount.abs().round());
    return amount < 0 ? '−$abs đ' : '$abs đ';
  }

  /// `19566000` → `19.566.000` (khi "đ" vẽ riêng, nhỏ và nhạt).
  static String number(num amount) => _money.format(amount.round());

  /// `1.5` → `1,5`; `2.0` → `2`.
  static String decimal(num value) {
    final v = value.toDouble();
    if (v == v.roundToDouble()) return v.round().toString();
    final s = v.toStringAsFixed(2);
    return s
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '')
        .replaceAll('.', ',');
  }

  /// Ngày `YYYY-MM-DD` → DateTime (UTC, 00:00) — ngày lịch, không quy đổi múi.
  static DateTime? dateOf(String? ymd) {
    if (ymd == null || ymd.length < 10) return null;
    final y = int.tryParse(ymd.substring(0, 4));
    final m = int.tryParse(ymd.substring(5, 7));
    final d = int.tryParse(ymd.substring(8, 10));
    if (y == null || m == null || d == null) return null;
    return DateTime.utc(y, m, d);
  }

  /// `2026-11-24` → `2026-11-24` (từ DateTime bất kỳ, lấy năm-tháng-ngày).
  static String ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${_pad2(d.month)}-${_pad2(d.day)}';

  /// `2026-11` từ DateTime.
  static String ym(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${_pad2(d.month)}';

  static String weekdayName(DateTime d) => _weekdays[d.weekday - 1];

  /// `Thứ Ba, 24/11`.
  static String dayLabel(DateTime d) =>
      '${weekdayName(d)}, ${d.day}/${_pad2(d.month)}';

  /// `Thứ Ba, 24/11` từ `YYYY-MM-DD`; chuỗi hỏng trả nguyên văn.
  static String dayLabelOf(String? ymd) {
    final d = dateOf(ymd);
    return d == null ? (ymd ?? '—') : dayLabel(d);
  }

  /// `24/11` từ `YYYY-MM-DD`.
  static String dayMonthOf(String? ymd) {
    final d = dateOf(ymd);
    return d == null ? (ymd ?? '—') : '${d.day}/${_pad2(d.month)}';
  }

  /// `Tháng 11/2026` từ `2026-11`.
  static String monthLabel(String ym) {
    final parts = ym.split('-');
    if (parts.length < 2) return ym;
    final m = int.tryParse(parts[1]) ?? 0;
    return 'Tháng $m/${parts[0]}';
  }

  /// `10/2026` từ `2026-10`.
  static String monthShort(String ym) {
    final parts = ym.split('-');
    if (parts.length < 2) return ym;
    return '${int.tryParse(parts[1]) ?? parts[1]}/${parts[0]}';
  }

  /// Tháng kề: `2026-11` + (-1) → `2026-10`.
  static String shiftMonth(String ym, int delta) {
    final parts = ym.split('-');
    final y = int.tryParse(parts.first) ?? 2000;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1;
    return HrFormat.ym(DateTime.utc(y, m + delta));
  }

  /// Mốc ISO (UTC, có `Z`) → `07:52` giờ Việt Nam. Hỏng → null.
  static String? hm(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return null;
    final vn = VnTime.of(parsed.isUtc ? parsed : parsed.toUtc());
    return '${_pad2(vn.hour)}:${_pad2(vn.minute)}';
  }

  /// Giờ hiện tại theo giờ Việt Nam, `16:15`.
  static String nowHm([DateTime? clock]) {
    final n = VnTime.now(clock);
    return '${_pad2(n.hour)}:${_pad2(n.minute)}';
  }

  /// `520` phút → `8 giờ 40 phút`.
  static String duration(int minutes) {
    if (minutes <= 0) return '0 phút';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m phút';
    if (m == 0) return '$h giờ';
    return '$h giờ $m phút';
  }

  /// Khoảng cách: `40 m`, `1,2 km`.
  static String distance(num meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${decimal((meters / 100).round() / 10)} km';
  }

  /// Phút trong ngày (giờ VN) của mốc ISO.
  static int? minuteOfDay(String? iso) {
    final t = hm(iso);
    if (t == null) return null;
    final p = t.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  static String _pad2(int n) => n.toString().padLeft(2, '0');
}
