import 'package:flutter/foundation.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/text_search.dart';
import 'finance_models.dart';

/// Kết quả phân tích dòng nhập nhanh (`Ví dụ: Tiền điện 1.85tr hoặc Tiếp khách 650k tm`).
@immutable
class ParsedExpenseDraft {
  const ParsedExpenseDraft({
    required this.amount,
    required this.title,
    this.matchedGroupId,
    this.matchedGroupKeyword,
    this.matchedAccountId,
    this.matchedAccountName,
    this.matchedAccountKind,
    this.suggestedStatus,
    this.parsedDate,
  });

  /// Số tiền đồng (0 nếu chưa nhận diện được).
  final int amount;

  /// Nội dung khoản chi đã làm sạch đơn vị tiền, ngày tắt và nhãn nguồn tiền.
  final String title;

  /// Id nhóm chi đoán được (`op`, `pe`, `mk`, `sw`, `ad`, `ot` hoặc id của server).
  final String? matchedGroupId;

  /// Từ khoá tiếng Việt đã kích hoạt gợi ý nhóm.
  final String? matchedGroupKeyword;

  /// Id nguồn tiền đoán được từ danh sách `MoneyAccount`.
  final String? matchedAccountId;

  /// Tên nguồn tiền đoán được (`Tiền mặt`, `TK ngân hàng`, `Ví điện tử`).
  final String? matchedAccountName;

  /// Loại nguồn tiền đoán được (`cash`, `bank`, `company`, `advance`).
  final MoneyAccountKind? matchedAccountKind;

  /// Trạng thái gợi ý (`paid` hoặc `unpaid`) từ từ khoá hoặc loại chi phí.
  final ExpenseStatus? suggestedStatus;

  /// Ngày ghi nhận nếu người dùng gõ kèm `hq`, `hôm qua`, `hn`, `25/11`...
  final DateTime? parsedDate;

  bool get hasValidAmount => amount > 0;
  bool get hasValidTitle => title.trim().isNotEmpty;
  bool get isReadyToSave => hasValidAmount && hasValidTitle;
}

/// Bộ phân tích 1 dòng thông minh cho Sổ chi phí (`parseSmart` + `guessGroup`).
abstract final class SmartExpenseParser {
  static final RegExp _amountTokenRegex = RegExp(
    r'(?<![/\d])(\d+(?:[.,]\d+)*)\s*(tỷ|tỉ|ty|tr|triệu|trieu|m|củ|cu|k|nghìn|ngàn|nghin|ngan|đ|d|vnd)?(\d{1,3})?(?=\s|$)',
    caseSensitive: false,
  );

  static final RegExp _nonMoneyPrefixRegex = RegExp(
    r'(?:tháng|thang|quý|quy|lần|lan|năm|nam|kỳ|ky|ngày|ngay|đợt|dot|t|q)\s*$',
    caseSensitive: false,
  );

  static final RegExp _dateTokenRegex = RegExp(
    r'(?:^|\s)(\d{1,2})\/(\d{1,2})(?:\/(\d{4}))?(?=\s|$)',
  );

  static const List<
    ({
      String seedId,
      List<String> groupAliases,
      List<String> keywords,
      bool defaultPaid,
    })
  >
  _categoryRules = [
    (
      seedId: 'fn',
      groupAliases: ['lai vay', 'tai chinh', 'ngan hang', 'von vay'],
      keywords: [
        'lai vay',
        'vay ngan hang',
        'tra lai',
        'lai ngan hang',
        'phi ngan hang',
        'tai chinh',
        'tin dung',
      ],
      defaultPaid: true,
    ),
    (
      seedId: 'ad',
      groupAliases: [
        'ke toan',
        'quan ly',
        'hanh chinh',
        'van phong pham',
        'thiet bi',
      ],
      keywords: [
        'luong ke toan',
        'ke toan dich vu',
        'dich vu ke toan',
        'van phong pham',
        'van phong',
        'in an',
        'muc in',
        'muc',
        'giay in',
        'thue gtgt',
        'chung tu',
        'hanh chinh',
        'ke toan',
        'thiet bi',
      ],
      defaultPaid: true,
    ),
    (
      seedId: 'pe',
      groupAliases: ['nhan su', 'luong', 'thuong'],
      keywords: [
        'luong',
        'thuong',
        'nhan su',
        'bhxh',
        'bao hiem',
        'tam ung',
        'ung luong',
        'cong tac',
        'kpi',
        'phu cap',
      ],
      defaultPaid: true,
    ),
    (
      seedId: 'op',
      groupAliases: [
        'kho bai',
        'van hanh',
        'mat bang',
        'thue van phong',
        'thue kho',
        'dien nuoc',
        'tien ich',
        'van chuyen',
      ],
      keywords: [
        'chi phi kho',
        'thue mat bang',
        'thue van phong',
        'thue kho',
        'thue nha',
        'mat bang',
        'tien dien',
        'tien nuoc',
        'dien nuoc',
        'internet',
        'wifi',
        'cap quang',
        'van chuyen',
        'giao hang',
        'ship',
        'kho',
        'dien',
        'nuoc',
        'thue',
      ],
      defaultPaid: true,
    ),
    (
      seedId: 'mk',
      groupAliases: [
        'tiep thi',
        'ban hang',
        'marketing',
        'quang cao',
        'tiep khach',
        'phuc loi',
      ],
      keywords: [
        'quang cao',
        'ads',
        'facebook',
        'google',
        'tiktok',
        'tiep khach',
        'ca phe',
        'cafe',
        'coffee',
        'an trua',
        'an toi',
        'nha hang',
        'hoa hong',
        'marketing',
        'catalogue',
        'banner',
      ],
      defaultPaid: true,
    ),
    (
      seedId: 'sw',
      groupAliases: ['phan mem', 'ten mien', 'cntt'],
      keywords: [
        'phan mem',
        'crm',
        'hosting',
        'domain',
        'ten mien',
        'server',
        'cloud',
        'vps',
        'zalo',
        'zoom',
      ],
      defaultPaid: true,
    ),
  ];

  /// Phân tích một cụm số tiền viết tắt đơn lẻ (`650k`, `1.85tr`, `4tr5`, `2.450.000`).
  static int? parseAmountToken(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final extracted = _extractAmount(trimmed);
    if (extracted != null && extracted.amount > 0) {
      return extracted.amount;
    }
    return null;
  }

  /// Đoán mã nhóm chuẩn (`op`, `pe`, `mk`, `sw`, `ad`, `ot`) hoặc id trong `groups`.
  static String? guessGroup(
    String rawTitle, {
    List<ExpenseGroup> groups = const [],
  }) {
    final m = _matchGroup(rawTitle, groups: groups);
    return m.groupId;
  }

  static ParsedExpenseDraft parse(
    String rawInput, {
    List<ExpenseGroup> groups = const [],
    List<MoneyAccount> accounts = const [],
    DateTime? referenceDate,
    String? targetMonth,
  }) {
    var working = rawInput.trim();
    if (working.isEmpty) {
      return const ParsedExpenseDraft(amount: 0, title: '');
    }

    final refDay = referenceDate != null
        ? DateTime(referenceDate.year, referenceDate.month, referenceDate.day)
        : VnTime.today();
    final defaultYear = targetMonth != null
        ? FinanceMonthUtils.yearOf(targetMonth)
        : refDay.year;

    // 1. Trích xuất ngày (`hôm qua`/`hq`, `hôm nay`/`hn`, hoặc `dd/mm`).
    DateTime? parsedDate;
    final dateResult = _extractDate(
      working,
      refDay: refDay,
      defaultYear: defaultYear,
    );
    if (dateResult != null) {
      parsedDate = dateResult.date;
      working = dateResult.remaining;
    }

    // 2. Trích xuất từ khoá nguồn tiền & trạng thái (`tm`, `tiền mặt`, `ck`, `chuyển khoản`, `nợ`).
    final paymentResult = _extractPaymentAndAccount(
      working,
      accounts: accounts,
    );
    working = paymentResult.remaining;

    // 3. Trích xuất số tiền (`650k`, `1.85tr`, `12tr`, `2.480.000`, bỏ qua `tháng 11`).
    var amount = 0;
    final amountResult = _extractAmount(working);
    if (amountResult != null) {
      amount = amountResult.amount;
      working = amountResult.remaining;
    }

    // 4. Chuẩn hoá tiêu đề.
    final cleanedTitle = _cleanTitle(working);

    // 5. Đoán nhóm chi phí.
    final groupMatch = _matchGroup(cleanedTitle, groups: groups);

    // 6. Trạng thái gợi ý.
    final ExpenseStatus? suggestedStatus =
        paymentResult.status ??
        (groupMatch.defaultPaid != null
            ? (groupMatch.defaultPaid!
                  ? ExpenseStatus.paid
                  : ExpenseStatus.unpaid)
            : null);

    String? matchedAccountId = paymentResult.accountId;
    if (matchedAccountId == null &&
        paymentResult.accountKind != null &&
        accounts.isNotEmpty) {
      matchedAccountId = accounts
          .where((a) => !a.archived && a.kind == paymentResult.accountKind)
          .map((a) => a.id)
          .firstOrNull;
    }

    return ParsedExpenseDraft(
      amount: amount,
      title: cleanedTitle,
      matchedGroupId: groupMatch.groupId,
      matchedGroupKeyword: groupMatch.keyword,
      matchedAccountId: matchedAccountId,
      matchedAccountName: paymentResult.accountName,
      matchedAccountKind: paymentResult.accountKind,
      suggestedStatus: suggestedStatus,
      parsedDate: parsedDate,
    );
  }

  static ({DateTime date, String remaining})? _extractDate(
    String input, {
    required DateTime refDay,
    required int defaultYear,
  }) {
    final dmMatch = _dateTokenRegex.firstMatch(input);
    if (dmMatch != null) {
      final d = int.tryParse(dmMatch.group(1) ?? '');
      final m = int.tryParse(dmMatch.group(2) ?? '');
      final y = dmMatch.group(3) != null
          ? int.tryParse(dmMatch.group(3)!)
          : defaultYear;
      if (d != null && m != null && y != null && m >= 1 && m <= 12 && d >= 1) {
        final maxDay = DateTime.utc(y, m + 1, 0).day;
        if (d <= maxDay) {
          final before = input.substring(0, dmMatch.start);
          final after = input.substring(dmMatch.end);
          return (
            date: DateTime(y, m, d),
            remaining: '$before $after'.replaceAll(RegExp(r'\s+'), ' ').trim(),
          );
        }
      }
    }

    final patterns = <(RegExp, int)>[
      (
        RegExp(
          r'(?:^|\s)(?:hôm\s+kia|hom\s+kia)(?=\s|$)',
          caseSensitive: false,
        ),
        -2,
      ),
      (
        RegExp(
          r'(?:^|\s)(?:hôm\s+qua|hom\s+qua|hq)(?=\s|$)',
          caseSensitive: false,
        ),
        -1,
      ),
      (
        RegExp(
          r'(?:^|\s)(?:hôm\s+nay|hom\s+nay|hn)(?=\s|$)',
          caseSensitive: false,
        ),
        0,
      ),
    ];

    for (final (regex, offsetDays) in patterns) {
      final match = regex.firstMatch(input);
      if (match != null) {
        final before = input.substring(0, match.start);
        final after = input.substring(match.end);
        return (
          date: refDay.add(Duration(days: offsetDays)),
          remaining: '$before $after'.replaceAll(RegExp(r'\s+'), ' ').trim(),
        );
      }
    }
    return null;
  }

  static ({int amount, String remaining})? _extractAmount(String input) {
    RegExpMatch? bestMatch;
    var bestValue = 0;
    var bestHasUnit = false;

    for (final match in _amountTokenRegex.allMatches(input)) {
      final rawNumber = match.group(1) ?? '';
      final rawUnit = (match.group(2) ?? '').toLowerCase();
      final rawTail = match.group(3) ?? '';
      final hasUnit = rawUnit.isNotEmpty;

      final prefix = input.substring(0, match.start);
      if (!hasUnit && _nonMoneyPrefixRegex.hasMatch(prefix)) {
        continue;
      }

      final combinedNumber = (hasUnit && rawTail.isNotEmpty)
          ? '$rawNumber.$rawTail'
          : rawNumber;
      final value = _parseNumericValue(combinedNumber, rawUnit);
      if (value <= 0) continue;

      if (!hasUnit && value < 1000) continue;

      if (hasUnit && !bestHasUnit) {
        bestMatch = match;
        bestValue = value;
        bestHasUnit = true;
        break;
      } else if (!bestHasUnit && value > bestValue) {
        bestMatch = match;
        bestValue = value;
      }
    }

    if (bestMatch == null || bestValue <= 0) return null;

    final before = input.substring(0, bestMatch.start);
    final after = input.substring(bestMatch.end);
    final remaining = '$before $after'.replaceAll(RegExp(r'\s+'), ' ').trim();
    return (amount: bestValue, remaining: remaining);
  }

  static int _parseNumericValue(String rawNum, String unit) {
    if (unit.isEmpty || unit == 'đ' || unit == 'd' || unit == 'vnd') {
      final digitsOnly = rawNum.replaceAll(RegExp(r'[^\d]'), '');
      return int.tryParse(digitsOnly) ?? 0;
    }

    final multiplier = switch (unit) {
      'tỷ' || 'tỉ' || 'ty' => 1000000000.0,
      'tr' || 'triệu' || 'trieu' || 'm' || 'củ' || 'cu' => 1000000.0,
      _ => 1000.0,
    };

    final isMillionOrBillion = multiplier >= 1000000.0;
    final dotCount = '.'.allMatches(rawNum).length;
    var normalized = (isMillionOrBillion && dotCount == 1)
        ? rawNum
        : rawNum.replaceAll(RegExp(r'\.(?=\d{3}\b)'), '');
    normalized = normalized.replaceAll(',', '.');
    final parsed = double.tryParse(normalized);
    if (parsed == null) return 0;
    return (parsed * multiplier).round();
  }

  static ({
    ExpenseStatus? status,
    MoneyAccountKind? accountKind,
    String? accountId,
    String? accountName,
    String remaining,
  })
  _extractPaymentAndAccount(
    String input, {
    required List<MoneyAccount> accounts,
  }) {
    var working = input;
    ExpenseStatus? status;
    MoneyAccountKind? accountKind;
    String? accountId;
    String? accountName;

    for (final acc in accounts.where((a) => !a.archived)) {
      final foldedAcc = foldDiacritics(acc.name.trim());
      if (foldedAcc.length < 2) continue;
      final escaped = RegExp.escape(foldedAcc);
      final tailRegex = RegExp(
        '(?:^|\\s)($escaped)\\s*\$',
        caseSensitive: false,
      );
      final foldedWorking = foldDiacritics(working);
      final m = tailRegex.firstMatch(foldedWorking);
      if (m != null) {
        accountId = acc.id;
        accountName = acc.name;
        accountKind = acc.kind;
        status = ExpenseStatus.paid;
        working = working.substring(0, m.start).trim();
        break;
      }
    }

    final tagRules =
        <
          ({
            RegExp pattern,
            MoneyAccountKind? kind,
            String? accName,
            ExpenseStatus status,
          })
        >[
          (
            pattern: RegExp(
              r'(?:^|\s)(?:chưa\s+trả|chua\s+tra|công\s+nợ|cong\s+no|ghi\s+nợ|ghi\s+no|nợ)(?=\s|$)',
              caseSensitive: false,
            ),
            kind: null,
            accName: null,
            status: ExpenseStatus.unpaid,
          ),
          (
            pattern: RegExp(
              r'(?:^|\s)(?:tiền\s+mặt|tien\s+mat|quỹ\s+tiền\s+mặt|tm)(?=\s|$)',
              caseSensitive: false,
            ),
            kind: MoneyAccountKind.cash,
            accName: 'Tiền mặt',
            status: ExpenseStatus.paid,
          ),
          (
            pattern: RegExp(
              r'(?:^|\s)(?:chuyển\s+khoản|chuyen\s+khoan|ngân\s+hàng|ngan\s+hang|ck|nh)(?=\s|$)',
              caseSensitive: false,
            ),
            kind: MoneyAccountKind.bank,
            accName: 'TK ngân hàng',
            status: ExpenseStatus.paid,
          ),
          (
            pattern: RegExp(
              r'(?:^|\s)(?:ví\s+điện\s+tử|vi\s+dien\s+tu|tiền\s+ứng|tien\s+ung|tạm\s+ứng|tam\s+ung)(?=\s|$)',
              caseSensitive: false,
            ),
            kind: MoneyAccountKind.advance,
            accName: 'Ví điện tử',
            status: ExpenseStatus.paid,
          ),
          (
            pattern: RegExp(
              r'(?:^|\s)(?:đã\s+trả|da\s+tra|trả\s+đủ|tra\s+du)(?=\s|$)',
              caseSensitive: false,
            ),
            kind: null,
            accName: null,
            status: ExpenseStatus.paid,
          ),
        ];

    for (final rule in tagRules) {
      final m = rule.pattern.firstMatch(working);
      if (m != null) {
        status ??= rule.status;
        accountKind ??= rule.kind;
        accountName ??= rule.accName;
        final before = working.substring(0, m.start);
        final after = working.substring(m.end);
        working = '$before $after'.replaceAll(RegExp(r'\s+'), ' ').trim();
        break;
      }
    }

    return (
      status: status,
      accountKind: accountKind,
      accountId: accountId,
      accountName: accountName,
      remaining: working,
    );
  }

  static ({String? groupId, String? keyword, bool? defaultPaid}) _matchGroup(
    String title, {
    required List<ExpenseGroup> groups,
  }) {
    if (title.isEmpty) {
      return (groupId: null, keyword: null, defaultPaid: null);
    }
    final foldedTitle = ' ${foldDiacritics(title)} ';
    final usableGroups = groups.where((g) => !g.archived).toList();

    for (final group in usableGroups) {
      final foldedGroup = foldDiacritics(group.name.trim());
      if (foldedGroup.length >= 3 && foldedTitle.contains(foldedGroup)) {
        return (groupId: group.id, keyword: group.name, defaultPaid: null);
      }
    }

    for (final rule in _categoryRules) {
      String? hitKeyword;
      for (final kw in rule.keywords) {
        if (foldedTitle.contains(kw)) {
          hitKeyword = kw.trim();
          break;
        }
      }
      if (hitKeyword == null) continue;

      // Tìm nhóm theo id chuẩn (`op`, `pe`, `mk`, `sw`, `ad`) trước.
      final bySeedId = usableGroups
          .where((g) => g.id == rule.seedId)
          .firstOrNull;
      if (bySeedId != null) {
        return (
          groupId: bySeedId.id,
          keyword: hitKeyword,
          defaultPaid: rule.defaultPaid,
        );
      }

      // Tìm nhóm trong workspace khớp với `groupAliases`.
      for (final alias in rule.groupAliases) {
        for (final group in usableGroups) {
          final foldedGroupName = foldDiacritics(group.name);
          if (foldedGroupName.contains(alias)) {
            return (
              groupId: group.id,
              keyword: hitKeyword,
              defaultPaid: rule.defaultPaid,
            );
          }
        }
      }

      return (
        groupId: usableGroups.isNotEmpty ? usableGroups.first.id : rule.seedId,
        keyword: hitKeyword,
        defaultPaid: rule.defaultPaid,
      );
    }

    final fallbackGroup =
        usableGroups
            .where(
              (g) =>
                  g.id == 'op' || foldDiacritics(g.name).contains('van hanh'),
            )
            .firstOrNull ??
        usableGroups.where((g) => g.countsAsExpense).firstOrNull ??
        usableGroups.firstOrNull;

    return (
      groupId: fallbackGroup?.id ?? 'op',
      keyword: null,
      defaultPaid: null,
    );
  }

  static String _cleanTitle(String raw) {
    final collapsed = raw
        .replaceAll(RegExp(r'^[\s\-–—·,.:;]+|[\s\-–—·,.:;]+$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (collapsed.isEmpty) return '';
    return '${collapsed[0].toUpperCase()}${collapsed.substring(1)}';
  }
}
