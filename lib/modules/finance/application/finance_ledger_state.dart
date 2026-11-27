// Trạng thái Sổ chi phí: dữ liệu bất biến + các phép suy (lọc, nhóm, sắp
// xếp, tổng). Tách khỏi `finance_providers.dart` (rà soát kiến trúc
// 27/11/2026) — file đó còn notifier (gọi API, hàng chờ, thông báo).
// Nhập qua `finance_providers.dart` (file đó export lại file này).

import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/text_search.dart';
import '../domain/finance_models.dart';
import '../domain/smart_expense_parser.dart';

/// Thông báo toast ở đáy màn hình kèm khả năng Hoàn tác đồng bộ máy chủ (`Hoàn tác`).
@immutable
class FinanceToastMessage {
  const FinanceToastMessage({
    required this.id,
    required this.text,
    this.onUndo,
  });

  final int id;
  final String text;
  final Future<void> Function()? onUndo;

  bool get canUndo => onUndo != null;
}

/// Một nhóm phần tử ở Tầng 3 (gom theo Ngày ghi nhận, Thời gian nhập, Ngày thanh toán, Loại chi phí hoặc Số tiền).
@immutable
class ExpenseListSection {
  const ExpenseListSection({
    required this.key,
    required this.headerLabel,
    required this.totalAmount,
    required this.items,
    this.dotColor,
  });

  final String key;
  final String headerLabel;
  final int totalAmount;
  final List<ExpenseItem> items;
  final Color? dotColor;
}

/// Toàn bộ trạng thái Sổ chi phí đồng bộ 100% với API `/api/v1/finance/*` và Web.
@immutable
class FinanceLedgerState {
  const FinanceLedgerState({
    required this.activeMonth,
    required this.itemsByMonth,
    required this.summariesByMonth,
    required this.loadedMonths,
    required this.dirtyMonths,
    required this.groups,
    required this.recurringTemplates,
    required this.accounts,
    required this.catalogYear,
    required this.recurDismissedMonths,
    required this.recurOpen,
    required this.recurUnselectedKeysByMonth,
    required this.recurCustomAmountsByMonth,
    required this.grpOpen,
    required this.fltStatus,
    required this.fltGroup,
    required this.sortMode,
    required this.searchOpen,
    required this.searchQuery,
    required this.flashedIds,
    required this.nextSeq,
    required this.isLoading,
    this.errorMessage,
    this.toast,
    this.syncing = false,
    this.clock,
  });

  factory FinanceLedgerState.initial({DateTime? clock}) {
    final ym = FinanceMonthUtils.currentVnMonth(clock);
    return FinanceLedgerState(
      activeMonth: ym,
      itemsByMonth: const {},
      summariesByMonth: const {},
      loadedMonths: const {},
      dirtyMonths: const {},
      groups: const [],
      recurringTemplates: const [],
      accounts: const [],
      catalogYear: FinanceMonthUtils.yearOf(ym),
      recurDismissedMonths: const {},
      recurOpen: false,
      recurUnselectedKeysByMonth: const {},
      recurCustomAmountsByMonth: const {},
      grpOpen: false,
      fltStatus: null,
      fltGroup: null,
      sortMode: ExpenseSortMode.spentDateDesc,
      searchOpen: false,
      searchQuery: '',
      flashedIds: const <String>{},
      nextSeq: 1,
      isLoading: true,
      clock: clock,
    );
  }

  /// Tháng đang chọn (`YYYY-MM`, mặc định tháng hiện tại theo giờ VN).
  final String activeMonth;

  /// Danh sách khoản chi theo từng tháng `YYYY-MM` tải từ API.
  final Map<String, List<ExpenseItem>> itemsByMonth;

  /// Bản tóm tắt chuẩn (`summary`) trả về từ `GET /finance/expenses?month=`.
  final Map<String, LedgerSummary> summariesByMonth;

  /// Các tháng đã tải thành công từ máy chủ.
  final Set<String> loadedMonths;

  /// Các tháng đang có chỉnh sửa lạc quan chờ máy chủ trả lại `summary` mới.
  final Set<String> dirtyMonths;

  /// Danh mục nhóm chi phí của workspace.
  final List<ExpenseGroup> groups;

  /// Danh sách mẫu khoản cố định từ `meta.recurring_templates` của API.
  final List<RecurringTemplateMeta> recurringTemplates;

  /// Danh mục nguồn tiền của workspace.
  final List<MoneyAccount> accounts;

  /// Năm của danh mục `groups` đang tải.
  final int catalogYear;

  /// Các tháng người dùng đã ghi xong thẻ Khoản cố định trong phiên.
  final Set<String> recurDismissedMonths;

  /// Trạng thái mở rộng thẻ Khoản cố định.
  final bool recurOpen;

  /// Các khoá khoản cố định bị bỏ tick theo từng tháng.
  final Map<String, Set<String>> recurUnselectedKeysByMonth;

  /// Số tiền người dùng tuỳ chỉnh trên thẻ Khoản cố định theo từng tháng.
  final Map<String, Map<String, int>> recurCustomAmountsByMonth;

  /// Trạng thái mở rộng bảng tỷ trọng nhóm.
  final bool grpOpen;

  /// Bộ lọc trạng thái: `null` | `'paid'` | `'owe'`.
  final String? fltStatus;

  /// Bộ lọc nhóm chi phí (`groupId` hoặc `null`).
  final String? fltGroup;

  /// Chế độ sắp xếp danh sách.
  final ExpenseSortMode sortMode;

  /// Thanh tìm kiếm đang mở hay đóng.
  final bool searchOpen;

  /// Từ khoá tìm kiếm.
  final String searchQuery;

  /// Tập ID khoản chi vừa mới thêm/cập nhật để nháy sáng (`flash`).
  final Set<String> flashedIds;

  /// Bộ đếm sinh ID tạm cục bộ khi thao tác lạc quan.
  final int nextSeq;

  /// Đang tải lần đầu của tháng đang chọn.
  final bool isLoading;

  /// Thông báo lỗi tải dữ liệu tháng hiện tại (nếu có).
  final String? errorMessage;

  /// Toast thông báo kèm nút Hoàn tác.
  final FinanceToastMessage? toast;

  /// Cờ đồng bộ nền với máy chủ.
  final bool syncing;

  /// Mốc đồng hồ tuỳ chọn (phục vụ kiểm thử).
  final DateTime? clock;

  /// Các nhóm chưa lưu trữ dùng cho form tạo mới / chọn nhóm.
  List<ExpenseGroup> get usableGroups =>
      groups.where((g) => !g.archived).toList(growable: false);

  /// Các nguồn tiền chưa lưu trữ dùng cho form tạo mới / thanh toán.
  List<MoneyAccount> get usableAccounts =>
      accounts.where((a) => !a.archived).toList(growable: false);

  /// Kiểm tra tháng `ym` đã tải từ API hay chưa.
  bool isMonthLoaded(String ym) => loadedMonths.contains(ym);

  /// Tra tên nguồn tiền theo `id` (nếu có).
  String? accountNameById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final a in accounts) {
      if (a.id == id) return a.name;
    }
    return null;
  }

  /// Nhóm mặc định khi mở form Thêm khoản chi (ưu tiên nhóm đang lọc, rồi nhóm tính chi phí đầu tiên).
  String get defaultGroupId {
    if (fltGroup != null && usableGroups.any((g) => g.id == fltGroup)) {
      return fltGroup!;
    }
    return usableGroups.where((g) => g.countsAsExpense).firstOrNull?.id ??
        usableGroups.firstOrNull?.id ??
        groups.firstOrNull?.id ??
        '';
  }

  /// Nguồn tiền mặc định khi thanh toán (khớp Web: ưu tiên Tiền mặt rồi nguồn khả dụng đầu tiên).
  MoneyAccount? get defaultPaymentAccount {
    final usable = usableAccounts;
    if (usable.isEmpty) return null;
    return usable.where((a) => a.kind == MoneyAccountKind.cash).firstOrNull ??
        usable.first;
  }

  /// Nguồn tiền chuyển khoản / ngân hàng mặc định cho khoản cố định hàng tháng.
  MoneyAccount? get defaultBankOrFirstAccount {
    final usable = usableAccounts;
    if (usable.isEmpty) return null;
    return usable.where((a) => a.kind == MoneyAccountKind.bank).firstOrNull ??
        usable.where((a) => a.kind == MoneyAccountKind.company).firstOrNull ??
        usable.first;
  }

  /// Danh sách khoản chi của tháng đang chọn.
  List<ExpenseItem> get activeMonthItems =>
      itemsByMonth[activeMonth] ?? const <ExpenseItem>[];

  /// Tổng hợp tháng đang chọn: ưu tiên tuyệt đối `summary` chuẩn từ API.
  /// Khi đang có thao tác lạc quan (`dirtyMonths`), tạm tính trên `activeMonthItems` nhưng giữ `prevMonth`, `revenue`, `cashOut` của server.
  LedgerSummary get activeSummary {
    final serverSummary = summariesByMonth[activeMonth];
    if (serverSummary != null && !dirtyMonths.contains(activeMonth)) {
      return serverSummary;
    }

    final prevYm = FinanceMonthUtils.shiftMonth(activeMonth, -1);
    final fallbackPrev =
        serverSummary?.prevMonth ??
        (summariesByMonth.containsKey(prevYm)
            ? LedgerPrevMonthSummary(
                month: prevYm,
                total: summariesByMonth[prevYm]!.total,
              )
            : (loadedMonths.contains(prevYm)
                  ? LedgerPrevMonthSummary(
                      month: prevYm,
                      total: (itemsByMonth[prevYm] ?? const <ExpenseItem>[])
                          .where((e) => e.countsAsExpense)
                          .fold<int>(0, (s, e) => s + e.amount),
                    )
                  : const LedgerPrevMonthSummary(month: '', total: 0)));

    return LedgerSummary.fromItems(
      items: activeMonthItems,
      groups: groups,
      prevMonth: fallbackPrev,
      revenue: serverSummary?.revenue ?? 0,
      cashOut:
          serverSummary?.cashOut ??
          const LedgerCashOutSummary(total: 0, earlier: 0),
    );
  }

  /// Tra lịch sử tháng gần nhất từ dữ liệu thực của workspace theo tiêu đề gốc (không cố định 3 tháng).
  List<({String monthLabel, int amount})> historyForTitle(
    String rawTitle, {
    String? beforeMonth,
  }) {
    final base = foldDiacritics(
      FinanceMonthUtils.normalizeRecurringBaseTitle(rawTitle),
    );
    if (base.isEmpty) return const [];
    final anchor = beforeMonth ?? activeMonth;
    final months = <String>[FinanceMonthUtils.shiftMonth(anchor, -1)];
    final result = <({String monthLabel, int amount})>[];
    for (final ym in months) {
      final list = itemsByMonth[ym];
      if (list == null || list.isEmpty) continue;
      ExpenseItem? matched;
      for (final item in list) {
        if (item.amount <= 0) continue;
        final itemBase = foldDiacritics(
          FinanceMonthUtils.normalizeRecurringBaseTitle(item.title),
        );
        if (itemBase == base ||
            itemBase.startsWith(base) ||
            base.startsWith(itemBase)) {
          matched = item;
          break;
        }
      }
      if (matched != null) {
        result.add((
          monthLabel: 'T${FinanceMonthUtils.monthNumberOf(ym)}',
          amount: matched.amount,
        ));
      }
    }
    return result;
  }

  List<RecurringTemplateMeta> get _effectiveTemplates {
    final raw = recurringTemplates.isNotEmpty
        ? recurringTemplates
        : FinanceSeedCatalog.defaultRecurringTemplates;
    return raw
        .where((tpl) {
          final k = tpl.key.toLowerCase();
          final foldedTitle = foldDiacritics(tpl.title);
          return k != 'luong_nhan_su' &&
              k != 'salary' &&
              !foldedTitle.contains('luong nhan su');
        })
        .toList(growable: false);
  }

  String _resolveTemplateGroupId(RecurringTemplateMeta tpl) {
    if (tpl.groupId != null && usableGroups.any((g) => g.id == tpl.groupId)) {
      return tpl.groupId!;
    }
    final foldedTarget = foldDiacritics(tpl.groupName);
    for (final g in usableGroups) {
      if (foldDiacritics(g.name) == foldedTarget) return g.id;
    }
    final guessed = SmartExpenseParser.guessGroup(
      tpl.title,
      groups: usableGroups,
    );
    if (guessed != null && guessed.isNotEmpty) return guessed;
    return defaultGroupId;
  }

  /// 5 gợi ý nhanh trong Sheet "Thêm chi phí" lấy nhóm & lịch sử thực của workspace.
  List<({String label, String title, int amount, String groupId})>
  get quickAddPresets {
    final out = <({String label, String title, int amount, String groupId})>[];
    for (final tpl in _effectiveTemplates) {
      final grpId = _resolveTemplateGroupId(tpl);
      if (grpId.isEmpty) continue;
      final hist = historyForTitle(tpl.title);
      final latestAmt = hist.isNotEmpty ? hist.last.amount : 0;
      final label = latestAmt > 0
          ? '${tpl.title} · ${Formatters.vnd(latestAmt)}'
          : tpl.title;
      out.add((
        label: label,
        title: tpl.title,
        amount: latestAmt,
        groupId: grpId,
      ));
    }
    return out;
  }

  /// Danh sách khoản cố định chưa ghi trong tháng hiện tại.
  List<RecurringExpenseSuggestion> get activeRecurringSuggestions {
    if (usableGroups.isEmpty) return const [];
    final mNum = FinanceMonthUtils.monthNumberOf(activeMonth);
    final spentOn = '$activeMonth-01';
    final defaultAcc = defaultBankOrFirstAccount;

    final existingBases = <String>{
      for (final item in activeMonthItems)
        foldDiacritics(
          FinanceMonthUtils.normalizeRecurringBaseTitle(item.title),
        ),
    };

    final list = <RecurringExpenseSuggestion>[];
    for (final tpl in _effectiveTemplates) {
      final tplBase = foldDiacritics(
        FinanceMonthUtils.normalizeRecurringBaseTitle(tpl.title),
      );
      final alreadyRecorded = existingBases.any(
        (b) => b.isNotEmpty && (b == tplBase || b.startsWith(tplBase)),
      );
      if (alreadyRecorded) continue;

      final grpId = _resolveTemplateGroupId(tpl);
      if (grpId.isEmpty) continue;
      final grp = groupById(grpId);
      final hist = historyForTitle(tpl.title, beforeMonth: activeMonth);
      final suggestedAmt = hist.isNotEmpty ? hist.last.amount : 0;

      list.add(
        RecurringExpenseSuggestion(
          key: tpl.key,
          baseTitle: tpl.title,
          titleForMonth: '${tpl.title} T$mNum',
          groupId: grp.id,
          groupName: grp.name,
          groupColor: grp.color,
          suggestedAmount: suggestedAmt,
          spentOnForMonth: spentOn,
          accountId: defaultAcc?.id,
          accountName: defaultAcc?.name,
          history: hist,
        ),
      );
    }
    return list;
  }

  /// Hiển thị thẻ Khoản cố định cho tháng hiện tại (hoặc tương lai) khi còn khoản chưa ghi.
  bool get showRecurringCard {
    if (isLoading || errorMessage != null) return false;
    if (recurDismissedMonths.contains(activeMonth)) return false;
    final currentYm = FinanceMonthUtils.currentVnMonth(clock);
    if (activeMonth.compareTo(currentYm) < 0) return false;
    return activeRecurringSuggestions.isNotEmpty;
  }

  /// Trạng thái tick chọn của từng dòng trong `activeRecurringSuggestions`.
  List<bool> get recurSel {
    final unselected =
        recurUnselectedKeysByMonth[activeMonth] ?? const <String>{};
    return [
      for (final s in activeRecurringSuggestions) !unselected.contains(s.key),
    ];
  }

  /// Số tiền hiện tại của từng dòng trong `activeRecurringSuggestions`.
  List<int> get recurAmt {
    final custom =
        recurCustomAmountsByMonth[activeMonth] ?? const <String, int>{};
    return [
      for (final s in activeRecurringSuggestions)
        custom[s.key] ?? s.suggestedAmount,
    ];
  }

  /// Số khoản cố định đang được tick chọn.
  int get selectedRecurringCount => recurSel.where((s) => s).length;

  /// Tổng tiền các khoản cố định đang được tick chọn.
  int get selectedRecurringSum {
    final sel = recurSel;
    final amt = recurAmt;
    var sum = 0;
    for (var i = 0; i < sel.length && i < amt.length; i++) {
      if (sel[i]) sum += amt[i];
    }
    return sum;
  }

  /// Tổng tiền tất cả các khoản cố định đang gợi ý.
  int get allRecurringSum => recurAmt.fold<int>(0, (s, a) => s + a);

  /// Có đang bật bộ lọc trạng thái, nhóm hoặc chế độ sắp xếp khác mặc định không.
  bool get hasActiveFilter =>
      fltStatus != null ||
      fltGroup != null ||
      sortMode != ExpenseSortMode.spentDateDesc;

  /// Nhãn hiển thị trong thanh `active-filter` (`Đã trả`, `Phải trả`, tên nhóm, chế độ sắp xếp).
  String get activeFilterDescription {
    final parts = <String>[];
    if (fltStatus == 'paid') parts.add('Đã trả');
    if (fltStatus == 'owe') parts.add('Phải trả');
    if (fltGroup != null) {
      parts.add(groupById(fltGroup!).name);
    }
    if (sortMode != ExpenseSortMode.spentDateDesc) {
      parts.add(sortMode.label);
    }
    return parts.join(' · ');
  }

  /// Danh sách khoản chi sau khi áp dụng bộ lọc trạng thái, nhóm và từ khoá tìm kiếm.
  List<ExpenseItem> get filteredItems {
    final q = searchQuery.trim().toLowerCase();
    final filtered = <ExpenseItem>[
      for (final item in activeMonthItems)
        if (_matchesFilter(item, q)) item,
    ];
    filtered.sort(_compareBySortMode);
    return filtered;
  }

  int _compareBySortMode(ExpenseItem a, ExpenseItem b) {
    return switch (sortMode) {
      ExpenseSortMode.spentDateDesc => () {
        final c = b.spentOn.compareTo(a.spentOn);
        return c != 0 ? c : b.id.compareTo(a.id);
      }(),
      ExpenseSortMode.createdAtDesc => () {
        final ka = _createdAtSortKey(a);
        final kb = _createdAtSortKey(b);
        final c = kb.compareTo(ka);
        return c != 0 ? c : b.id.compareTo(a.id);
      }(),
      ExpenseSortMode.paidDateDesc => () {
        final pa = a.lastPaidDateIso;
        final pb = b.lastPaidDateIso;
        if (pa.isEmpty && pb.isNotEmpty) return 1;
        if (pa.isNotEmpty && pb.isEmpty) return -1;
        final c = pb.compareTo(pa);
        return c != 0 ? c : b.spentOn.compareTo(a.spentOn);
      }(),
      ExpenseSortMode.category => () {
        final ga = groupById(a.groupId).sortOrder;
        final gb = groupById(b.groupId).sortOrder;
        final c = ga.compareTo(gb);
        return c != 0 ? c : b.amount.compareTo(a.amount);
      }(),
      ExpenseSortMode.amountDesc => () {
        final c = b.amount.compareTo(a.amount);
        return c != 0 ? c : b.spentOn.compareTo(a.spentOn);
      }(),
      ExpenseSortMode.amountAsc => () {
        final c = a.amount.compareTo(b.amount);
        return c != 0 ? c : b.spentOn.compareTo(a.spentOn);
      }(),
    };
  }

  String _createdAtSortKey(ExpenseItem item) {
    return FinanceMonthUtils.createdSortKey(
      rawCreatedAt: item.rawCreatedAt,
      displayCreatedAt: item.createdAt,
      fallbackSpentOn: item.spentOn,
      month: item.month,
    );
  }

  bool _matchesFilter(ExpenseItem item, String queryLower) {
    // Khớp logic lọc trạng thái của Web (`ledger-filter.ts`):
    // - 'paid': status == paid
    // - 'owe': còn số tiền phải trả (outstanding > 0)
    if (fltStatus == 'paid' && item.status != ExpenseStatus.paid) return false;
    if (fltStatus == 'owe' && item.remainingAmount <= 0) return false;
    if (fltGroup != null && item.groupId != fltGroup) return false;
    if (queryLower.isEmpty) return true;

    final grpName = groupById(
      item.groupId,
      fallbackName: item.groupName,
      fallbackColor: item.groupColor,
    ).name.toLowerCase();
    final accName = (item.effectiveAccountName ?? '').toLowerCase();
    final titleLower = item.title.toLowerCase();
    final noteLower = (item.note ?? '').toLowerCase();
    final foldedQuery = foldDiacritics(queryLower);

    // 1. Khớp tên khoản chi, ghi chú, nhóm, nguồn tiền, ghi chú lần trả, tên tệp đính kèm
    if (titleLower.contains(queryLower) ||
        noteLower.contains(queryLower) ||
        grpName.contains(queryLower) ||
        accName.contains(queryLower) ||
        foldDiacritics(titleLower).contains(foldedQuery) ||
        foldDiacritics(noteLower).contains(foldedQuery) ||
        foldDiacritics(grpName).contains(foldedQuery) ||
        foldDiacritics(accName).contains(foldedQuery)) {
      return true;
    }

    for (final p in item.payments) {
      final pNote = (p.note ?? '').toLowerCase();
      final pAcc = (p.accountName ?? '').toLowerCase();
      if ((pNote.isNotEmpty &&
              (pNote.contains(queryLower) ||
                  foldDiacritics(pNote).contains(foldedQuery))) ||
          (pAcc.isNotEmpty &&
              (pAcc.contains(queryLower) ||
                  foldDiacritics(pAcc).contains(foldedQuery)))) {
        return true;
      }
    }

    for (final att in item.attachments) {
      final attName = att.name.toLowerCase();
      if (attName.contains(queryLower) ||
          foldDiacritics(attName).contains(foldedQuery)) {
        return true;
      }
    }

    // 2. Khớp ngày ghi nhận, thời gian nhập, ngày thanh toán
    final shortDm = FinanceMonthUtils.shortDayMonth(item.spentOn).toLowerCase();
    final fullDmy = FinanceMonthUtils.fullDayMonthYear(
      item.spentOn,
      fallbackMonth: item.month,
    ).toLowerCase();
    if (item.spentOn.toLowerCase().contains(queryLower) ||
        shortDm.contains(queryLower) ||
        fullDmy.contains(queryLower) ||
        item.createdAt.toLowerCase().contains(queryLower)) {
      return true;
    }
    for (final p in item.payments) {
      final pShort = FinanceMonthUtils.shortDayMonth(p.paidOn).toLowerCase();
      if (p.paidOn.toLowerCase().contains(queryLower) ||
          pShort.contains(queryLower)) {
        return true;
      }
    }

    // 3. Khớp số tiền viết tắt (450k, 1.85tr, 2.45tr, 12tr, 3tr...)
    final parsedAmt = SmartExpenseParser.parseAmountToken(queryLower);
    if (parsedAmt != null && parsedAmt > 0) {
      if (item.amount.abs() == parsedAmt ||
          item.paidTotal.abs() == parsedAmt ||
          item.remainingAmount == parsedAmt ||
          item.payments.any((p) => p.amount == parsedAmt)) {
        return true;
      }
    }

    // 4. Khớp chuỗi chữ số (2450000, 2.450.000, 2450, 420...)
    final digitsOnly = queryLower.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isNotEmpty &&
        RegExp(r'^[\-\d.,\sđdvnd]+$').hasMatch(queryLower)) {
      final candidates = <int>[
        item.amount.abs(),
        item.paidTotal.abs(),
        item.remainingAmount,
        for (final p in item.payments) p.amount,
      ];
      for (final c in candidates) {
        if (c <= 0) continue;
        final rawStr = '$c';
        final fmtStr = FinanceMonthUtils.formatNumber(c).toLowerCase();
        if (rawStr.contains(digitsOnly) || fmtStr.contains(queryLower)) {
          return true;
        }
      }
    }

    return false;
  }

  /// Kết quả [groupedSections] theo từng bản state. State bất biến nên một bản
  /// chỉ lọc + sắp + gom một lần, dù màn đọc getter bao nhiêu lần mỗi build.
  static final Expando<List<ExpenseListSection>> _sectionsCache = Expando();

  /// Gom nhóm danh sách khoản chi đã lọc theo `sortMode` hiện hành.
  List<ExpenseListSection> get groupedSections =>
      _sectionsCache[this] ??= _computeGroupedSections();

  List<ExpenseListSection> _computeGroupedSections() {
    final list = filteredItems;
    if (list.isEmpty) return const [];

    switch (sortMode) {
      case ExpenseSortMode.spentDateDesc:
        final byDay = <String, List<ExpenseItem>>{};
        for (final item in list) {
          (byDay[item.spentOn] ??= <ExpenseItem>[]).add(item);
        }
        return [
          for (final entry in byDay.entries)
            ExpenseListSection(
              key: 'spent_${entry.key}',
              headerLabel: FinanceMonthUtils.dayHeaderLabel(
                entry.key,
                activeMonth: activeMonth,
                clock: clock,
              ),
              totalAmount: entry.value.fold<int>(0, (s, e) => s + e.amount),
              items: entry.value,
            ),
        ];

      case ExpenseSortMode.createdAtDesc:
        final byEntryDay = <String, List<ExpenseItem>>{};
        for (final item in list) {
          final iso = FinanceMonthUtils.createdDayIso(
            rawCreatedAt: item.rawCreatedAt,
            displayCreatedAt: item.createdAt,
            fallbackSpentOn: item.spentOn,
            month: item.month,
          );
          (byEntryDay[iso] ??= <ExpenseItem>[]).add(item);
        }
        return [
          for (final entry in byEntryDay.entries)
            ExpenseListSection(
              key: 'created_${entry.key}',
              headerLabel:
                  'Nhập ngày ${FinanceMonthUtils.fullDayMonthYear(entry.key, fallbackMonth: activeMonth)}',
              totalAmount: entry.value.fold<int>(0, (s, e) => s + e.amount),
              items: entry.value,
            ),
        ];

      case ExpenseSortMode.paidDateDesc:
        final byPaidDay = <String, List<ExpenseItem>>{};
        for (final item in list) {
          final paidIso = item.lastPaidDateIso;
          final bucketKey = paidIso.isNotEmpty ? paidIso : '__unpaid__';
          (byPaidDay[bucketKey] ??= <ExpenseItem>[]).add(item);
        }
        return [
          for (final entry in byPaidDay.entries)
            ExpenseListSection(
              key: 'paid_${entry.key}',
              headerLabel: entry.key == '__unpaid__'
                  ? 'Chưa thanh toán'
                  : 'Thanh toán · ${FinanceMonthUtils.fullDayMonthYear(entry.key, fallbackMonth: activeMonth)}',
              totalAmount: entry.value.fold<int>(0, (s, e) => s + e.amount),
              items: entry.value,
            ),
        ];

      case ExpenseSortMode.category:
        final byGrp = <String, List<ExpenseItem>>{};
        for (final item in list) {
          (byGrp[item.groupId] ??= <ExpenseItem>[]).add(item);
        }
        final sections = <ExpenseListSection>[
          for (final entry in byGrp.entries)
            () {
              final sample = entry.value.first;
              final grp = groupById(
                entry.key,
                fallbackName: sample.groupName,
                fallbackColor: sample.groupColor,
                fallbackCountsAsExpense: sample.countsAsExpense,
              );
              return ExpenseListSection(
                key: 'grp_${entry.key}',
                headerLabel: grp.name,
                dotColor: grp.parsedColor,
                totalAmount: entry.value.fold<int>(0, (s, e) => s + e.amount),
                items: entry.value,
              );
            }(),
        ]..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
        return sections;

      case ExpenseSortMode.amountDesc:
      case ExpenseSortMode.amountAsc:
        return [
          ExpenseListSection(
            key: 'amt_${sortMode.id}',
            headerLabel: sortMode.label,
            totalAmount: list.fold<int>(0, (s, e) => s + e.amount),
            items: list,
          ),
        ];
    }
  }

  /// Tương thích ngược cho code gọi `groupedFilteredByDay`.
  List<
    ({
      String spentOn,
      String headerLabel,
      int dayTotal,
      List<ExpenseItem> items,
    })
  >
  get groupedFilteredByDay {
    return [
      for (final s in groupedSections)
        (
          spentOn: s.key,
          headerLabel: s.headerLabel,
          dayTotal: s.totalAmount,
          items: s.items,
        ),
    ];
  }

  /// Tìm `ExpenseGroup` theo `id` (ưu tiên danh mục API, sau đó đến metadata đính kèm trên `ExpenseItem`).
  ExpenseGroup groupById(
    String groupId, {
    String? fallbackName,
    String? fallbackColor,
    bool? fallbackCountsAsExpense,
  }) {
    for (final g in groups) {
      if (g.id == groupId) return g;
    }
    if (fallbackName != null && fallbackName.trim().isNotEmpty) {
      return ExpenseGroup(
        id: groupId,
        name: fallbackName,
        color: fallbackColor ?? '#94A3B8',
        countsAsExpense: fallbackCountsAsExpense ?? true,
        sortOrder: 999,
      );
    }
    for (final g in FinanceSeedCatalog.defaultGroups) {
      if (g.id == groupId) return g;
    }
    return ExpenseGroup(
      id: groupId,
      name: 'Chưa phân nhóm',
      color: fallbackColor ?? '#94A3B8',
      countsAsExpense: fallbackCountsAsExpense ?? true,
      sortOrder: 999,
    );
  }

  /// Tìm `MoneyAccount` theo `id`.
  MoneyAccount? accountById(String? accountId) {
    if (accountId == null || accountId.isEmpty) return null;
    for (final a in accounts) {
      if (a.id == accountId) return a;
    }
    return null;
  }

  /// Tìm `ExpenseItem` theo `id` trên toàn bộ các tháng.
  ExpenseItem? findItemById(String id) {
    for (final list in itemsByMonth.values) {
      for (final item in list) {
        if (item.id == id) return item;
      }
    }
    return null;
  }

  /// Toàn bộ các khoản chi đã tải trong bộ nhớ (phục vụ gợi ý Autocomplete tên khoản chi).
  List<ExpenseItem> get allLoadedExpenses {
    final out = <ExpenseItem>[];
    for (final list in itemsByMonth.values) {
      out.addAll(list);
    }
    return out;
  }

  /// Bản tóm tắt của một tháng bất kỳ ym (ưu tiên summariesByMonth, hoặc tính từ itemsByMonth).
  LedgerSummary summaryForMonth(String ymOrSlash) {
    final ym = FinanceMonthUtils.toYearMonth(ymOrSlash, clock);
    final serverSummary = summariesByMonth[ym];
    if (serverSummary != null && !dirtyMonths.contains(ym)) {
      return serverSummary;
    }
    final list = itemsByMonth[ym] ?? const <ExpenseItem>[];
    return LedgerSummary.fromItems(
      items: list,
      groups: groups,
      prevMonth:
          serverSummary?.prevMonth ??
          const LedgerPrevMonthSummary(month: '', total: 0),
      revenue: serverSummary?.revenue ?? 0,
      cashOut:
          serverSummary?.cashOut ??
          const LedgerCashOutSummary(total: 0, earlier: 0),
    );
  }

  /// Tổng chi và số khoản của một tháng bất kỳ (dùng cho menu chọn tháng).
  ({int total, int count, bool loaded}) statsForMonth(String ymOrSlash) {
    final ym = FinanceMonthUtils.toYearMonth(ymOrSlash, clock);
    final summary = summariesByMonth[ym];
    if (summary != null && !dirtyMonths.contains(ym)) {
      return (total: summary.total, count: summary.count, loaded: true);
    }
    if (loadedMonths.contains(ym)) {
      final list = itemsByMonth[ym] ?? const <ExpenseItem>[];
      final total = list
          .where((e) => e.countsAsExpense)
          .fold<int>(0, (s, e) => s + e.amount);
      final count = list.where((e) => e.countsAsExpense).length;
      return (total: total, count: count, loaded: true);
    }
    return (total: 0, count: 0, loaded: false);
  }

  FinanceLedgerState copyWith({
    String? activeMonth,
    Map<String, List<ExpenseItem>>? itemsByMonth,
    Map<String, LedgerSummary>? summariesByMonth,
    Set<String>? loadedMonths,
    Set<String>? dirtyMonths,
    List<ExpenseGroup>? groups,
    List<RecurringTemplateMeta>? recurringTemplates,
    List<MoneyAccount>? accounts,
    int? catalogYear,
    Set<String>? recurDismissedMonths,
    bool? recurOpen,
    Map<String, Set<String>>? recurUnselectedKeysByMonth,
    Map<String, Map<String, int>>? recurCustomAmountsByMonth,
    bool? grpOpen,
    String? Function()? fltStatus,
    String? Function()? fltGroup,
    ExpenseSortMode? sortMode,
    bool? searchOpen,
    String? searchQuery,
    Set<String>? flashedIds,
    int? nextSeq,
    bool? isLoading,
    String? Function()? errorMessage,
    FinanceToastMessage? Function()? toast,
    bool? syncing,
  }) {
    return FinanceLedgerState(
      activeMonth: activeMonth ?? this.activeMonth,
      itemsByMonth: itemsByMonth ?? this.itemsByMonth,
      summariesByMonth: summariesByMonth ?? this.summariesByMonth,
      loadedMonths: loadedMonths ?? this.loadedMonths,
      dirtyMonths: dirtyMonths ?? this.dirtyMonths,
      groups: groups ?? this.groups,
      recurringTemplates: recurringTemplates ?? this.recurringTemplates,
      accounts: accounts ?? this.accounts,
      catalogYear: catalogYear ?? this.catalogYear,
      recurDismissedMonths: recurDismissedMonths ?? this.recurDismissedMonths,
      recurOpen: recurOpen ?? this.recurOpen,
      recurUnselectedKeysByMonth:
          recurUnselectedKeysByMonth ?? this.recurUnselectedKeysByMonth,
      recurCustomAmountsByMonth:
          recurCustomAmountsByMonth ?? this.recurCustomAmountsByMonth,
      grpOpen: grpOpen ?? this.grpOpen,
      fltStatus: fltStatus != null ? fltStatus() : this.fltStatus,
      fltGroup: fltGroup != null ? fltGroup() : this.fltGroup,
      sortMode: sortMode ?? this.sortMode,
      searchOpen: searchOpen ?? this.searchOpen,
      searchQuery: searchQuery ?? this.searchQuery,
      flashedIds: flashedIds ?? this.flashedIds,
      nextSeq: nextSeq ?? this.nextSeq,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      toast: toast != null ? toast() : this.toast,
      syncing: syncing ?? this.syncing,
      clock: clock,
    );
  }
}
