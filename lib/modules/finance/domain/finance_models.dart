import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/utils/formatters.dart';
import '../../../design/tokens/tokens.dart';

/// Trạng thái thanh toán của một khoản chi.
enum ExpenseStatus {
  paid('paid', 'Đã trả đủ'),
  unpaid('unpaid', 'Chưa trả'),
  partial('partial', 'Trả một phần');

  const ExpenseStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static ExpenseStatus fromString(String? raw) => switch (raw) {
    'paid' => ExpenseStatus.paid,
    'partial' => ExpenseStatus.partial,
    _ => ExpenseStatus.unpaid,
  };
}

/// Phân loại nguồn tiền (`/finance/money-accounts`).
enum MoneyAccountKind {
  bank('bank', 'TK ngân hàng'),
  company('company', 'Chuyển khoản công ty'),
  cash('cash', 'Tiền mặt'),
  advance('advance', 'Tiền ứng');

  const MoneyAccountKind(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static MoneyAccountKind fromString(String? raw) => switch (raw) {
    'company' => MoneyAccountKind.company,
    'cash' => MoneyAccountKind.cash,
    'advance' => MoneyAccountKind.advance,
    _ => MoneyAccountKind.bank,
  };
}

/// Chế độ sắp xếp danh sách chi phí đa chiều chuẩn iOS.
enum ExpenseSortMode {
  spentDateDesc('spent_desc', 'Ngày ghi nhận (mới nhất)'),
  createdAtDesc('created_desc', 'Thời gian nhập (mới nhập)'),
  paidDateDesc('paid_desc', 'Ngày thanh toán (mới trả)'),
  category('category', 'Loại chi phí (theo nhóm)'),
  amountDesc('amount_desc', 'Số tiền (cao › thấp)'),
  amountAsc('amount_asc', 'Số tiền (thấp › cao)');

  const ExpenseSortMode(this.id, this.label);

  final String id;
  final String label;
}

/// Dựng lại host cho đường dẫn media chứng từ `/api/v1/finance/media/...`
/// về API origin hiện tại, đồng thời bảo toàn URL S3/CDN công khai.
String resolveFinanceMediaUrl(String value) {
  final source = value.trim();
  if (source.isEmpty) return '';
  final cut = source.indexOf(RegExp(r'[?#]'));
  final rawPath = cut < 0 ? source : source.substring(0, cut);
  String decoded;
  try {
    decoded = Uri.decodeFull(rawPath);
  } catch (_) {
    decoded = rawPath;
  }
  if (RegExp(r'(^|/)\.\.($|/)').hasMatch(decoded.replaceAll(r'\', '/'))) {
    return '';
  }
  final parsed = Uri.tryParse(source);
  if (parsed == null) return source;
  final api = Uri.parse(AppConfig.apiBaseUrl);
  final query = parsed.hasQuery ? parsed.query : null;
  String rebind(String path) =>
      api.replace(path: path, query: query).toString();

  if (parsed.path.startsWith('/api/v1/finance/media/')) {
    return rebind(parsed.path);
  }
  if (!parsed.hasScheme && parsed.path.startsWith('/')) {
    return rebind(parsed.path);
  }
  return source;
}

/// Chứng từ / tệp đính kèm chứng minh khoản chi (ảnh phiếu chi, hoá đơn, PDF).
@immutable
class ExpenseAttachment {
  const ExpenseAttachment({
    required this.id,
    required this.name,
    this.url = '',
    this.mimeType,
    this.size,
    this.kind = 'image',
    this.sizeLabel = '',
    this.uploadedAt = '',
    this.rawUploadedAt,
  });

  factory ExpenseAttachment.fromJson(Map<String, dynamic> json) {
    final name = '${json['name'] ?? ''}';
    final mimeType = _asNullableString(json['mime_type'] ?? json['mimeType']);
    final size = json['size'] == null ? null : _asInt(json['size']);
    final rawUploaded = _asNullableString(
      json['uploaded_at'] ?? json['uploadedAt'],
    );
    final explicitKind = _asNullableString(json['kind']);
    final inferredKind =
        explicitKind ??
        ((mimeType?.toLowerCase() == 'application/pdf' ||
                name.toLowerCase().endsWith('.pdf'))
            ? 'pdf'
            : 'image');
    final explicitSizeLabel = _asNullableString(
      json['size_label'] ?? json['sizeLabel'],
    );

    return ExpenseAttachment(
      id: '${json['id'] ?? ''}',
      name: name,
      url: '${json['url'] ?? ''}',
      mimeType: mimeType,
      size: size,
      kind: inferredKind,
      sizeLabel: explicitSizeLabel ?? FinanceMonthUtils.formatByteSize(size),
      uploadedAt: FinanceMonthUtils.formatServerTimestamp(rawUploaded),
      rawUploadedAt: rawUploaded,
    );
  }

  final String id;
  final String name;
  final String url;
  final String? mimeType;
  final int? size;

  /// `'image'` hoặc `'pdf'`.
  final String kind;
  final String sizeLabel;
  final String uploadedAt;
  final String? rawUploadedAt;

  String get resolvedUrl => resolveFinanceMediaUrl(url);

  bool get isPdf =>
      mimeType?.toLowerCase() == 'application/pdf' ||
      kind.toLowerCase() == 'pdf' ||
      name.toLowerCase().endsWith('.pdf');

  bool get isImage =>
      !isPdf &&
      ((mimeType?.toLowerCase().startsWith('image/') ?? false) ||
          kind.toLowerCase() == 'image' ||
          RegExp(
            r'\.(jpg|jpeg|png|webp|gif|heic)$',
            caseSensitive: false,
          ).hasMatch(name));

  Map<String, dynamic> toInputJson() => {
    if (id.isNotEmpty) 'id': id,
    'name': name,
    'url': url,
    if (mimeType != null && mimeType!.isNotEmpty) 'mime_type': mimeType,
    if (size != null) 'size': size,
    if (rawUploadedAt != null && rawUploadedAt!.isNotEmpty)
      'uploaded_at': rawUploadedAt,
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    if (mimeType != null) 'mime_type': mimeType,
    if (size != null) 'size': size,
    'kind': kind,
    'size_label': sizeLabel,
    'uploaded_at': rawUploadedAt ?? uploadedAt,
  };
}

/// Mẫu khoản chi cố định trả về từ `meta.recurring_templates` của `GET /finance/expense-groups`.
@immutable
class RecurringTemplateMeta {
  const RecurringTemplateMeta({
    required this.key,
    required this.title,
    required this.seedKey,
    required this.groupName,
    this.groupId,
  });

  factory RecurringTemplateMeta.fromJson(Map<String, dynamic> json) {
    return RecurringTemplateMeta(
      key: '${json['key'] ?? ''}',
      title: '${json['title'] ?? ''}',
      seedKey: '${json['seed_key'] ?? ''}',
      groupName: '${json['group_name'] ?? ''}',
      groupId: _asNullableString(json['group_id']),
    );
  }

  final String key;
  final String title;
  final String seedKey;
  final String groupName;
  final String? groupId;
}

/// Tiện ích tháng `YYYY-MM` / `MM/YYYY` và ngày `YYYY-MM-DD` / `DD/MM`.
abstract final class FinanceMonthUtils {
  /// Định dạng số nguyên kiểu `vi-VN` không kèm hậu tố `đ` (vd `12.000.000`, `-500.000`).
  /// Giữ nguyên dấu âm cho khoản hoàn tiền / chiết khấu nhập từ Excel (API Ruling 18).
  static String formatNumber(num? value) {
    final rounded = (value ?? 0).round();
    if (rounded == 0) return '0';
    final s = Formatters.vnd(rounded.abs());
    final clean = s.endsWith('đ') ? s.substring(0, s.length - 1) : s;
    return rounded < 0 ? '-$clean' : clean;
  }

  /// Định dạng tiền tệ kèm khoảng trắng `12.000.000 đ` (hoặc `-500.000 đ`).
  static String formatVndSpace(num? value) => '${formatNumber(value)} đ';

  static String formatByteSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Định dạng mốc giờ ISO từ API sang giờ VN (`DD/MM HH:mm`), hoặc giữ nguyên nếu đã định dạng sẵn.
  static String formatServerTimestamp(String? raw, {String fallback = ''}) {
    if (raw == null || raw.trim().isEmpty) return fallback;
    final trimmed = raw.trim();
    final parsed = DateTime.tryParse(trimmed);
    if (parsed != null) {
      final vn = VnTime.of(parsed);
      final d = vn.day.toString().padLeft(2, '0');
      final m = vn.month.toString().padLeft(2, '0');
      final hh = vn.hour.toString().padLeft(2, '0');
      final mm = vn.minute.toString().padLeft(2, '0');
      return '$d/$m $hh:$mm';
    }
    return trimmed;
  }

  /// Trích khoá sắp xếp `YYYY-MM-DD HH:mm:ss` theo giờ VN cho `created_at`.
  static String createdSortKey({
    String? rawCreatedAt,
    required String displayCreatedAt,
    required String fallbackSpentOn,
    required String month,
  }) {
    if (rawCreatedAt != null && rawCreatedAt.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(rawCreatedAt.trim());
      if (parsed != null) {
        final vn = VnTime.of(parsed);
        final y = vn.year.toString().padLeft(4, '0');
        final m = vn.month.toString().padLeft(2, '0');
        final d = vn.day.toString().padLeft(2, '0');
        final hh = vn.hour.toString().padLeft(2, '0');
        final mm = vn.minute.toString().padLeft(2, '0');
        final ss = vn.second.toString().padLeft(2, '0');
        return '$y-$m-$d $hh:$mm:$ss';
      }
    }
    final parts = displayCreatedAt.trim().split(RegExp(r'\s+'));
    final dm = parts.isNotEmpty && parts.first.isNotEmpty
        ? parts.first
        : shortDayMonth(fallbackSpentOn);
    final hm = parts.length > 1 ? parts.last : '00:00';
    final isoDate = toIsoDate(dm, month);
    return '$isoDate $hm:00';
  }

  /// Ngày `YYYY-MM-DD` theo giờ VN của thời điểm nhập `created_at`.
  static String createdDayIso({
    String? rawCreatedAt,
    required String displayCreatedAt,
    required String fallbackSpentOn,
    required String month,
  }) {
    if (rawCreatedAt != null && rawCreatedAt.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(rawCreatedAt.trim());
      if (parsed != null) {
        return formatIsoDate(VnTime.day(parsed));
      }
    }
    final dm = displayCreatedAt.trim().split(RegExp(r'\s+')).first;
    if (dm.isNotEmpty) {
      return toIsoDate(dm, month);
    }
    return fallbackSpentOn;
  }

  static String currentVnMonth([DateTime? clock]) {
    final now = VnTime.now(clock);
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  /// 3 tháng mặc định trên thanh chọn nhanh `[M-2, M-1, M]` theo giờ VN.
  static List<String> recentThreeMonths([DateTime? clock]) {
    final cur = currentVnMonth(clock);
    return [shiftMonth(cur, -2), shiftMonth(cur, -1), cur];
  }

  /// Danh sách tháng trong menu chọn kỳ (tháng kế tiếp + 12 tháng gần nhất + `activeMonth` nếu nằm ngoài).
  static List<String> pickerMonths({
    String? activeMonth,
    DateTime? clock,
    int pastMonths = 11,
  }) {
    final cur = currentVnMonth(clock);
    final next = shiftMonth(cur, 1);
    final list = <String>[
      next,
      cur,
      for (var i = 1; i <= pastMonths; i++) shiftMonth(cur, -i),
    ];
    if (activeMonth != null && activeMonth.isNotEmpty) {
      final normalized = toYearMonth(activeMonth, clock);
      if (!list.contains(normalized)) {
        list.add(normalized);
        list.sort((a, b) => b.compareTo(a));
      }
    }
    return list;
  }

  /// Chuẩn hoá chuỗi tháng bất kỳ (`11/2026` hoặc `2026-11`) về `YYYY-MM`.
  static String toYearMonth(String raw, [DateTime? clock]) {
    final trimmed = raw.trim();
    final fallbackYear = VnTime.now(clock).year;
    if (trimmed.contains('/')) {
      final parts = trimmed.split('/');
      if (parts.length == 2) {
        final m = (int.tryParse(parts[0]) ?? 1)
            .clamp(1, 12)
            .toString()
            .padLeft(2, '0');
        final y = (int.tryParse(parts[1]) ?? fallbackYear).toString().padLeft(
          4,
          '0',
        );
        return '$y-$m';
      }
    }
    if (trimmed.contains('-')) {
      final parts = trimmed.split('-');
      if (parts.length >= 2) {
        final y = (int.tryParse(parts[0]) ?? fallbackYear).toString().padLeft(
          4,
          '0',
        );
        final m = (int.tryParse(parts[1]) ?? 1)
            .clamp(1, 12)
            .toString()
            .padLeft(2, '0');
        return '$y-$m';
      }
    }
    return currentVnMonth(clock);
  }

  /// `2026-11` → `11/2026`.
  static String formatMonthSlash(String ymOrSlash) {
    final ym = toYearMonth(ymOrSlash);
    final m = monthNumberOf(ym).toString().padLeft(2, '0');
    final y = yearOf(ym);
    return '$m/$y';
  }

  /// `2026-11` → `Tháng 11/2026`.
  static String formatMonthFull(String ymOrSlash) {
    final ym = toYearMonth(ymOrSlash);
    return 'Tháng ${monthNumberOf(ym)}/${yearOf(ym)}';
  }

  /// `2026-11` → `Tháng 11`.
  static String formatMonthShort(String ymOrSlash) {
    final ym = toYearMonth(ymOrSlash);
    return 'Tháng ${monthNumberOf(ym)}';
  }

  static int yearOf(String ymOrSlash) {
    final ym = toYearMonth(ymOrSlash);
    final parts = ym.split('-');
    return parts.isNotEmpty
        ? (int.tryParse(parts[0]) ?? VnTime.now().year)
        : VnTime.now().year;
  }

  static int monthNumberOf(String ymOrSlash) {
    final ym = toYearMonth(ymOrSlash);
    final parts = ym.split('-');
    return parts.length > 1 ? (int.tryParse(parts[1]) ?? 1) : 1;
  }

  /// Dời `YYYY-MM` đi `deltaMonths` tháng (âm = lùi, dương = tiến).
  static String shiftMonth(String ymOrSlash, int deltaMonths) {
    final ym = toYearMonth(ymOrSlash);
    final y = yearOf(ym);
    final m = monthNumberOf(ym);
    final total = y * 12 + (m - 1) + deltaMonths;
    final nextYear = (total / 12).floor();
    final nextMonth0 = total - nextYear * 12;
    return '$nextYear-${(nextMonth0 + 1).toString().padLeft(2, '0')}';
  }

  /// Dời ngày `YYYY-MM-DD` sang tháng `targetYm` và kẹp ngày cuối tháng hợp lệ (vd 31/01 -> 28/02).
  static String shiftDateToMonth(String ymd, String targetYm) {
    final ym = toYearMonth(targetYm);
    final dt = parseIsoDate(ymd, fallbackMonth: ym);
    final maxDay = DateTime.utc(yearOf(ym), monthNumberOf(ym) + 1, 0).day;
    final clampedDay = math.min(dt.day, maxDay).toString().padLeft(2, '0');
    return '$ym-$clampedDay';
  }

  static String todayIso([DateTime? clock]) {
    final today = VnTime.today(clock);
    return formatIsoDate(today);
  }

  /// Kẹp `paid_on <= today` theo giờ VN (API `SaveExpense::checkedPayments` cấm ngày trả tương lai).
  static String clampPaidOn(String candidateIso, [DateTime? clock]) {
    final today = todayIso(clock);
    if (candidateIso.trim().isEmpty) return today;
    return candidateIso.compareTo(today) <= 0 ? candidateIso : today;
  }

  static String formatIsoDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static DateTime parseIsoDate(String ymd, {String? fallbackMonth}) {
    final trimmed = ymd.trim();
    final fallbackYr = fallbackMonth != null
        ? yearOf(fallbackMonth)
        : VnTime.now().year;
    if (trimmed.contains('-') && trimmed.length >= 10) {
      final parts = trimmed.split('-');
      final y = int.tryParse(parts[0]) ?? fallbackYr;
      final m = int.tryParse(parts[1]) ?? 1;
      final d =
          int.tryParse(parts[2].substring(0, math.min(2, parts[2].length))) ??
          1;
      return DateTime(y, m, d);
    }
    if (trimmed.contains('/')) {
      final parts = trimmed.split('/');
      if (parts.length >= 2) {
        final d = int.tryParse(parts[0]) ?? 1;
        final m = int.tryParse(parts[1]) ?? 1;
        final y = parts.length >= 3
            ? (int.tryParse(parts[2]) ?? fallbackYr)
            : fallbackYr;
        return DateTime(y, m, d);
      }
    }
    return DateTime.tryParse(trimmed) ?? VnTime.today();
  }

  /// Chuẩn hoá `02/11` + `2026-11` → `2026-11-02`.
  static String toIsoDate(String dayOrIso, String monthYm) {
    final trimmed = dayOrIso.trim();
    if (trimmed.contains('-') && trimmed.length >= 10) {
      return trimmed.substring(0, 10);
    }
    final ym = toYearMonth(monthYm);
    final y = yearOf(ym).toString().padLeft(4, '0');
    if (trimmed.contains('/')) {
      final parts = trimmed.split('/');
      final mInt = parts.length > 1
          ? (int.tryParse(parts[1]) ?? monthNumberOf(ym)).clamp(1, 12)
          : monthNumberOf(ym);
      final maxDay = DateTime.utc(int.parse(y), mInt + 1, 0).day;
      final dInt = (int.tryParse(parts[0]) ?? 1).clamp(1, maxDay);
      return '$y-${mInt.toString().padLeft(2, '0')}-${dInt.toString().padLeft(2, '0')}';
    }
    return '$ym-01';
  }

  /// `2026-11-02` → `02/11`.
  static String shortDayMonth(String ymd) {
    final trimmed = ymd.trim();
    if (trimmed.length >= 10 && trimmed.contains('-')) {
      return '${trimmed.substring(8, 10)}/${trimmed.substring(5, 7)}';
    }
    if (trimmed.contains('/')) {
      final parts = trimmed.split('/');
      if (parts.length >= 2) {
        return '${parts[0].padLeft(2, '0')}/${parts[1].padLeft(2, '0')}';
      }
    }
    return trimmed;
  }

  /// `2026-11-02` → `02/11/2026`.
  static String fullDayMonthYear(String ymd, {String? fallbackMonth}) {
    final dt = parseIsoDate(ymd, fallbackMonth: fallbackMonth);
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString().padLeft(4, '0');
    return '$d/$m/$y';
  }

  /// Ngày cuối tháng `YYYY-MM-DD`.
  static String lastDayOfMonth(String ymOrSlash) {
    final ym = toYearMonth(ymOrSlash);
    final y = yearOf(ym);
    final m = monthNumberOf(ym);
    final lastDay = DateTime.utc(y, m + 1, 0).day;
    return '$ym-${lastDay.toString().padLeft(2, '0')}';
  }

  /// Ngày mặc định trong tháng khớp logic Web (`defaultSpentOn`):
  /// - Tháng hiện tại (giờ VN): hôm nay
  /// - Tháng quá khứ: ngày cuối tháng đó
  /// - Tháng tương lai: ngày 01 của tháng đó
  static String defaultSpentOnForMonth(String ymOrSlash, [DateTime? clock]) {
    final ym = toYearMonth(ymOrSlash, clock);
    final current = currentVnMonth(clock);
    if (ym == current) return todayIso(clock);
    if (ym.compareTo(current) < 0) return lastDayOfMonth(ym);
    return '$ym-01';
  }

  /// Nhãn tiêu đề ngày trên danh sách: `Hôm nay · DD/MM/YYYY`, `Hôm qua · DD/MM/YYYY` hoặc `DD/MM/YYYY`.
  static String dayHeaderLabel(
    String ymd, {
    String? activeMonth,
    DateTime? clock,
  }) {
    final iso = toIsoDate(ymd, activeMonth ?? currentVnMonth(clock));
    final full = fullDayMonthYear(iso, fallbackMonth: activeMonth);
    final today = todayIso(clock);
    if (iso == today) {
      return 'Hôm nay · $full';
    }
    final yesterday = formatIsoDate(
      VnTime.today(clock).subtract(const Duration(days: 1)),
    );
    if (iso == yesterday) {
      return 'Hôm qua · $full';
    }
    return full;
  }

  /// Danh sách các ngày gợi ý nhanh trong popover chọn ngày của tháng `ym`.
  static List<({String isoDate, String label})> quickDatesForMonth(
    String ymOrSlash, [
    DateTime? clock,
  ]) {
    final ym = toYearMonth(ymOrSlash, clock);
    final y = yearOf(ym);
    final m = monthNumberOf(ym).toString().padLeft(2, '0');
    final today = todayIso(clock);
    final defaultIso = defaultSpentOnForMonth(ym, clock);
    final defaultDm = shortDayMonth(defaultIso);
    final lastDm = shortDayMonth(lastDayOfMonth(ym));
    final candidates = <String>[
      defaultDm,
      '01/$m',
      '05/$m',
      '10/$m',
      '15/$m',
      '20/$m',
      '25/$m',
      lastDm,
    ];
    final seen = <String>{};
    final result = <({String isoDate, String label})>[];
    for (final dm in candidates) {
      if (!seen.add(dm)) continue;
      final iso = toIsoDate(dm, ym);
      final isToday = iso == today;
      result.add((isoDate: iso, label: '${isToday ? 'Hôm nay · ' : ''}$dm/$y'));
    }
    return result;
  }

  static String adaptTitleToMonth(
    String title, {
    required String fromMonth,
    required String toMonth,
  }) {
    final fromNum = monthNumberOf(fromMonth);
    final toNum = monthNumberOf(toMonth);
    if (fromNum == toNum) return title;
    var updated = title.replaceAllMapped(
      RegExp('tháng\\s*0?$fromNum(?!\\d)', caseSensitive: false),
      (match) {
        final raw = match.group(0) ?? 'tháng $toNum';
        final startsUpper = raw.startsWith('T');
        return '${startsUpper ? 'Tháng' : 'tháng'} $toNum';
      },
    );
    updated = updated.replaceAllMapped(
      RegExp('\\bT0?$fromNum\\b'),
      (_) => 'T$toNum',
    );
    return updated;
  }

  static String normalizeRecurringBaseTitle(String title) {
    return title
        .replaceAll(
          RegExp(
            r'\s*(?:tháng\s*\d{1,2}(?:\/\d{4})?|T\d{1,2})\s*$',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
  }

  static Color parseHexColor(
    String? hex, {
    Color fallback = OmniColors.primary,
  }) {
    if (hex == null || hex.trim().isEmpty) return fallback;
    final cleaned = hex.trim().replaceFirst('#', '');
    if (cleaned.length == 6) {
      final val = int.tryParse('FF$cleaned', radix: 16);
      if (val != null) return Color(val);
    } else if (cleaned.length == 8) {
      final val = int.tryParse(cleaned, radix: 16);
      if (val != null) return Color(val);
    }
    return fallback;
  }
}

/// Nhóm chi phí (`GET/POST/PUT /finance/expense-groups`).
@immutable
class ExpenseGroup {
  const ExpenseGroup({
    required this.id,
    required this.name,
    required this.color,
    this.countsAsExpense = true,
    this.sortOrder = 0,
    this.archived = false,
    this.expenseCount = 0,
    this.yearTotal = 0,
  });

  factory ExpenseGroup.fromJson(Map<String, dynamic> json) {
    return ExpenseGroup(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      color: '${json['color'] ?? '#0A7D76'}',
      countsAsExpense: json['counts_as_expense'] != false,
      sortOrder: _asInt(json['sort_order']),
      archived: json['archived'] == true,
      expenseCount: _asInt(json['expense_count']),
      yearTotal: _asInt(json['year_total']),
    );
  }

  final String id;
  final String name;
  final String color;
  final bool countsAsExpense;
  final int sortOrder;
  final bool archived;
  final int expenseCount;
  final int yearTotal;

  Color get parsedColor => FinanceMonthUtils.parseHexColor(color);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': color,
    'counts_as_expense': countsAsExpense,
    'sort_order': sortOrder,
    'archived': archived,
    'expense_count': expenseCount,
    'year_total': yearTotal,
  };
}

/// Nguồn tiền (`/finance/money-accounts`).
@immutable
class MoneyAccount {
  const MoneyAccount({
    required this.id,
    required this.name,
    required this.kind,
    this.sortOrder = 0,
    this.archived = false,
    this.expenseCount = 0,
  });

  factory MoneyAccount.fromJson(Map<String, dynamic> json) {
    return MoneyAccount(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      kind: MoneyAccountKind.fromString(json['kind'] as String?),
      sortOrder: _asInt(json['sort_order']),
      archived: json['archived'] == true,
      expenseCount: _asInt(json['expense_count']),
    );
  }

  final String id;
  final String name;
  final MoneyAccountKind kind;
  final int sortOrder;
  final bool archived;
  final int expenseCount;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.apiValue,
    'sort_order': sortOrder,
    'archived': archived,
    'expense_count': expenseCount,
  };
}

/// Một lần thanh toán của khoản chi (`payments` trong `ExpenseItem`).
@immutable
class ExpensePayment {
  const ExpensePayment({
    required this.id,
    required this.paidOn,
    required this.amount,
    this.accountId,
    this.accountName,
    this.note,
  });

  factory ExpensePayment.fromJson(Map<String, dynamic> json) {
    return ExpensePayment(
      id: '${json['id'] ?? legacyPaymentId}',
      paidOn: '${json['paid_on'] ?? json['d'] ?? ''}',
      amount: _asInt(json['amount'] ?? json['a']),
      accountId: _asNullableString(json['account_id']),
      accountName: _asNullableString(json['account_name'] ?? json['acc']),
      note: _asNullableString(json['note']),
    );
  }

  static const String legacyPaymentId = 'legacy';

  final String id;
  final String paidOn;
  final int amount;
  final String? accountId;
  final String? accountName;
  final String? note;

  bool get isLegacy => id == legacyPaymentId || id.isEmpty;

  ExpensePayment copyWith({
    String? id,
    String? paidOn,
    int? amount,
    String? accountId,
    String? accountName,
    String? note,
  }) {
    return ExpensePayment(
      id: id ?? this.id,
      paidOn: paidOn ?? this.paidOn,
      amount: amount ?? this.amount,
      accountId: accountId ?? this.accountId,
      accountName: accountName ?? this.accountName,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toInputJson() => {
    if (!isLegacy) 'id': id,
    'paid_on': paidOn,
    'amount': amount,
    'account_id': accountId,
    'note': note,
  };
}

/// Khoản chi trong sổ tháng (`/finance/expenses`).
@immutable
class ExpenseItem {
  const ExpenseItem({
    required this.id,
    required this.spentOn,
    required this.month,
    required this.groupId,
    this.groupName,
    this.groupColor,
    this.countsAsExpense = true,
    required this.title,
    required this.amount,
    this.accountId,
    this.accountName,
    required this.status,
    this.paidAmount,
    required this.outstanding,
    this.note,
    this.importId,
    this.createdAt = '',
    this.rawCreatedAt,
    this.payments = const [],
    this.attachments = const [],
  });

  factory ExpenseItem.fromJson(Map<String, dynamic> json) {
    final rawPayments = json['payments'];
    final payments = rawPayments is List
        ? rawPayments
              .whereType<Map>()
              .map((e) => ExpensePayment.fromJson(e.cast<String, dynamic>()))
              .toList()
        : const <ExpensePayment>[];
    final rawAttachments = json['attachments'];
    final attachments = rawAttachments is List
        ? rawAttachments
              .whereType<Map>()
              .map((e) => ExpenseAttachment.fromJson(e.cast<String, dynamic>()))
              .toList()
        : const <ExpenseAttachment>[];
    final spentOn = '${json['spent_on'] ?? ''}';
    final month =
        _asNullableString(json['month']) ??
        (spentOn.length >= 7
            ? spentOn.substring(0, 7)
            : FinanceMonthUtils.currentVnMonth());
    final status = ExpenseStatus.fromString(json['status'] as String?);
    final amount = _asInt(json['amount']);
    final paidAmount = json['paid_amount'] == null
        ? null
        : _asInt(json['paid_amount']);
    final fallbackPaid = switch (status) {
      ExpenseStatus.paid => amount,
      ExpenseStatus.partial => paidAmount ?? 0,
      ExpenseStatus.unpaid => 0,
    };
    final outstanding = json['outstanding'] != null
        ? _asInt(json['outstanding'])
        : (amount < 0 ? 0 : math.max(0, amount - fallbackPaid));
    final rawCreated = _asNullableString(
      json['created_at'] ?? json['createdAt'],
    );
    final defaultCreated = spentOn.isNotEmpty
        ? FinanceMonthUtils.shortDayMonth(spentOn)
        : '';

    return ExpenseItem(
      id: '${json['id'] ?? ''}',
      spentOn: spentOn,
      month: FinanceMonthUtils.toYearMonth(month),
      groupId: '${json['group_id'] ?? ''}',
      groupName: _asNullableString(json['group_name']),
      groupColor: _asNullableString(json['group_color']),
      countsAsExpense: json['counts_as_expense'] != false,
      title: '${json['title'] ?? ''}',
      amount: amount,
      accountId: _asNullableString(json['account_id']),
      accountName: _asNullableString(json['account_name']),
      status: status,
      paidAmount: paidAmount,
      outstanding: outstanding,
      note: _asNullableString(json['note']),
      importId: _asNullableString(json['import_id']),
      createdAt: FinanceMonthUtils.formatServerTimestamp(
        rawCreated,
        fallback: defaultCreated,
      ),
      rawCreatedAt: rawCreated,
      payments: payments,
      attachments: attachments,
    );
  }

  final String id;
  final String spentOn;
  final String month;
  final String groupId;
  final String? groupName;
  final String? groupColor;
  final bool countsAsExpense;
  final String title;
  final int amount;
  final String? accountId;
  final String? accountName;
  final ExpenseStatus status;
  final int? paidAmount;
  final int outstanding;
  final String? note;
  final String? importId;

  /// Thời điểm nhập khoản chi theo giờ VN (`DD/MM HH:mm`, ví dụ `'02/11 09:30'`).
  final String createdAt;

  /// Chuỗi ISO-8601 gốc từ máy chủ (dùng để sắp xếp chính xác theo thời điểm nhập).
  final String? rawCreatedAt;
  final List<ExpensePayment> payments;
  final List<ExpenseAttachment> attachments;

  /// Khoản hoàn tiền / chiết khấu âm nhập từ Excel (API Ruling 18).
  bool get isRefund => amount < 0;

  /// Tổng tiền đã trả (khớp `ExpenseRules::paidPortion` trên API).
  int get paidTotal {
    if (amount < 0) return amount;
    if (payments.isNotEmpty) {
      return payments.fold<int>(0, (sum, p) => sum + p.amount);
    }
    return switch (status) {
      ExpenseStatus.paid => amount,
      ExpenseStatus.partial => paidAmount ?? math.max(0, amount - outstanding),
      ExpenseStatus.unpaid => 0,
    };
  }

  /// Phần còn phải trả (khớp `ExpenseRules::outstanding` trên API).
  int get remainingAmount {
    if (amount < 0) return 0;
    if (payments.isNotEmpty && !payments.any((p) => p.isLegacy)) {
      return math.max(0, amount - paidTotal);
    }
    return math.max(0, outstanding);
  }

  bool get isPaid =>
      status == ExpenseStatus.paid || (amount > 0 && remainingAmount <= 0);
  bool get isPartial =>
      !isPaid && (status == ExpenseStatus.partial || paidTotal > 0);
  bool get isUnpaid => !isPaid && !isPartial;

  /// Đúng khi khoản này đã được trả đủ trong đúng 1 lần duy nhất (`one = pays.length <= 1 && !left`).
  bool get isSingleFullPayment => isPaid && payments.length <= 1;

  bool get hasPaymentHistory => payments.isNotEmpty || paidTotal > 0;

  bool get hasStoredPayments =>
      payments.isNotEmpty && !payments.any((p) => p.isLegacy);

  Color get resolvedColor => FinanceMonthUtils.parseHexColor(
    groupColor ?? FinanceSeedCatalog.colorForGroupId(groupId),
  );

  String get resolvedGroupName =>
      (groupName != null && groupName!.trim().isNotEmpty)
      ? groupName!
      : FinanceSeedCatalog.nameForGroupId(groupId);

  /// Phụ đề dòng: `Tên nhóm · Nguồn tiền`.
  String get rowSubtitle {
    final acc = effectiveAccountName;
    if (acc != null && acc.isNotEmpty) {
      return '$resolvedGroupName · $acc';
    }
    return resolvedGroupName;
  }

  /// Nguồn tiền hiển thị: ưu tiên nguồn của lần trả, sau đó đến `accountName` (không tự bịa khi rỗng).
  String? get effectiveAccountName {
    final distinctNames = <String>[];
    for (final p in payments) {
      final name = p.accountName?.trim();
      if (name != null && name.isNotEmpty && !distinctNames.contains(name)) {
        distinctNames.add(name);
      }
    }
    if (distinctNames.length == 1) return distinctNames.first;
    if (distinctNames.length > 1) {
      return '${distinctNames.last} (+${distinctNames.length - 1})';
    }
    if (accountName != null && accountName!.trim().isNotEmpty) {
      return accountName!.trim();
    }
    return null;
  }

  String? defaultPaymentAccountId(List<MoneyAccount> accounts) {
    final usable = {
      for (final a in accounts)
        if (!a.archived) a.id,
    };
    final lastPaymentAcc = payments.isNotEmpty ? payments.last.accountId : null;
    final cashAcc = accounts
        .where((a) => !a.archived && a.kind == MoneyAccountKind.cash)
        .map((a) => a.id)
        .firstOrNull;
    for (final candidate in [lastPaymentAcc, accountId, cashAcc]) {
      if (candidate != null && usable.contains(candidate)) {
        return candidate;
      }
    }
    return accounts.where((a) => !a.archived).map((a) => a.id).firstOrNull;
  }

  List<Map<String, dynamic>> buildAddPaymentInputs({
    required String paidOn,
    required int paymentAmount,
    String? paymentAccountId,
    String? note,
  }) {
    final safePaidOn = FinanceMonthUtils.clampPaidOn(paidOn);
    return [
      for (final p in payments) p.toInputJson(),
      {
        'paid_on': safePaidOn,
        'amount': paymentAmount,
        'account_id': paymentAccountId ?? accountId,
        'note': note,
      },
    ];
  }

  List<Map<String, dynamic>>? buildPayInFullInputs({
    required String today,
    String? defaultAccountId,
  }) {
    final rest = remainingAmount;
    if (rest <= 0) return null;
    return buildAddPaymentInputs(
      paidOn: today,
      paymentAmount: rest,
      paymentAccountId: defaultAccountId ?? accountId,
    );
  }

  Map<String, dynamic> buildAmountUpdateBody(int newAmount) {
    if (!hasStoredPayments &&
        status == ExpenseStatus.partial &&
        paidAmount != null &&
        paidAmount! >= newAmount) {
      return {'amount': newAmount, 'status': ExpenseStatus.paid.apiValue};
    }
    return {'amount': newAmount};
  }

  /// Giờ nhập rút gọn (`09:30`) trích từ `createdAt` (`02/11 09:30`).
  String get createdTimeOnly {
    final parts = createdAt.trim().split(RegExp(r'\s+'));
    return parts.length > 1 ? parts.last : createdAt;
  }

  /// Ngày thanh toán gần nhất (`YYYY-MM-DD`), hoặc `''` nếu chưa thanh toán.
  String get lastPaidDateIso {
    if (payments.isNotEmpty) {
      return payments.last.paidOn;
    }
    return isPaid ? spentOn : '';
  }

  ExpenseItem copyWith({
    String? id,
    String? spentOn,
    String? month,
    String? groupId,
    String? groupName,
    String? groupColor,
    bool? countsAsExpense,
    String? title,
    int? amount,
    String? accountId,
    String? accountName,
    ExpenseStatus? status,
    int? paidAmount,
    int? outstanding,
    String? note,
    String? createdAt,
    String? rawCreatedAt,
    List<ExpensePayment>? payments,
    List<ExpenseAttachment>? attachments,
  }) {
    return ExpenseItem(
      id: id ?? this.id,
      spentOn: spentOn ?? this.spentOn,
      month: month ?? this.month,
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      groupColor: groupColor ?? this.groupColor,
      countsAsExpense: countsAsExpense ?? this.countsAsExpense,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      accountId: accountId ?? this.accountId,
      accountName: accountName ?? this.accountName,
      status: status ?? this.status,
      paidAmount: paidAmount ?? this.paidAmount,
      outstanding: outstanding ?? this.outstanding,
      note: note ?? this.note,
      importId: importId,
      createdAt: createdAt ?? this.createdAt,
      rawCreatedAt: rawCreatedAt ?? this.rawCreatedAt,
      payments: payments ?? this.payments,
      attachments: attachments ?? this.attachments,
    );
  }
}

/// Tổng hợp theo nhóm trong `summary.by_group`.
@immutable
class LedgerGroupTotal {
  const LedgerGroupTotal({
    required this.groupId,
    this.name,
    this.color,
    this.countsAsExpense = true,
    required this.amount,
    required this.count,
  });

  factory LedgerGroupTotal.fromJson(Map<String, dynamic> json) {
    return LedgerGroupTotal(
      groupId: '${json['group_id'] ?? ''}',
      name: _asNullableString(json['name']),
      color: _asNullableString(json['color']),
      countsAsExpense: json['counts_as_expense'] != false,
      amount: _asInt(json['amount']),
      count: _asInt(json['count']),
    );
  }

  final String groupId;
  final String? name;
  final String? color;
  final bool countsAsExpense;
  final int amount;
  final int count;

  Color get resolvedColor => FinanceMonthUtils.parseHexColor(
    color ?? FinanceSeedCatalog.colorForGroupId(groupId),
  );
  String get resolvedName => (name != null && name!.trim().isNotEmpty)
      ? name!
      : FinanceSeedCatalog.nameForGroupId(groupId);
}

@immutable
class LedgerExcludedSummary {
  const LedgerExcludedSummary({required this.total, required this.count});

  factory LedgerExcludedSummary.fromJson(Map<String, dynamic> json) {
    return LedgerExcludedSummary(
      total: _asInt(json['total']),
      count: _asInt(json['count']),
    );
  }

  final int total;
  final int count;
}

@immutable
class LedgerPrevMonthSummary {
  const LedgerPrevMonthSummary({required this.month, required this.total});

  factory LedgerPrevMonthSummary.fromJson(Map<String, dynamic> json) {
    return LedgerPrevMonthSummary(
      month: '${json['month'] ?? ''}',
      total: _asInt(json['total']),
    );
  }

  final String month;
  final int total;
}

@immutable
class LedgerCashOutSummary {
  const LedgerCashOutSummary({required this.total, required this.earlier});

  factory LedgerCashOutSummary.fromJson(Map<String, dynamic> json) {
    return LedgerCashOutSummary(
      total: _asInt(json['total']),
      earlier: _asInt(json['earlier']),
    );
  }

  final int total;
  final int earlier;
}

/// Tóm tắt cả tháng trong `GET /finance/expenses?month=`.
@immutable
class LedgerSummary {
  const LedgerSummary({
    required this.total,
    required this.paid,
    required this.outstanding,
    required this.count,
    required this.paidCount,
    required this.unpaidCount,
    required this.partialCount,
    this.excluded = const LedgerExcludedSummary(total: 0, count: 0),
    this.byGroup = const [],
    this.prevMonth = const LedgerPrevMonthSummary(month: '', total: 0),
    this.revenue = 0,
    this.cashOut = const LedgerCashOutSummary(total: 0, earlier: 0),
  });

  factory LedgerSummary.fromJson(Map<String, dynamic> json) {
    final rawByGroup = json['by_group'];
    final byGroup = rawByGroup is List
        ? rawByGroup
              .whereType<Map>()
              .map((e) => LedgerGroupTotal.fromJson(e.cast<String, dynamic>()))
              .toList()
        : const <LedgerGroupTotal>[];
    final excludedMap = json['excluded'] is Map
        ? (json['excluded'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final prevMonthMap = json['prev_month'] is Map
        ? (json['prev_month'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final cashOutMap = json['cash_out'] is Map
        ? (json['cash_out'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};

    return LedgerSummary(
      total: _asInt(json['total']),
      paid: _asInt(json['paid']),
      outstanding: _asInt(json['outstanding']),
      count: _asInt(json['count']),
      paidCount: _asInt(json['paid_count']),
      unpaidCount: _asInt(json['unpaid_count']),
      partialCount: _asInt(json['partial_count']),
      excluded: LedgerExcludedSummary.fromJson(excludedMap),
      byGroup: byGroup,
      prevMonth: LedgerPrevMonthSummary.fromJson(prevMonthMap),
      revenue: _asInt(json['revenue']),
      cashOut: LedgerCashOutSummary.fromJson(cashOutMap),
    );
  }

  /// Tự tính `LedgerSummary` lạc quan từ danh sách `items` (khớp `ExpenseSummary.php`),
  /// bảo toàn `prevMonth`, `revenue` và `cashOut` của máy chủ.
  factory LedgerSummary.fromItems({
    required List<ExpenseItem> items,
    required List<ExpenseGroup> groups,
    LedgerPrevMonthSummary prevMonth = const LedgerPrevMonthSummary(
      month: '',
      total: 0,
    ),
    int revenue = 0,
    LedgerCashOutSummary cashOut = const LedgerCashOutSummary(
      total: 0,
      earlier: 0,
    ),
  }) {
    var total = 0;
    var paid = 0;
    var outstanding = 0;
    var count = 0;
    var paidCount = 0;
    var unpaidCount = 0;
    var partialCount = 0;
    var excludedTotal = 0;
    var excludedCount = 0;
    final groupSums = <String, int>{};
    final groupCounts = <String, int>{};
    final groupItemMeta = <String, ExpenseItem>{};

    final groupMap = {for (final g in groups) g.id: g};

    for (final item in items) {
      final grp = groupMap[item.groupId];
      final counts = grp?.countsAsExpense ?? item.countsAsExpense;
      if (!counts) {
        excludedTotal += item.amount;
        excludedCount++;
      } else {
        total += item.amount;
        paid += item.paidTotal;
        outstanding += item.remainingAmount;
        count++;
        if (item.isPaid) {
          paidCount++;
        } else if (item.isPartial) {
          partialCount++;
        } else {
          unpaidCount++;
        }
      }
      groupSums[item.groupId] = (groupSums[item.groupId] ?? 0) + item.amount;
      groupCounts[item.groupId] = (groupCounts[item.groupId] ?? 0) + 1;
      groupItemMeta.putIfAbsent(item.groupId, () => item);
    }

    final byGroup =
        <LedgerGroupTotal>[
          for (final entry in groupSums.entries)
            LedgerGroupTotal(
              groupId: entry.key,
              name:
                  groupMap[entry.key]?.name ??
                  groupItemMeta[entry.key]?.groupName ??
                  FinanceSeedCatalog.nameForGroupId(entry.key),
              color:
                  groupMap[entry.key]?.color ??
                  groupItemMeta[entry.key]?.groupColor ??
                  FinanceSeedCatalog.colorForGroupId(entry.key),
              countsAsExpense:
                  groupMap[entry.key]?.countsAsExpense ??
                  groupItemMeta[entry.key]?.countsAsExpense ??
                  true,
              amount: entry.value,
              count: groupCounts[entry.key] ?? 1,
            ),
        ]..sort((a, b) {
          final c = b.amount.compareTo(a.amount);
          return c != 0 ? c : a.resolvedName.compareTo(b.resolvedName);
        });

    return LedgerSummary(
      total: total,
      paid: paid,
      outstanding: outstanding,
      count: count,
      paidCount: paidCount,
      unpaidCount: unpaidCount,
      partialCount: partialCount,
      excluded: LedgerExcludedSummary(
        total: excludedTotal,
        count: excludedCount,
      ),
      byGroup: byGroup,
      prevMonth: prevMonth,
      revenue: revenue,
      cashOut: cashOut,
    );
  }

  final int total;
  final int paid;
  final int outstanding;
  final int count;
  final int paidCount;
  final int unpaidCount;
  final int partialCount;
  final LedgerExcludedSummary excluded;
  final List<LedgerGroupTotal> byGroup;
  final LedgerPrevMonthSummary prevMonth;
  final int revenue;
  final LedgerCashOutSummary cashOut;

  int get owedCount => unpaidCount + partialCount;

  double get paidRatio => total > 0 ? (paid / total).clamp(0.0, 1.0) : 1.0;

  /// Thông tin pill so sánh với tháng liền trước (`+8% vs T10` hoặc `−14% vs T10`).
  ({String text, bool isIncrease})? get deltaPill {
    if (prevMonth.total <= 0 || total <= 0 || prevMonth.month.isEmpty) {
      return null;
    }
    final diff = total - prevMonth.total;
    final dp = (diff.abs() / prevMonth.total * 100).round();
    final prevNum = FinanceMonthUtils.monthNumberOf(prevMonth.month);
    final sign = diff >= 0 ? '+' : '−';
    return (text: '$sign$dp% vs T$prevNum', isIncrease: diff > 0);
  }
}

/// Dữ liệu sổ chi phí của một tháng (`GET /finance/expenses?month=`).
@immutable
class MonthLedger {
  const MonthLedger({
    required this.month,
    required this.items,
    this.truncated = false,
    required this.summary,
  });

  factory MonthLedger.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map((e) => ExpenseItem.fromJson(e.cast<String, dynamic>()))
              .toList()
        : const <ExpenseItem>[];
    final summaryMap = json['summary'] is Map
        ? (json['summary'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};

    return MonthLedger(
      month: FinanceMonthUtils.toYearMonth(
        '${json['month'] ?? FinanceMonthUtils.currentVnMonth()}',
      ),
      items: items,
      truncated: json['truncated'] == true,
      summary: LedgerSummary.fromJson(summaryMap),
    );
  }

  final String month;
  final List<ExpenseItem> items;
  final bool truncated;
  final LedgerSummary summary;
}

/// Gợi ý khoản chi cố định đầu tháng (`RECUR`).
@immutable
class RecurringExpenseSuggestion {
  const RecurringExpenseSuggestion({
    required this.key,
    required this.baseTitle,
    required this.titleForMonth,
    required this.groupId,
    required this.groupName,
    required this.groupColor,
    required this.suggestedAmount,
    required this.spentOnForMonth,
    this.accountId,
    this.accountName,
    this.history = const [],
  });

  final String key;
  final String baseTitle;
  final String titleForMonth;
  final String groupId;
  final String groupName;
  final String groupColor;
  final int suggestedAmount;
  final String spentOnForMonth;
  final String? accountId;
  final String? accountName;
  final List<({String monthLabel, int amount})> history;

  Color get resolvedColor => FinanceMonthUtils.parseHexColor(groupColor);
}

/// Danh mục chuẩn, tiện ích gợi ý lịch sử 3 tháng và dữ liệu mẫu dùng riêng cho Demo Mode / Unit Test.
abstract final class FinanceSeedCatalog {
  /// 5 mẫu khoản cố định chuẩn (khớp `DefaultFinanceCatalog::RECURRING_TEMPLATES` trên API).
  static const List<RecurringTemplateMeta> defaultRecurringTemplates = [
    RecurringTemplateMeta(
      key: 'chi_phi_kho',
      title: 'Chi phí kho',
      seedKey: 'thue_kho',
      groupName: 'Thuê kho',
    ),
    RecurringTemplateMeta(
      key: 'dien_nuoc',
      title: 'Điện nước',
      seedKey: 'dien_nuoc',
      groupName: 'Điện nước & tiện ích',
    ),
    RecurringTemplateMeta(
      key: 'luong_nhan_su',
      title: 'Lương nhân sự',
      seedKey: 'luong_thuong',
      groupName: 'Lương & Thưởng',
    ),
    RecurringTemplateMeta(
      key: 'lai_vay',
      title: 'Lãi vay',
      seedKey: 'lai_vay',
      groupName: 'Lãi vay',
    ),
    RecurringTemplateMeta(
      key: 'ke_toan_dich_vu',
      title: 'Lương kế toán dịch vụ',
      seedKey: 'thue_phi',
      groupName: 'Thuế & phí',
    ),
  ];

  static const List<ExpenseGroup> defaultGroups = [
    ExpenseGroup(
      id: 'op',
      name: 'Kho bãi & vận hành',
      color: '#0A7D76',
      sortOrder: 1,
    ),
    ExpenseGroup(
      id: 'pe',
      name: 'Nhân sự & tiền lương',
      color: '#2563EB',
      sortOrder: 2,
    ),
    ExpenseGroup(
      id: 'fn',
      name: 'Lãi vay & tài chính',
      color: '#7C3AED',
      sortOrder: 3,
    ),
    ExpenseGroup(
      id: 'ad',
      name: 'Kế toán & hành chính',
      color: '#64748B',
      sortOrder: 4,
    ),
    ExpenseGroup(
      id: 'mk',
      name: 'Tiếp thị & bán hàng',
      color: '#D97706',
      sortOrder: 5,
    ),
    ExpenseGroup(
      id: 'sw',
      name: 'Phần mềm & tên miền',
      color: '#1D4ED8',
      sortOrder: 6,
    ),
    ExpenseGroup(
      id: 'ot',
      name: 'Chi phí khác',
      color: '#94A3B8',
      sortOrder: 7,
    ),
  ];

  static const List<MoneyAccount> defaultAccounts = [
    MoneyAccount(
      id: 'acc_bank',
      name: 'TK ngân hàng',
      kind: MoneyAccountKind.bank,
      sortOrder: 1,
    ),
    MoneyAccount(
      id: 'acc_cash',
      name: 'Tiền mặt',
      kind: MoneyAccountKind.cash,
      sortOrder: 2,
    ),
    MoneyAccount(
      id: 'acc_wallet',
      name: 'Tiền ứng',
      kind: MoneyAccountKind.advance,
      sortOrder: 3,
    ),
  ];

  /// Tạo danh sách chip gợi ý trên bàn phím từ lịch sử 3 tháng gần nhất (`histChips`).
  static List<({String label, int amount})> buildHistoryChips(
    List<({String monthLabel, int amount})>? history,
  ) {
    if (history == null || history.isEmpty) return const [];
    final chips = <({String label, int amount})>[
      for (final item in history.reversed)
        (
          label:
              '${item.monthLabel} · ${FinanceMonthUtils.formatNumber(item.amount)}',
          amount: item.amount,
        ),
    ];
    final firstVal = history.first.amount;
    if (history.any((x) => x.amount != firstVal)) {
      final sum = history.fold<int>(0, (s, x) => s + x.amount);
      final avg = (sum / history.length).round();
      chips.add((
        label: 'TB 3 tháng · ${FinanceMonthUtils.formatNumber(avg)}',
        amount: avg,
      ));
    }
    return chips;
  }

  static String nameForGroupId(String groupId) {
    for (final g in defaultGroups) {
      if (g.id == groupId) return g.name;
    }
    return 'Khác';
  }

  static String colorForGroupId(String groupId) {
    for (final g in defaultGroups) {
      if (g.id == groupId) return g.color;
    }
    return '#94A3B8';
  }
}

int _asInt(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

String? _asNullableString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
