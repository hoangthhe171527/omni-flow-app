import 'dart:math' as math;

import 'package:flutter/material.dart';

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
  advance('advance', 'Ví điện tử');

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

/// Chứng từ / tệp đính kèm chứng minh khoản chi (ảnh phiếu chi, hoá đơn, PDF).
@immutable
class ExpenseAttachment {
  const ExpenseAttachment({
    required this.id,
    required this.name,
    this.kind = 'image',
    this.sizeLabel = '320 KB',
    this.uploadedAt = '02/11 09:30',
  });

  factory ExpenseAttachment.fromJson(Map<String, dynamic> json) {
    return ExpenseAttachment(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      kind: '${json['kind'] ?? 'image'}',
      sizeLabel: '${json['size_label'] ?? json['sizeLabel'] ?? '320 KB'}',
      uploadedAt: '${json['uploaded_at'] ?? json['uploadedAt'] ?? ''}',
    );
  }

  final String id;
  final String name;

  /// `'image'` hoặc `'pdf'`.
  final String kind;
  final String sizeLabel;
  final String uploadedAt;

  bool get isPdf => kind.toLowerCase() == 'pdf' || name.toLowerCase().endsWith('.pdf');

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind,
    'size_label': sizeLabel,
    'uploaded_at': uploadedAt,
  };
}

/// Tiện ích tháng `YYYY-MM` / `MM/YYYY` và ngày `YYYY-MM-DD` / `DD/MM`.
abstract final class FinanceMonthUtils {
  /// Định dạng số nguyên kiểu `vi-VN` không kèm hậu tố `đ` (vd `12.000.000`).
  static String formatNumber(num? value) {
    final s = Formatters.vnd((value ?? 0).round().abs());
    return s.endsWith('đ') ? s.substring(0, s.length - 1) : s;
  }

  /// Định dạng tiền tệ kèm khoảng trắng `12.000.000 đ` giống hệt mẫu `so-chi-phi-mobile.html`.
  static String formatVndSpace(num? value) => '${formatNumber(value)} đ';

  static String currentVnMonth([DateTime? clock]) {
    final now = VnTime.now(clock);
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  /// Chuẩn hoá chuỗi tháng bất kỳ (`11/2026` hoặc `2026-11`) về `YYYY-MM`.
  static String toYearMonth(String raw) {
    final trimmed = raw.trim();
    if (trimmed.contains('/')) {
      final parts = trimmed.split('/');
      if (parts.length == 2) {
        final m = (int.tryParse(parts[0]) ?? 1).toString().padLeft(2, '0');
        final y = (int.tryParse(parts[1]) ?? 2026).toString().padLeft(4, '0');
        return '$y-$m';
      }
    }
    if (trimmed.contains('-')) {
      final parts = trimmed.split('-');
      if (parts.length >= 2) {
        final y = (int.tryParse(parts[0]) ?? 2026).toString().padLeft(4, '0');
        final m = (int.tryParse(parts[1]) ?? 1).toString().padLeft(2, '0');
        return '$y-$m';
      }
    }
    return '2026-11';
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
    return parts.isNotEmpty ? (int.tryParse(parts[0]) ?? 2026) : 2026;
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

  static String todayIso([DateTime? clock]) {
    final today = VnTime.today(clock);
    return formatIsoDate(today);
  }

  static String formatIsoDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static DateTime parseIsoDate(String ymd, {String? fallbackMonth}) {
    final trimmed = ymd.trim();
    if (trimmed.contains('-') && trimmed.length >= 10) {
      final parts = trimmed.split('-');
      final y = int.tryParse(parts[0]) ?? 2026;
      final m = int.tryParse(parts[1]) ?? 1;
      final d = int.tryParse(parts[2]) ?? 1;
      return DateTime(y, m, d);
    }
    if (trimmed.contains('/')) {
      final parts = trimmed.split('/');
      if (parts.length >= 2) {
        final d = int.tryParse(parts[0]) ?? 1;
        final m = int.tryParse(parts[1]) ?? 1;
        final y = parts.length >= 3
            ? (int.tryParse(parts[2]) ?? 2026)
            : (fallbackMonth != null ? yearOf(fallbackMonth) : 2026);
        return DateTime(y, m, d);
      }
    }
    return DateTime.tryParse(trimmed) ?? DateTime(2026, 11, 2);
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
      final d = (int.tryParse(parts[0]) ?? 1).toString().padLeft(2, '0');
      final m = parts.length > 1
          ? (int.tryParse(parts[1]) ?? monthNumberOf(ym)).toString().padLeft(
              2,
              '0',
            )
          : monthNumberOf(ym).toString().padLeft(2, '0');
      return '$y-$m-$d';
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

  /// Ngày mặc định trong tháng theo mẫu thiết kế (`02/11` cho T11/2026 hoặc `05/MM`).
  static String defaultSpentOnForMonth(String ymOrSlash, [DateTime? clock]) {
    final ym = toYearMonth(ymOrSlash);
    if (ym == '2026-11') return '2026-11-02';
    final current = currentVnMonth(clock);
    if (ym == current) return todayIso(clock);
    return '$ym-05';
  }

  /// Nhãn tiêu đề ngày trên danh sách: `Hôm nay · 02/11/2026` hoặc `01/11/2026`.
  static String dayHeaderLabel(String ymd, {String? activeMonth}) {
    final full = fullDayMonthYear(ymd, fallbackMonth: activeMonth);
    final short = shortDayMonth(ymd);
    final todayShort = shortDayMonth(todayIso());
    if ((short == '02/11' &&
            (activeMonth == null || toYearMonth(activeMonth) == '2026-11')) ||
        short == todayShort) {
      return 'Hôm nay · $full';
    }
    return full;
  }

  /// Danh sách các ngày gợi ý nhanh trong popover chọn ngày của tháng `ym`.
  static List<({String isoDate, String label})> quickDatesForMonth(
    String ymOrSlash,
  ) {
    final ym = toYearMonth(ymOrSlash);
    final y = yearOf(ym);
    final m = monthNumberOf(ym).toString().padLeft(2, '0');
    final defaultIso = defaultSpentOnForMonth(ym);
    final defaultDm = shortDayMonth(defaultIso);
    final candidates = <String>[
      defaultDm,
      '01/$m',
      '02/$m',
      '03/$m',
      '05/$m',
      '10/$m',
      '15/$m',
      '20/$m',
      '25/$m',
    ];
    final seen = <String>{};
    final result = <({String isoDate, String label})>[];
    for (final dm in candidates) {
      if (!seen.add(dm)) continue;
      final iso = toIsoDate(dm, ym);
      final isToday = dm == defaultDm && ym == '2026-11';
      result.add((
        isoDate: iso,
        label: '${isToday ? 'Hôm nay · ' : ''}$dm/$y',
      ));
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
    'account_name': accountName,
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
    this.createdAt = '02/11 09:00',
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
        (spentOn.length >= 7 ? spentOn.substring(0, 7) : '2026-11');
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
        : math.max(0, amount - fallbackPaid);
    final defaultCreated =
        '${FinanceMonthUtils.shortDayMonth(spentOn.isNotEmpty ? spentOn : '2026-11-02')} 09:00';

    return ExpenseItem(
      id: '${json['id'] ?? ''}',
      spentOn: spentOn,
      month: FinanceMonthUtils.toYearMonth(month),
      groupId: '${json['group_id'] ?? 'op'}',
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
      createdAt:
          _asNullableString(json['created_at'] ?? json['createdAt']) ??
          defaultCreated,
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

  /// Thời điểm nhập khoản chi (`DD/MM HH:mm`, ví dụ `'02/11 09:30'`).
  final String createdAt;
  final List<ExpensePayment> payments;
  final List<ExpenseAttachment> attachments;

  /// Tổng tiền đã trả.
  int get paidTotal {
    if (payments.isNotEmpty) {
      return payments.fold<int>(0, (sum, p) => sum + p.amount);
    }
    return switch (status) {
      ExpenseStatus.paid => amount,
      ExpenseStatus.partial => paidAmount ?? math.max(0, amount - outstanding),
      ExpenseStatus.unpaid => 0,
    };
  }

  /// Phần còn phải trả.
  int get remainingAmount {
    if (payments.isNotEmpty) {
      return math.max(0, amount - paidTotal);
    }
    return math.max(0, outstanding);
  }

  bool get isPaid => status == ExpenseStatus.paid || remainingAmount <= 0;
  bool get isPartial => !isPaid && paidTotal > 0;
  bool get isUnpaid => !isPaid && paidTotal <= 0;

  /// Đúng khi khoản này đã được trả đủ trong đúng 1 lần duy nhất (`one = pays.length === 1 && !left`).
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

  /// Nguồn tiền hiển thị: ưu tiên nguồn của lần trả cuối, sau đó đến `accountName`.
  String? get effectiveAccountName {
    for (var i = payments.length - 1; i >= 0; i--) {
      final name = payments[i].accountName;
      if (name != null && name.trim().isNotEmpty) return name;
    }
    if (accountName != null && accountName!.trim().isNotEmpty) {
      return accountName;
    }
    return 'TK ngân hàng';
  }

  String? defaultPaymentAccountId(List<MoneyAccount> accounts) {
    final usable = {
      for (final a in accounts)
        if (!a.archived) a.id,
    };
    final lastPaymentAcc = payments.isNotEmpty
        ? payments.last.accountId
        : null;
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
    String? paymentAccountName,
    String? note,
  }) {
    return [
      for (final p in payments) p.toInputJson(),
      {
        'paid_on': paidOn,
        'amount': paymentAmount,
        'account_id': paymentAccountId ?? accountId,
        'account_name': paymentAccountName ?? effectiveAccountName,
        'note': note,
      },
    ];
  }

  List<Map<String, dynamic>>? buildPayInFullInputs({
    required String today,
    String? defaultAccountId,
    String? defaultAccountName,
  }) {
    final rest = remainingAmount;
    if (rest <= 0) return null;
    return buildAddPaymentInputs(
      paidOn: today,
      paymentAmount: rest,
      paymentAccountId: defaultAccountId ?? accountId,
      paymentAccountName: defaultAccountName ?? effectiveAccountName,
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

  /// Tự tính `LedgerSummary` từ danh sách `items` và tổng tháng trước `prevMonthTotal`.
  factory LedgerSummary.fromItems({
    required List<ExpenseItem> items,
    required List<ExpenseGroup> groups,
    String prevMonth = '',
    int prevMonthTotal = 0,
  }) {
    var total = 0;
    var paid = 0;
    var paidCount = 0;
    var unpaidCount = 0;
    var partialCount = 0;
    var excludedTotal = 0;
    var excludedCount = 0;
    final groupSums = <String, int>{};
    final groupCounts = <String, int>{};

    for (final item in items) {
      if (!item.countsAsExpense) {
        excludedTotal += item.amount;
        excludedCount++;
      } else {
        total += item.amount;
        paid += item.paidTotal;
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
    }

    final groupMap = {for (final g in groups) g.id: g};
    final byGroup = <LedgerGroupTotal>[
      for (final entry in groupSums.entries)
        if (entry.value > 0)
          LedgerGroupTotal(
            groupId: entry.key,
            name:
                groupMap[entry.key]?.name ??
                FinanceSeedCatalog.nameForGroupId(entry.key),
            color:
                groupMap[entry.key]?.color ??
                FinanceSeedCatalog.colorForGroupId(entry.key),
            countsAsExpense: groupMap[entry.key]?.countsAsExpense ?? true,
            amount: entry.value,
            count: groupCounts[entry.key] ?? 1,
          ),
    ]..sort((a, b) => b.amount.compareTo(a.amount));

    final outstanding = math.max(0, total - paid);
    return LedgerSummary(
      total: total,
      paid: paid,
      outstanding: outstanding,
      count: items.where((e) => e.countsAsExpense).length,
      paidCount: paidCount,
      unpaidCount: unpaidCount,
      partialCount: partialCount,
      excluded: LedgerExcludedSummary(
        total: excludedTotal,
        count: excludedCount,
      ),
      byGroup: byGroup,
      prevMonth: LedgerPrevMonthSummary(
        month: prevMonth,
        total: prevMonthTotal,
      ),
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

  double get paidRatio =>
      total > 0 ? (paid / total).clamp(0.0, 1.0) : 1.0;

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
      month: FinanceMonthUtils.toYearMonth('${json['month'] ?? '2026-11'}'),
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

/// Gợi ý khoản chi cố định đầu tháng (`RECUR` trong mẫu thiết kế).
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
    this.accountName = 'TK ngân hàng',
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

/// Danh mục nhóm chuẩn Viomni Orbit, 3 nguồn tiền, 5 khoản cố định hàng tháng, lịch sử 3 tháng và dữ liệu mẫu.
abstract final class FinanceSeedCatalog {
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
      name: 'Ví điện tử',
      kind: MoneyAccountKind.advance,
      sortOrder: 3,
    ),
  ];

  static const List<String> defaultAccountNames = [
    'TK ngân hàng',
    'Tiền mặt',
    'Ví điện tử',
  ];

  static const List<String> segMonths = ['2026-09', '2026-10', '2026-11'];

  static const List<String> allMonths = [
    '2026-06',
    '2026-07',
    '2026-08',
    '2026-09',
    '2026-10',
    '2026-11',
  ];

  /// 5 gợi ý nhanh trong sheet "Thêm chi phí" khớp 5 khoản cố định hàng tháng của anh Lê Nguyên.
  static const List<({String label, String title, int amount, String groupId})>
  quickAddPresets = [
    (
      label: 'Chi phí kho · 12tr',
      title: 'Chi phí kho',
      amount: 12000000,
      groupId: 'op',
    ),
    (
      label: 'Điện nước · 1,85tr',
      title: 'Điện nước',
      amount: 1850000,
      groupId: 'op',
    ),
    (
      label: 'Lương nhân sự · 18tr',
      title: 'Lương nhân sự',
      amount: 18000000,
      groupId: 'pe',
    ),
    (
      label: 'Lãi vay · 6,5tr',
      title: 'Lãi vay',
      amount: 6500000,
      groupId: 'fn',
    ),
    (
      label: 'Lương kế toán DV · 3tr',
      title: 'Lương kế toán dịch vụ',
      amount: 3000000,
      groupId: 'ad',
    ),
  ];

  static List<({String label, String title, int amount, String groupId})>
  get quickChips => quickAddPresets;

  /// Lịch sử 3 tháng gần nhất (`HIST`) để gợi ý chip 1 chạm trên bàn phím số cho cả 5 khoản cố định.
  static const Map<String, List<({String monthLabel, int amount})>>
  historyTable = {
    'Chi phí kho': [
      (monthLabel: 'T8', amount: 12000000),
      (monthLabel: 'T9', amount: 12000000),
      (monthLabel: 'T10', amount: 12000000),
    ],
    'Điện nước': [
      (monthLabel: 'T8', amount: 1790000),
      (monthLabel: 'T9', amount: 1920000),
      (monthLabel: 'T10', amount: 1850000),
    ],
    'Lương nhân sự': [
      (monthLabel: 'T8', amount: 17500000),
      (monthLabel: 'T9', amount: 18000000),
      (monthLabel: 'T10', amount: 18000000),
    ],
    'Lãi vay': [
      (monthLabel: 'T8', amount: 6500000),
      (monthLabel: 'T9', amount: 6500000),
      (monthLabel: 'T10', amount: 6500000),
    ],
    'Lương kế toán dịch vụ': [
      (monthLabel: 'T8', amount: 3000000),
      (monthLabel: 'T9', amount: 3000000),
      (monthLabel: 'T10', amount: 3000000),
    ],
    'Tiền thuê mặt bằng': [
      (monthLabel: 'T8', amount: 12000000),
      (monthLabel: 'T9', amount: 12000000),
      (monthLabel: 'T10', amount: 12000000),
    ],
    'Internet + Điện nước': [
      (monthLabel: 'T8', amount: 1790000),
      (monthLabel: 'T9', amount: 1920000),
      (monthLabel: 'T10', amount: 1850000),
    ],
    'Phí phần mềm CRM': [
      (monthLabel: 'T8', amount: 1600000),
      (monthLabel: 'T9', amount: 1600000),
      (monthLabel: 'T10', amount: 1600000),
    ],
    'Lương bộ phận': [
      (monthLabel: 'T8', amount: 18000000),
      (monthLabel: 'T9', amount: 18000000),
      (monthLabel: 'T10', amount: 18000000),
    ],
    'Quảng cáo Facebook': [
      (monthLabel: 'T8', amount: 4200000),
      (monthLabel: 'T9', amount: 5000000),
      (monthLabel: 'T10', amount: 4500000),
    ],
    'Phí hosting': [
      (monthLabel: 'T8', amount: 2450000),
      (monthLabel: 'T9', amount: 2450000),
      (monthLabel: 'T10', amount: 2450000),
    ],
  };

  static Map<String, List<({String monthLabel, int amount})>>
  get historyByTitlePrefix => historyTable;

  /// Tìm lịch sử 3 tháng cho tiêu đề `title` (khớp tiền tố như `histFor` trong HTML).
  static List<({String monthLabel, int amount})>? historyForTitle(
    String title,
  ) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return null;
    for (final entry in historyTable.entries) {
      if (trimmed.toLowerCase().startsWith(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return null;
  }

  /// Tạo danh sách chip gợi ý trên bàn phím từ lịch sử (`histChips` trong HTML).
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
    return 'Chi phí khác';
  }

  static String colorForGroupId(String groupId) {
    for (final g in defaultGroups) {
      if (g.id == groupId) return g.color;
    }
    return '#94A3B8';
  }

  /// 5 khoản cố định hàng tháng theo yêu cầu của anh Lê Nguyên:
  /// 1. Chi phí kho (`12.000.000 đ`)
  /// 2. Điện nước (`1.850.000 đ`)
  /// 3. Lương nhân sự (`18.000.000 đ`)
  /// 4. Lãi vay (`6.500.000 đ`)
  /// 5. Lương kế toán dịch vụ (`3.000.000 đ`)
  static List<RecurringExpenseSuggestion> defaultRecurringForMonth(
    String ymOrSlash,
  ) {
    final ym = FinanceMonthUtils.toYearMonth(ymOrSlash);
    final mNum = FinanceMonthUtils.monthNumberOf(ym);
    final spentOn = '$ym-01';
    return [
      RecurringExpenseSuggestion(
        key: 'recur_warehouse',
        baseTitle: 'Chi phí kho',
        titleForMonth: 'Chi phí kho T$mNum',
        groupId: 'op',
        groupName: nameForGroupId('op'),
        groupColor: colorForGroupId('op'),
        suggestedAmount: 12000000,
        spentOnForMonth: spentOn,
        accountId: 'acc_bank',
        accountName: 'TK ngân hàng',
        history: historyTable['Chi phí kho']!,
      ),
      RecurringExpenseSuggestion(
        key: 'recur_utilities',
        baseTitle: 'Điện nước',
        titleForMonth: 'Điện nước T$mNum',
        groupId: 'op',
        groupName: nameForGroupId('op'),
        groupColor: colorForGroupId('op'),
        suggestedAmount: 1850000,
        spentOnForMonth: spentOn,
        accountId: 'acc_bank',
        accountName: 'TK ngân hàng',
        history: historyTable['Điện nước']!,
      ),
      RecurringExpenseSuggestion(
        key: 'recur_payroll',
        baseTitle: 'Lương nhân sự',
        titleForMonth: 'Lương nhân sự T$mNum',
        groupId: 'pe',
        groupName: nameForGroupId('pe'),
        groupColor: colorForGroupId('pe'),
        suggestedAmount: 18000000,
        spentOnForMonth: spentOn,
        accountId: 'acc_bank',
        accountName: 'TK ngân hàng',
        history: historyTable['Lương nhân sự']!,
      ),
      RecurringExpenseSuggestion(
        key: 'recur_loan_interest',
        baseTitle: 'Lãi vay',
        titleForMonth: 'Lãi vay T$mNum',
        groupId: 'fn',
        groupName: nameForGroupId('fn'),
        groupColor: colorForGroupId('fn'),
        suggestedAmount: 6500000,
        spentOnForMonth: spentOn,
        accountId: 'acc_bank',
        accountName: 'TK ngân hàng',
        history: historyTable['Lãi vay']!,
      ),
      RecurringExpenseSuggestion(
        key: 'recur_accounting_service',
        baseTitle: 'Lương kế toán dịch vụ',
        titleForMonth: 'Lương kế toán dịch vụ T$mNum',
        groupId: 'ad',
        groupName: nameForGroupId('ad'),
        groupColor: colorForGroupId('ad'),
        suggestedAmount: 3000000,
        spentOnForMonth: spentOn,
        accountId: 'acc_bank',
        accountName: 'TK ngân hàng',
        history: historyTable['Lương kế toán dịch vụ']!,
      ),
    ];
  }

  static List<RecurringExpenseSuggestion> get recurringTemplates =>
      defaultRecurringForMonth('2026-11');

  /// Dữ liệu khởi tạo 6 tháng (`06/2026` → `11/2026`) kèm `createdAt` và `attachments` mẫu.
  static Map<String, List<ExpenseItem>> buildInitialSeedItems() {
    ExpenseItem paidItem({
      required int id,
      required String title,
      required String groupId,
      required int amount,
      required String spentOn,
      required String accountName,
      String? createdAt,
      List<ExpenseAttachment> attachments = const [],
    }) {
      final month = spentOn.substring(0, 7);
      final accId = accountName == 'Tiền mặt' ? 'acc_cash' : 'acc_bank';
      final defaultCreated =
          createdAt ?? '${FinanceMonthUtils.shortDayMonth(spentOn)} 09:15';
      return ExpenseItem(
        id: '$id',
        spentOn: spentOn,
        month: month,
        groupId: groupId,
        groupName: nameForGroupId(groupId),
        groupColor: colorForGroupId(groupId),
        title: title,
        amount: amount,
        accountId: accId,
        accountName: accountName,
        status: ExpenseStatus.paid,
        paidAmount: amount,
        outstanding: 0,
        createdAt: defaultCreated,
        payments: [
          ExpensePayment(
            id: 'p_$id',
            paidOn: spentOn,
            amount: amount,
            accountId: accId,
            accountName: accountName,
          ),
        ],
        attachments: attachments,
      );
    }

    return {
      '2026-06': [
        paidItem(
          id: 1,
          title: 'Lương nhân sự T6',
          groupId: 'pe',
          amount: 17500000,
          spentOn: '2026-06-06',
          accountName: 'TK ngân hàng',
          createdAt: '06/06 09:00',
        ),
        paidItem(
          id: 2,
          title: 'Chi phí kho T6',
          groupId: 'op',
          amount: 12000000,
          spentOn: '2026-06-02',
          accountName: 'TK ngân hàng',
          createdAt: '02/06 08:30',
        ),
      ],
      '2026-07': [
        paidItem(
          id: 5,
          title: 'Lương nhân sự T7',
          groupId: 'pe',
          amount: 18000000,
          spentOn: '2026-07-05',
          accountName: 'TK ngân hàng',
          createdAt: '05/07 09:00',
        ),
        paidItem(
          id: 6,
          title: 'Chi phí kho T7',
          groupId: 'op',
          amount: 12000000,
          spentOn: '2026-07-01',
          accountName: 'TK ngân hàng',
          createdAt: '01/07 08:45',
        ),
      ],
      '2026-08': [
        paidItem(
          id: 8,
          title: 'Lương nhân sự T8',
          groupId: 'pe',
          amount: 18000000,
          spentOn: '2026-08-05',
          accountName: 'TK ngân hàng',
          createdAt: '05/08 09:10',
        ),
        paidItem(
          id: 9,
          title: 'Chi phí kho T8',
          groupId: 'op',
          amount: 12000000,
          spentOn: '2026-08-01',
          accountName: 'TK ngân hàng',
          createdAt: '01/08 08:30',
        ),
      ],
      '2026-09': [
        paidItem(
          id: 11,
          title: 'Lương nhân sự T9',
          groupId: 'pe',
          amount: 18000000,
          spentOn: '2026-09-05',
          accountName: 'TK ngân hàng',
          createdAt: '05/09 09:00',
        ),
        paidItem(
          id: 12,
          title: 'Quảng cáo Facebook T9',
          groupId: 'mk',
          amount: 5000000,
          spentOn: '2026-09-03',
          accountName: 'TK ngân hàng',
          createdAt: '03/09 14:20',
        ),
        paidItem(
          id: 13,
          title: 'Chi phí kho T9',
          groupId: 'op',
          amount: 12000000,
          spentOn: '2026-09-01',
          accountName: 'TK ngân hàng',
          createdAt: '01/09 08:30',
        ),
        paidItem(
          id: 14,
          title: 'Điện nước T9',
          groupId: 'op',
          amount: 1920000,
          spentOn: '2026-09-01',
          accountName: 'TK ngân hàng',
          createdAt: '01/09 10:15',
        ),
        paidItem(
          id: 15,
          title: 'Phí phần mềm CRM T9',
          groupId: 'sw',
          amount: 1600000,
          spentOn: '2026-09-01',
          accountName: 'TK ngân hàng',
          createdAt: '01/09 11:00',
        ),
      ],
      '2026-10': [
        paidItem(
          id: 21,
          title: 'Lương bộ phận kinh doanh T10',
          groupId: 'pe',
          amount: 18000000,
          spentOn: '2026-10-05',
          accountName: 'TK ngân hàng',
          createdAt: '05/10 09:30',
        ),
        paidItem(
          id: 22,
          title: 'Quảng cáo Facebook T10',
          groupId: 'mk',
          amount: 4500000,
          spentOn: '2026-10-03',
          accountName: 'TK ngân hàng',
          createdAt: '03/10 15:00',
        ),
        paidItem(
          id: 23,
          title: 'Văn phòng phẩm & in ấn',
          groupId: 'ad',
          amount: 650000,
          spentOn: '2026-10-02',
          accountName: 'Tiền mặt',
          createdAt: '02/10 16:10',
        ),
        paidItem(
          id: 24,
          title: 'Chi phí kho T10',
          groupId: 'op',
          amount: 12000000,
          spentOn: '2026-10-01',
          accountName: 'TK ngân hàng',
          createdAt: '01/10 08:30',
        ),
        paidItem(
          id: 25,
          title: 'Điện nước T10',
          groupId: 'op',
          amount: 1850000,
          spentOn: '2026-10-01',
          accountName: 'TK ngân hàng',
          createdAt: '01/10 09:45',
        ),
        paidItem(
          id: 26,
          title: 'Phí phần mềm CRM T10',
          groupId: 'sw',
          amount: 1600000,
          spentOn: '2026-10-01',
          accountName: 'TK ngân hàng',
          createdAt: '01/10 10:30',
        ),
      ],
      '2026-11': [
        paidItem(
          id: 31,
          title: 'Phí hosting tháng 11',
          groupId: 'sw',
          amount: 2450000,
          spentOn: '2026-11-02',
          accountName: 'TK ngân hàng',
          createdAt: '02/11 09:15',
          attachments: const [
            ExpenseAttachment(
              id: 'att_31_1',
              name: 'Hoa-don-VAT-hosting-T11.pdf',
              kind: 'pdf',
              sizeLabel: '185 KB',
              uploadedAt: '02/11 09:15',
            ),
          ],
        ),
        const ExpenseItem(
          id: '32',
          spentOn: '2026-11-02',
          month: '2026-11',
          groupId: 'mk',
          groupName: 'Tiếp thị & bán hàng',
          groupColor: '#D97706',
          title: 'Quảng cáo Facebook đầu tháng',
          amount: 4500000,
          accountId: 'acc_bank',
          accountName: 'TK ngân hàng',
          status: ExpenseStatus.unpaid,
          paidAmount: 0,
          outstanding: 4500000,
          createdAt: '02/11 10:40',
          payments: [],
        ),
        const ExpenseItem(
          id: '33',
          spentOn: '2026-11-01',
          month: '2026-11',
          groupId: 'pe',
          groupName: 'Nhân sự & tiền lương',
          groupColor: '#2563EB',
          title: 'Tạm ứng lương bộ phận KD',
          amount: 18000000,
          accountId: 'acc_bank',
          accountName: 'TK ngân hàng',
          status: ExpenseStatus.partial,
          paidAmount: 9000000,
          outstanding: 9000000,
          createdAt: '01/11 11:20',
          payments: [
            ExpensePayment(
              id: 'p_33_1',
              paidOn: '2026-11-01',
              amount: 9000000,
              accountId: 'acc_bank',
              accountName: 'TK ngân hàng',
            ),
          ],
        ),
        paidItem(
          id: 34,
          title: 'Tiếp khách đối tác chiến lược',
          groupId: 'mk',
          amount: 1280000,
          spentOn: '2026-11-01',
          accountName: 'Tiền mặt',
          createdAt: '01/11 14:20',
          attachments: const [
            ExpenseAttachment(
              id: 'att_34_1',
              name: 'Phieu-chi-tien-mat-0111.jpg',
              kind: 'image',
              sizeLabel: '420 KB',
              uploadedAt: '01/11 14:20',
            ),
          ],
        ),
        const ExpenseItem(
          id: '35',
          spentOn: '2026-11-01',
          month: '2026-11',
          groupId: 'ad',
          groupName: 'Kế toán & hành chính',
          groupColor: '#64748B',
          title: 'Văn phòng phẩm & mực in',
          amount: 420000,
          accountId: 'acc_cash',
          accountName: 'Tiền mặt',
          status: ExpenseStatus.unpaid,
          paidAmount: 0,
          outstanding: 420000,
          createdAt: '01/11 16:05',
          payments: [],
        ),
      ],
    };
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
