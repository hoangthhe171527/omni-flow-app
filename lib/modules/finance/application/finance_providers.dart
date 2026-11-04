import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/text_search.dart';
import '../data/finance_api.dart';
import '../domain/finance_models.dart';
import '../domain/smart_expense_parser.dart';

/// Đồng hồ nghiệp vụ cho Sổ chi phí (`null` = giờ thực tế, có thể override trong test).
final financeClockProvider = Provider<DateTime?>((ref) => null);

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
    final months = <String>[
      FinanceMonthUtils.shiftMonth(anchor, -1),
    ];
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
          ? '${tpl.title} · ${Formatters.vndCompact(latestAmt)}'
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

  /// Gom nhóm danh sách khoản chi đã lọc theo `sortMode` hiện hành.
  List<ExpenseListSection> get groupedSections {
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
      prevMonth: serverSummary?.prevMonth ??
          const LedgerPrevMonthSummary(month: '', total: 0),
      revenue: serverSummary?.revenue ?? 0,
      cashOut: serverSummary?.cashOut ??
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

final financeLedgerProvider =
    NotifierProvider<FinanceLedgerNotifier, FinanceLedgerState>(
      FinanceLedgerNotifier.new,
    );

class FinanceLedgerNotifier extends Notifier<FinanceLedgerState> {
  Timer? _toastTimer;
  Timer? _flashTimer;
  int _toastCounter = 0;
  bool _disposed = false;

  @override
  FinanceLedgerState build() {
    _disposed = false;
    // Bắt buộc watch `financeApiProvider` để khi đổi workspace/tenant (APP-I14 / multi-tenant),
    // provider tự huỷ bộ nhớ đệm cũ và tải lại dữ liệu của công ty mới.
    ref.watch(financeApiProvider);
    final clock = ref.watch(financeClockProvider);

    ref.onDispose(() {
      _disposed = true;
      _toastTimer?.cancel();
      _flashTimer?.cancel();
    });

    final initial = FinanceLedgerState.initial(clock: clock);
    Future.microtask(_hydrateInitial);
    return initial;
  }

  FinanceApi get _api => ref.read(financeApiProvider);

  String _errorMessageOf(Object error) {
    if (error is AppException && error.message.trim().isNotEmpty) {
      return error.message;
    }
    return 'Không thể đồng bộ dữ liệu với máy chủ. Vui lòng thử lại.';
  }

  Future<void> _hydrateInitial() async {
    if (_disposed) return;
    final ym = state.activeMonth;
    final year = FinanceMonthUtils.yearOf(ym);

    try {
      final results = await Future.wait<Object?>([
        _api.fetchGroupsCatalog(year: year),
        _api.fetchAccounts(),
        _api.fetchMonthLedger(month: ym),
      ]);
      if (_disposed) return;

      final catalog = results[0] as ExpenseGroupsCatalog;
      final remoteAccounts = results[1] as List<MoneyAccount>;
      final remoteLedger = results[2] as MonthLedger;

      final itemsMap = Map<String, List<ExpenseItem>>.from(state.itemsByMonth)
        ..[remoteLedger.month] = remoteLedger.items;
      final summariesMap = Map<String, LedgerSummary>.from(
        state.summariesByMonth,
      )..[remoteLedger.month] = remoteLedger.summary;
      final loaded = Set<String>.from(state.loadedMonths)
        ..add(remoteLedger.month);
      final dirty = Set<String>.from(state.dirtyMonths)
        ..remove(remoteLedger.month);

      state = state.copyWith(
        groups: catalog.groups,
        recurringTemplates: catalog.recurringTemplates,
        accounts: remoteAccounts,
        catalogYear: year,
        itemsByMonth: itemsMap,
        summariesByMonth: summariesMap,
        loadedMonths: loaded,
        dirtyMonths: dirty,
        isLoading: false,
        syncing: false,
        errorMessage: () => null,
      );

      unawaited(_prefetchHistoryMonths(ym));
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(
        isLoading: false,
        syncing: false,
        errorMessage: () => _errorMessageOf(e),
      );
    }
  }

  /// Tải ngầm 3 tháng liền trước (`M-1`, `M-2`, `M-3`) để chuyển tab tức thì và có lịch sử thật cho gợi ý.
  Future<void> _prefetchHistoryMonths(String anchorYm) async {
    final months = <String>[
      FinanceMonthUtils.shiftMonth(anchorYm, -1),
      FinanceMonthUtils.shiftMonth(anchorYm, -2),
      FinanceMonthUtils.shiftMonth(anchorYm, -3),
    ];
    final missing = [
      for (final m in months)
        if (!state.loadedMonths.contains(m)) m,
    ];
    if (missing.isEmpty || _disposed) return;

    final fetched = await Future.wait<MonthLedger?>([
      for (final m in missing)
        _api
            .fetchMonthLedger(month: m)
            .then<MonthLedger?>((v) => v)
            .catchError((_) => null),
    ]);
    if (_disposed) return;

    final nextItems = Map<String, List<ExpenseItem>>.from(state.itemsByMonth);
    final nextSummaries = Map<String, LedgerSummary>.from(
      state.summariesByMonth,
    );
    final nextLoaded = Set<String>.from(state.loadedMonths);

    var changed = false;
    for (final ledger in fetched) {
      if (ledger == null) continue;
      if (state.dirtyMonths.contains(ledger.month)) continue;
      nextItems[ledger.month] = ledger.items;
      nextSummaries[ledger.month] = ledger.summary;
      nextLoaded.add(ledger.month);
      changed = true;
    }

    if (changed) {
      state = state.copyWith(
        itemsByMonth: nextItems,
        summariesByMonth: nextSummaries,
        loadedMonths: nextLoaded,
      );
    }
  }

  /// Làm mới dữ liệu từ máy chủ (kéo để làm mới hoặc bấm Thử lại).
  Future<void> refresh() async {
    if (_disposed) return;
    final ym = state.activeMonth;
    final year = FinanceMonthUtils.yearOf(ym);
    final hasLoaded = state.loadedMonths.contains(ym);

    state = state.copyWith(
      isLoading: !hasLoaded,
      syncing: hasLoaded,
      errorMessage: () => null,
    );

    try {
      final results = await Future.wait<Object?>([
        _api.fetchGroupsCatalog(year: year),
        _api.fetchAccounts(),
        _api.fetchMonthLedger(month: ym),
      ]);
      if (_disposed) return;

      final catalog = results[0] as ExpenseGroupsCatalog;
      final remoteAccounts = results[1] as List<MoneyAccount>;
      final remoteLedger = results[2] as MonthLedger;

      final itemsMap = Map<String, List<ExpenseItem>>.from(state.itemsByMonth)
        ..[remoteLedger.month] = remoteLedger.items;
      final summariesMap = Map<String, LedgerSummary>.from(
        state.summariesByMonth,
      )..[remoteLedger.month] = remoteLedger.summary;
      final loaded = Set<String>.from(state.loadedMonths)
        ..add(remoteLedger.month);
      final dirty = Set<String>.from(state.dirtyMonths)
        ..remove(remoteLedger.month);

      state = state.copyWith(
        groups: catalog.groups,
        recurringTemplates: catalog.recurringTemplates,
        accounts: remoteAccounts,
        catalogYear: year,
        itemsByMonth: itemsMap,
        summariesByMonth: summariesMap,
        loadedMonths: loaded,
        dirtyMonths: dirty,
        isLoading: false,
        syncing: false,
        errorMessage: () => null,
      );

      unawaited(_prefetchHistoryMonths(ym));
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(
        isLoading: false,
        syncing: false,
        errorMessage: hasLoaded ? () => null : () => _errorMessageOf(e),
      );
      if (hasLoaded) {
        showToast(_errorMessageOf(e));
      }
    }
  }

  Future<void> _refreshMonths(Set<String> months) async {
    if (months.isEmpty || _disposed) return;
    final toFetch = <String>{
      ...months,
      // Nếu sửa tháng liền trước của `activeMonth`, làm mới luôn `activeMonth` để `prev_month` chuẩn xác.
      if (months.contains(FinanceMonthUtils.shiftMonth(state.activeMonth, -1)))
        state.activeMonth,
    };

    final results = await Future.wait<MonthLedger?>([
      for (final m in toFetch)
        _api
            .fetchMonthLedger(month: m)
            .then<MonthLedger?>((v) => v)
            .catchError((_) => null),
    ]);
    if (_disposed) return;

    final nextItems = Map<String, List<ExpenseItem>>.from(state.itemsByMonth);
    final nextSummaries = Map<String, LedgerSummary>.from(
      state.summariesByMonth,
    );
    final nextLoaded = Set<String>.from(state.loadedMonths);
    final nextDirty = Set<String>.from(state.dirtyMonths);

    for (final ledger in results) {
      if (ledger == null) continue;
      nextItems[ledger.month] = ledger.items;
      nextSummaries[ledger.month] = ledger.summary;
      nextLoaded.add(ledger.month);
      nextDirty.remove(ledger.month);
    }

    state = state.copyWith(
      itemsByMonth: nextItems,
      summariesByMonth: nextSummaries,
      loadedMonths: nextLoaded,
      dirtyMonths: nextDirty,
      syncing: false,
    );
  }

  /// Chọn tháng (`pickMonth`) và tải dữ liệu thực của tháng đó từ API.
  /// Đảm bảo tập hợp các tháng `months` đã được tải từ API (phục vụ màn Tổng hợp chi phí Tháng · Quý · Năm).
  Future<void> ensureMonthsLoaded(
    Iterable<String> months, {
    bool forceRefresh = false,
  }) async {
    final normalized = <String>{
      for (final m in months) FinanceMonthUtils.toYearMonth(m, state.clock),
    };
    final toFetch = forceRefresh
        ? normalized
        : normalized.difference(state.loadedMonths);
    if (toFetch.isEmpty) return;
    state = state.copyWith(syncing: true);
    await _refreshMonths(toFetch);
  }

  Future<void> selectMonth(String ymOrSlash) async {
    final ym = FinanceMonthUtils.toYearMonth(ymOrSlash, state.clock);
    final alreadyLoaded = state.loadedMonths.contains(ym);
    final targetYear = FinanceMonthUtils.yearOf(ym);
    final yearChanged = targetYear != state.catalogYear;

    state = state.copyWith(
      activeMonth: ym,
      fltStatus: () => null,
      fltGroup: () => null,
      recurOpen: false,
      isLoading: !alreadyLoaded,
      syncing: alreadyLoaded,
      errorMessage: () => null,
    );

    try {
      final futures = <Future<Object?>>[
        _api.fetchMonthLedger(month: ym),
        if (yearChanged || state.groups.isEmpty)
          _api.fetchGroupsCatalog(year: targetYear),
        if (state.accounts.isEmpty) _api.fetchAccounts(),
      ];
      final results = await Future.wait<Object?>(futures);
      if (_disposed) return;

      final ledger = results[0] as MonthLedger;
      var idx = 1;
      ExpenseGroupsCatalog? newCatalog;
      if (yearChanged || state.groups.isEmpty) {
        newCatalog = results[idx++] as ExpenseGroupsCatalog;
      }
      List<MoneyAccount>? newAccounts;
      if (state.accounts.isEmpty && idx < results.length) {
        newAccounts = results[idx] as List<MoneyAccount>;
      }

      final nextItems = Map<String, List<ExpenseItem>>.from(state.itemsByMonth)
        ..[ledger.month] = ledger.items;
      final nextSummaries = Map<String, LedgerSummary>.from(
        state.summariesByMonth,
      )..[ledger.month] = ledger.summary;
      final nextLoaded = Set<String>.from(state.loadedMonths)
        ..add(ledger.month);
      final nextDirty = Set<String>.from(state.dirtyMonths)
        ..remove(ledger.month);

      state = state.copyWith(
        itemsByMonth: nextItems,
        summariesByMonth: nextSummaries,
        loadedMonths: nextLoaded,
        dirtyMonths: nextDirty,
        groups: newCatalog?.groups,
        recurringTemplates: newCatalog?.recurringTemplates,
        catalogYear: newCatalog != null ? targetYear : state.catalogYear,
        accounts: newAccounts,
        isLoading: false,
        syncing: false,
        errorMessage: () => null,
      );

      unawaited(_prefetchHistoryMonths(ym));
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(
        isLoading: false,
        syncing: false,
        errorMessage: alreadyLoaded ? () => null : () => _errorMessageOf(e),
      );
      if (alreadyLoaded) {
        showToast(_errorMessageOf(e));
      }
    }
  }

  /// Bật / tắt thanh tìm kiếm.
  void toggleSearch() {
    final nextOpen = !state.searchOpen;
    state = state.copyWith(
      searchOpen: nextOpen,
      searchQuery: nextOpen ? state.searchQuery : '',
    );
  }

  /// Đóng thanh tìm kiếm và xoá từ khoá.
  void clearSearch() {
    state = state.copyWith(searchOpen: false, searchQuery: '');
  }

  /// Cập nhật từ khoá tìm kiếm.
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Đổi chế độ sắp xếp danh sách.
  void setSortMode(ExpenseSortMode mode) {
    state = state.copyWith(sortMode: mode);
  }

  /// Bật / tắt bảng tỷ trọng nhóm.
  void toggleGroupBreakdown() {
    state = state.copyWith(grpOpen: !state.grpOpen);
  }

  /// Lọc theo trạng thái `'paid'` hoặc `'owe'`.
  void toggleStatusFilter(String status) {
    final next = state.fltStatus == status ? null : status;
    state = state.copyWith(fltStatus: () => next);
  }

  /// Lọc theo nhóm chi phí.
  void toggleGroupFilter(String groupId) {
    final next = state.fltGroup == groupId ? null : groupId;
    state = state.copyWith(fltGroup: () => next);
  }

  /// Xoá toàn bộ bộ lọc và đưa sắp xếp về mặc định.
  void clearFilters() {
    state = state.copyWith(
      fltStatus: () => null,
      fltGroup: () => null,
      sortMode: ExpenseSortMode.spentDateDesc,
    );
  }

  /// Mở / đóng thẻ Khoản cố định.
  void toggleRecurringExpanded() {
    state = state.copyWith(recurOpen: !state.recurOpen);
  }

  /// Tick / bỏ tick một khoản cố định.
  void toggleRecurringItem(int index) {
    final suggestions = state.activeRecurringSuggestions;
    if (index < 0 || index >= suggestions.length) return;
    final key = suggestions[index].key;
    final ym = state.activeMonth;
    final currentSet = Set<String>.from(
      state.recurUnselectedKeysByMonth[ym] ?? const <String>{},
    );
    if (currentSet.contains(key)) {
      currentSet.remove(key);
    } else {
      currentSet.add(key);
    }
    final nextMap = Map<String, Set<String>>.from(
      state.recurUnselectedKeysByMonth,
    )..[ym] = currentSet;
    state = state.copyWith(recurUnselectedKeysByMonth: nextMap);
  }

  /// Chỉnh số tiền của một khoản cố định.
  void updateRecurringAmount(int index, int newAmount) {
    final suggestions = state.activeRecurringSuggestions;
    if (index < 0 || index >= suggestions.length || newAmount <= 0) return;
    final key = suggestions[index].key;
    final ym = state.activeMonth;

    final nextAmtForMonth = Map<String, int>.from(
      state.recurCustomAmountsByMonth[ym] ?? const <String, int>{},
    )..[key] = newAmount;
    final nextCustomMap = Map<String, Map<String, int>>.from(
      state.recurCustomAmountsByMonth,
    )..[ym] = nextAmtForMonth;

    final nextUnselected = Set<String>.from(
      state.recurUnselectedKeysByMonth[ym] ?? const <String>{},
    )..remove(key);
    final nextUnselectedMap = Map<String, Set<String>>.from(
      state.recurUnselectedKeysByMonth,
    )..[ym] = nextUnselected;

    state = state.copyWith(
      recurCustomAmountsByMonth: nextCustomMap,
      recurUnselectedKeysByMonth: nextUnselectedMap,
    );
  }

  /// Ghi các khoản cố định vào tháng hiện tại và đồng bộ `POST /finance/expenses` lên API.
  Future<void> commitRecurring({bool all = false}) async {
    final ym = state.activeMonth;
    if (state.recurDismissedMonths.contains(ym)) return;

    final suggestions = state.activeRecurringSuggestions;
    final sel = state.recurSel;
    final amtList = state.recurAmt;

    final chosen = <({RecurringExpenseSuggestion suggestion, int amount})>[];
    for (var i = 0; i < suggestions.length; i++) {
      if (all || (i < sel.length && sel[i])) {
        chosen.add((
          suggestion: suggestions[i],
          amount: i < amtList.length
              ? amtList[i]
              : suggestions[i].suggestedAmount,
        ));
      }
    }
    if (chosen.isEmpty) return;

    final validChosen = [
      for (final c in chosen)
        if (c.amount > 0) c,
    ];
    if (validChosen.isEmpty) {
      state = state.copyWith(recurOpen: true);
      showToast('Chạm vào từng khoản cố định để nhập số tiền trước khi ghi');
      return;
    }

    final rollbackState = state;
    var seq = state.nextSeq;
    final optimisticItems = <ExpenseItem>[];
    final optimisticIds = <String>{};
    var totalAdded = 0;
    final nowFormatted = FinanceMonthUtils.formatServerTimestamp(
      VnTime.now(state.clock).toIso8601String(),
    );

    for (final entry in validChosen) {
      final s = entry.suggestion;
      final amt = entry.amount;
      final tempId = 'tmp_${seq++}';
      optimisticIds.add(tempId);
      totalAdded += amt;
      final paidOn = FinanceMonthUtils.clampPaidOn(
        s.spentOnForMonth,
        state.clock,
      );
      optimisticItems.add(
        ExpenseItem(
          id: tempId,
          spentOn: s.spentOnForMonth,
          month: ym,
          groupId: s.groupId,
          groupName: s.groupName,
          groupColor: s.groupColor,
          countsAsExpense: state.groupById(s.groupId).countsAsExpense,
          title: s.titleForMonth,
          amount: amt,
          accountId: s.accountId,
          accountName: s.accountName,
          status: ExpenseStatus.paid,
          paidAmount: amt,
          outstanding: 0,
          createdAt: nowFormatted,
          payments: [
            ExpensePayment(
              id: 'p_$tempId',
              paidOn: paidOn,
              amount: amt,
              accountId: s.accountId,
              accountName: s.accountName,
            ),
          ],
        ),
      );
    }

    final updatedMonthList = <ExpenseItem>[
      ...optimisticItems,
      ...state.activeMonthItems,
    ];
    final updatedItemsByMonth = Map<String, List<ExpenseItem>>.from(
      state.itemsByMonth,
    )..[ym] = updatedMonthList;
    final updatedDismissed = Set<String>.from(state.recurDismissedMonths)
      ..add(ym);
    final updatedDirty = Set<String>.from(state.dirtyMonths)..add(ym);

    state = state.copyWith(
      itemsByMonth: updatedItemsByMonth,
      recurDismissedMonths: updatedDismissed,
      dirtyMonths: updatedDirty,
      recurOpen: false,
      nextSeq: seq,
      syncing: true,
    );
    _flashRows(optimisticIds);

    final createBatchFuture = Future.wait<ExpenseItem>([
      for (final entry in validChosen)
        _api.createExpense(
          spentOn: entry.suggestion.spentOnForMonth,
          groupId: entry.suggestion.groupId,
          title: entry.suggestion.titleForMonth,
          amount: entry.amount,
          accountId: entry.suggestion.accountId,
          payments: [
            {
              'paid_on': FinanceMonthUtils.clampPaidOn(
                entry.suggestion.spentOnForMonth,
                state.clock,
              ),
              'amount': entry.amount,
              'account_id': entry.suggestion.accountId,
              'note': null,
            },
          ],
        ),
    ]);

    showToast(
      'Đã ghi ${validChosen.length} khoản cố định · ${FinanceMonthUtils.formatVndSpace(totalAdded)}',
      onUndo: () async {
        final createdItems = await createBatchFuture;
        await Future.wait<void>([
          for (final item in createdItems) _api.deleteExpense(item.id),
        ]);
        if (_disposed) return;
        final nextDismissed = Set<String>.from(state.recurDismissedMonths)
          ..remove(ym);
        state = state.copyWith(recurDismissedMonths: nextDismissed);
        await _refreshMonths({ym});
      },
    );

    try {
      final createdItems = await createBatchFuture;
      if (_disposed) return;
      _flashRows({for (final c in createdItems) c.id});
      await _refreshMonths({ym});
    } catch (e) {
      if (_disposed) return;
      state = rollbackState.copyWith(toast: () => null, syncing: false);
      showToast(_errorMessageOf(e));
    }
  }

  /// Thêm một khoản chi mới và đồng bộ `POST /finance/expenses` lên API.
  Future<ExpenseItem?> addExpense({
    required String title,
    required int amount,
    required String groupId,
    required String spentOn,
    required bool isPaid,
    String? paidOn,
    String? accountId,
    String? accountName,
    String? note,
    String? createdAt,
    List<ExpenseAttachment> attachments = const [],
  }) async {
    final isoDate = FinanceMonthUtils.toIsoDate(spentOn, state.activeMonth);
    final targetMonth = isoDate.substring(0, 7);
    final resolvedGroupId =
        groupId.isNotEmpty && state.groups.any((g) => g.id == groupId)
        ? groupId
        : state.defaultGroupId;
    if (resolvedGroupId.isEmpty) {
      showToast('Chưa có danh mục nhóm chi phí khả dụng');
      return null;
    }

    final grp = state.groupById(resolvedGroupId);
    final resolvedAcc = _resolveAccount(
      accountId: accountId,
      accountName: accountName,
      fallbackDefault: isPaid,
    );
    final cleanTitle = title.trim().isNotEmpty ? title.trim() : grp.name;
    final tempId = 'tmp_${state.nextSeq}';
    final effectivePaidOn = (paidOn != null && paidOn.trim().isNotEmpty)
        ? FinanceMonthUtils.clampPaidOn(
            FinanceMonthUtils.toIsoDate(paidOn.trim(), targetMonth),
            state.clock,
          )
        : FinanceMonthUtils.clampPaidOn(isoDate, state.clock);
    final nowDisplay =
        createdAt ??
        FinanceMonthUtils.formatServerTimestamp(
          VnTime.now(state.clock).toIso8601String(),
        );

    final optimisticItem = ExpenseItem(
      id: tempId,
      spentOn: isoDate,
      month: targetMonth,
      groupId: grp.id,
      groupName: grp.name,
      groupColor: grp.color,
      countsAsExpense: grp.countsAsExpense,
      title: cleanTitle,
      amount: amount,
      accountId: resolvedAcc?.id,
      accountName: resolvedAcc?.name,
      status: isPaid ? ExpenseStatus.paid : ExpenseStatus.unpaid,
      paidAmount: isPaid ? amount : 0,
      outstanding: isPaid ? 0 : amount,
      note: note,
      createdAt: nowDisplay,
      payments: isPaid
          ? [
              ExpensePayment(
                id: 'p_$tempId',
                paidOn: effectivePaidOn,
                amount: amount,
                accountId: resolvedAcc?.id,
                accountName: resolvedAcc?.name,
              ),
            ]
          : const [],
      attachments: attachments,
    );

    final rollbackState = state;
    final existingMonthList =
        state.itemsByMonth[targetMonth] ?? const <ExpenseItem>[];
    final updatedMap = Map<String, List<ExpenseItem>>.from(state.itemsByMonth)
      ..[targetMonth] = <ExpenseItem>[optimisticItem, ...existingMonthList];
    final updatedDirty = Set<String>.from(state.dirtyMonths)..add(targetMonth);

    state = state.copyWith(
      itemsByMonth: updatedMap,
      dirtyMonths: updatedDirty,
      nextSeq: state.nextSeq + 1,
      fltStatus: () => null,
      fltGroup: () => null,
      syncing: true,
    );
    if (targetMonth == state.activeMonth) {
      _flashRows({tempId});
    }

    final paymentInputs = isPaid
        ? <Map<String, dynamic>>[
            {
              'paid_on': effectivePaidOn,
              'amount': amount,
              'account_id': resolvedAcc?.id,
              'note': null,
            },
          ]
        : const <Map<String, dynamic>>[];

    final attachmentInputs = <Map<String, dynamic>>[
      for (final a in attachments)
        if (a.url.trim().isNotEmpty) a.toInputJson(),
    ];

    final createFuture = _api.createExpense(
      spentOn: isoDate,
      groupId: grp.id,
      title: cleanTitle,
      amount: amount,
      accountId: resolvedAcc?.id,
      note: note,
      payments: paymentInputs,
      attachments: attachmentInputs.isEmpty ? null : attachmentInputs,
    );

    showToast(
      'Đã thêm "$cleanTitle" · ${FinanceMonthUtils.formatVndSpace(amount)}',
      onUndo: () async {
        final created = await createFuture;
        await _api.deleteExpense(created.id);
        await _refreshMonths({targetMonth});
      },
    );

    try {
      final created = await createFuture;
      if (_disposed) return created;
      _replaceItemByIdInMonth(targetMonth, tempId, created);
      if (targetMonth == state.activeMonth) {
        _flashRows({created.id});
      }
      await _refreshMonths({targetMonth});
      return created;
    } catch (e) {
      if (_disposed) return null;
      state = rollbackState.copyWith(toast: () => null, syncing: false);
      showToast(_errorMessageOf(e));
      return null;
    }
  }

  /// Đính kèm thêm một chứng từ đã tải lên (`POST /finance/attachments`) vào khoản chi.
  Future<void> addAttachmentToExpense(
    String itemId,
    ExpenseAttachment attachment,
  ) async {
    final found = _locateItem(itemId);
    if (found == null) return;
    final prevAttachments = found.item.attachments;
    final nextAttachments = <ExpenseAttachment>[...prevAttachments, attachment];

    final rollbackState = state;
    _replaceItemInMonth(
      found.month,
      found.item.copyWith(attachments: nextAttachments),
    );

    final updateFuture = _api.updateExpense(
      id: itemId,
      patch: {
        'attachments': [for (final a in nextAttachments) a.toInputJson()],
      },
    );

    showToast(
      'Đã đính kèm "${attachment.name}"',
      onUndo: () async {
        await updateFuture;
        await _api.updateExpense(
          id: itemId,
          patch: {
            'attachments': [for (final a in prevAttachments) a.toInputJson()],
          },
        );
        await _refreshMonths({found.month});
      },
    );

    try {
      final serverItem = await updateFuture;
      if (_disposed) return;
      _replaceItemInMonth(found.month, serverItem);
      await _refreshMonths({found.month});
    } catch (e) {
      if (_disposed) return;
      state = rollbackState.copyWith(toast: () => null, syncing: false);
      showToast(_errorMessageOf(e));
    }
  }

  /// Xoá một chứng từ đính kèm khỏi khoản chi trên máy chủ.
  Future<void> removeAttachmentFromExpense(
    String itemId,
    String attachmentId,
  ) async {
    final found = _locateItem(itemId);
    if (found == null) return;
    final prevAttachments = found.item.attachments;
    final nextAttachments = <ExpenseAttachment>[
      for (final a in prevAttachments)
        if (a.id != attachmentId) a,
    ];

    final rollbackState = state;
    _replaceItemInMonth(
      found.month,
      found.item.copyWith(attachments: nextAttachments),
    );

    final updateFuture = _api.updateExpense(
      id: itemId,
      patch: {
        'attachments': [for (final a in nextAttachments) a.toInputJson()],
      },
    );

    showToast(
      'Đã gỡ chứng từ đính kèm',
      onUndo: () async {
        await updateFuture;
        await _api.updateExpense(
          id: itemId,
          patch: {
            'attachments': [for (final a in prevAttachments) a.toInputJson()],
          },
        );
        await _refreshMonths({found.month});
      },
    );

    try {
      final serverItem = await updateFuture;
      if (_disposed) return;
      _replaceItemInMonth(found.month, serverItem);
      await _refreshMonths({found.month});
    } catch (e) {
      if (_disposed) return;
      state = rollbackState.copyWith(toast: () => null, syncing: false);
      showToast(_errorMessageOf(e));
    }
  }

  /// Trả đủ ngay lập tức qua `PUT /finance/expenses/{id}/payments`.
  Future<void> markPaidFull(
    String itemId, {
    String? accountId,
    String? accountName,
  }) async {
    final found = _locateItem(itemId);
    if (found == null) return;
    final item = found.item;
    final left = item.remainingAmount;
    if (left <= 0 || item.isRefund) return;

    final resolvedAcc = _resolveAccount(
      accountId: accountId ?? item.defaultPaymentAccountId(state.accounts),
      accountName: accountName ?? item.effectiveAccountName,
      fallbackDefault: true,
    );
    final today = FinanceMonthUtils.todayIso(state.clock);
    final paymentInputs = item.buildPayInFullInputs(
      today: today,
      defaultAccountId: resolvedAcc?.id,
    );
    if (paymentInputs == null) return;

    final prevPaymentInputs = [for (final p in item.payments) p.toInputJson()];
    final rollbackState = state;

    final optimisticPayments = <ExpensePayment>[
      ...item.payments,
      ExpensePayment(
        id: 'p_${item.id}_${item.payments.length + 1}',
        paidOn: today,
        amount: left,
        accountId: resolvedAcc?.id,
        accountName: resolvedAcc?.name,
      ),
    ];
    final updatedItem = item.copyWith(
      status: ExpenseStatus.paid,
      paidAmount: item.amount,
      outstanding: 0,
      payments: optimisticPayments,
    );

    _replaceItemInMonth(found.month, updatedItem, markDirty: true);
    _flashRows({item.id});

    final accLabel = resolvedAcc?.name ?? item.effectiveAccountName;
    final payFuture = _api.replacePayments(
      expenseId: item.id,
      payments: paymentInputs,
    );

    showToast(
      accLabel != null && accLabel.isNotEmpty
          ? 'Đã trả đủ · ${FinanceMonthUtils.formatVndSpace(left)} ($accLabel)'
          : 'Đã trả đủ · ${FinanceMonthUtils.formatVndSpace(left)}',
      onUndo: () async {
        await payFuture;
        await _api.replacePayments(
          expenseId: item.id,
          payments: prevPaymentInputs,
        );
        await _refreshMonths({found.month});
      },
    );

    try {
      final serverItem = await payFuture;
      if (_disposed) return;
      _replaceItemInMonth(found.month, serverItem, markDirty: true);
      await _refreshMonths({found.month});
    } catch (e) {
      if (_disposed) return;
      state = rollbackState.copyWith(toast: () => null, syncing: false);
      showToast(_errorMessageOf(e));
    }
  }

  /// Ghi nhận một lần thanh toán bất kỳ qua `PUT /finance/expenses/{id}/payments`.
  Future<void> recordPayment(
    String itemId, {
    required int amount,
    String? accountId,
    String? accountName,
  }) async {
    final found = _locateItem(itemId);
    if (found == null || amount <= 0) return;
    final item = found.item;
    final left = item.remainingAmount;
    if (left <= 0 || item.isRefund) return;

    final add = math.min(amount, left);
    final resolvedAcc = _resolveAccount(
      accountId: accountId ?? item.defaultPaymentAccountId(state.accounts),
      accountName: accountName ?? item.effectiveAccountName,
      fallbackDefault: true,
    );
    final today = FinanceMonthUtils.todayIso(state.clock);
    final paymentInputs = item.buildAddPaymentInputs(
      paidOn: today,
      paymentAmount: add,
      paymentAccountId: resolvedAcc?.id,
    );
    final prevPaymentInputs = [for (final p in item.payments) p.toInputJson()];
    final rollbackState = state;

    final updatedPayments = <ExpensePayment>[
      ...item.payments,
      ExpensePayment(
        id: 'p_${item.id}_${item.payments.length + 1}',
        paidOn: today,
        amount: add,
        accountId: resolvedAcc?.id,
        accountName: resolvedAcc?.name,
      ),
    ];
    final newPaidTotal = updatedPayments.fold<int>(0, (s, p) => s + p.amount);
    final newLeft = math.max(0, item.amount - newPaidTotal);
    final newStatus = newLeft <= 0
        ? ExpenseStatus.paid
        : (newPaidTotal > 0 ? ExpenseStatus.partial : ExpenseStatus.unpaid);

    final updatedItem = item.copyWith(
      status: newStatus,
      paidAmount: newPaidTotal,
      outstanding: newLeft,
      payments: updatedPayments,
    );

    _replaceItemInMonth(found.month, updatedItem, markDirty: true);
    _flashRows({item.id});

    final accLabel = resolvedAcc?.name ?? item.effectiveAccountName;
    final payFuture = _api.replacePayments(
      expenseId: item.id,
      payments: paymentInputs,
    );

    showToast(
      newLeft <= 0
          ? (accLabel != null && accLabel.isNotEmpty
                ? 'Đã trả đủ · ${FinanceMonthUtils.formatVndSpace(add)} ($accLabel)'
                : 'Đã trả đủ · ${FinanceMonthUtils.formatVndSpace(add)}')
          : 'Đã ghi trả ${FinanceMonthUtils.formatVndSpace(add)} · còn ${FinanceMonthUtils.formatVndSpace(newLeft)}',
      onUndo: () async {
        await payFuture;
        await _api.replacePayments(
          expenseId: item.id,
          payments: prevPaymentInputs,
        );
        await _refreshMonths({found.month});
      },
    );

    try {
      final serverItem = await payFuture;
      if (_disposed) return;
      _replaceItemInMonth(found.month, serverItem, markDirty: true);
      await _refreshMonths({found.month});
    } catch (e) {
      if (_disposed) return;
      state = rollbackState.copyWith(toast: () => null, syncing: false);
      showToast(_errorMessageOf(e));
    }
  }

  /// Đổi số tiền của khoản chi và đồng bộ đúng thứ tự `PUT /expenses` + `PUT /payments` theo luật E6.
  Future<void> updateExpenseAmount(String itemId, int newAmount) async {
    final found = _locateItem(itemId);
    if (found == null || newAmount <= 0 || newAmount == found.item.amount) {
      return;
    }
    final item = found.item;
    if (item.isRefund) {
      showToast('Không thể sửa số tiền của khoản hoàn/chiết khấu âm');
      return;
    }

    final isSingleFull = item.isSingleFullPayment && item.payments.length == 1;
    if (!isSingleFull && item.hasStoredPayments && newAmount < item.paidTotal) {
      showToast(
        'Số tiền mới không thể nhỏ hơn số đã trả (${FinanceMonthUtils.formatVndSpace(item.paidTotal)})',
      );
      return;
    }

    final oldAmount = item.amount;
    final prevPaymentInputs = [for (final p in item.payments) p.toInputJson()];
    final rollbackState = state;

    List<ExpensePayment> nextPayments = item.payments;
    if (isSingleFull) {
      nextPayments = [item.payments.first.copyWith(amount: newAmount)];
    }
    final newPaid = nextPayments.isNotEmpty
        ? nextPayments.fold<int>(0, (s, p) => s + p.amount)
        : (item.isPaid ? newAmount : (item.paidAmount ?? 0));
    final newLeft = math.max(0, newAmount - newPaid);
    final newStatus = newLeft <= 0
        ? ExpenseStatus.paid
        : (newPaid > 0 ? ExpenseStatus.partial : ExpenseStatus.unpaid);

    final updatedItem = item.copyWith(
      amount: newAmount,
      status: newStatus,
      paidAmount: newPaid,
      outstanding: newLeft,
      payments: nextPayments,
    );

    _replaceItemInMonth(found.month, updatedItem, markDirty: true);
    _flashRows({item.id});

    Future<ExpenseItem> runSync() async {
      if (isSingleFull) {
        final singleInput = [
          item.payments.first
              .copyWith(
                amount: newAmount,
                paidOn: FinanceMonthUtils.clampPaidOn(
                  item.payments.first.paidOn,
                  state.clock,
                ),
              )
              .toInputJson(),
        ];
        if (newAmount < oldAmount) {
          // Giảm lần trả trước rồi mới giảm tổng tiền để không vi phạm `amount_below_paid`.
          await _api.replacePayments(expenseId: item.id, payments: singleInput);
          return _api.updateExpense(id: item.id, patch: {'amount': newAmount});
        } else {
          await _api.updateExpense(id: item.id, patch: {'amount': newAmount});
          return _api.replacePayments(
            expenseId: item.id,
            payments: singleInput,
          );
        }
      }
      return _api.updateExpense(
        id: item.id,
        patch: item.buildAmountUpdateBody(newAmount),
      );
    }

    final syncFuture = runSync();

    showToast(
      'Đã cập nhật số tiền · ${FinanceMonthUtils.formatVndSpace(newAmount)}',
      onUndo: () async {
        await syncFuture;
        if (isSingleFull) {
          if (oldAmount < newAmount) {
            await _api.replacePayments(
              expenseId: item.id,
              payments: prevPaymentInputs,
            );
            await _api.updateExpense(id: item.id, patch: {'amount': oldAmount});
          } else {
            await _api.updateExpense(id: item.id, patch: {'amount': oldAmount});
            await _api.replacePayments(
              expenseId: item.id,
              payments: prevPaymentInputs,
            );
          }
        } else {
          await _api.updateExpense(id: item.id, patch: {'amount': oldAmount});
        }
        await _refreshMonths({found.month});
      },
    );

    try {
      final serverItem = await syncFuture;
      if (_disposed) return;
      _replaceItemInMonth(found.month, serverItem, markDirty: true);
      await _refreshMonths({found.month});
    } catch (e) {
      if (_disposed) return;
      state = rollbackState.copyWith(toast: () => null, syncing: false);
      showToast(_errorMessageOf(e));
    }
  }

  /// Đổi tiêu đề khoản chi (`PUT /finance/expenses/{id}`).
  Future<void> updateExpenseTitle(String itemId, String newTitle) async {
    final trimmed = newTitle.trim();
    if (trimmed.isEmpty) return;
    final found = _locateItem(itemId);
    if (found == null || found.item.title == trimmed) return;

    final prevTitle = found.item.title;
    final rollbackState = state;
    _replaceItemInMonth(found.month, found.item.copyWith(title: trimmed));

    final updateFuture = _api.updateExpense(
      id: itemId,
      patch: {'title': trimmed},
    );

    showToast(
      'Đã đổi tên khoản chi',
      onUndo: () async {
        await updateFuture;
        await _api.updateExpense(id: itemId, patch: {'title': prevTitle});
        await _refreshMonths({found.month});
      },
    );

    try {
      final serverItem = await updateFuture;
      if (_disposed) return;
      _replaceItemInMonth(found.month, serverItem);
      await _refreshMonths({found.month});
    } catch (e) {
      if (_disposed) return;
      state = rollbackState.copyWith(toast: () => null, syncing: false);
      showToast(_errorMessageOf(e));
    }
  }

  /// Đổi nhóm chi phí (`PUT /finance/expenses/{id}`).
  Future<void> updateExpenseGroup(String itemId, String newGroupId) async {
    final found = _locateItem(itemId);
    if (found == null || found.item.groupId == newGroupId) return;

    final prevGroupId = found.item.groupId;
    final grp = state.groupById(newGroupId);
    final rollbackState = state;

    final updatedItem = found.item.copyWith(
      groupId: grp.id,
      groupName: grp.name,
      groupColor: grp.color,
      countsAsExpense: grp.countsAsExpense,
    );
    _replaceItemInMonth(found.month, updatedItem, markDirty: true);

    final updateFuture = _api.updateExpense(
      id: itemId,
      patch: {'group_id': grp.id},
    );

    showToast(
      'Đã chuyển sang nhóm "${grp.name}"',
      onUndo: () async {
        await updateFuture;
        await _api.updateExpense(id: itemId, patch: {'group_id': prevGroupId});
        await _refreshMonths({found.month});
      },
    );

    try {
      final serverItem = await updateFuture;
      if (_disposed) return;
      _replaceItemInMonth(found.month, serverItem, markDirty: true);
      await _refreshMonths({found.month});
    } catch (e) {
      if (_disposed) return;
      state = rollbackState.copyWith(toast: () => null, syncing: false);
      showToast(_errorMessageOf(e));
    }
  }

  /// Đổi ngày ghi nhận (`PUT /finance/expenses/{id}`), hỗ trợ cả trường hợp chuyển sang tháng khác.
  Future<void> updateExpenseDate(String itemId, String newIsoDate) async {
    final found = _locateItem(itemId);
    if (found == null) return;
    final normalized = FinanceMonthUtils.toIsoDate(newIsoDate, found.month);
    if (found.item.spentOn == normalized) return;

    final prevSpentOn = found.item.spentOn;
    final prevMonth = found.month;
    final newMonth = normalized.substring(0, 7);
    final prevPayments = found.item.payments;
    final rollbackState = state;

    final syncSinglePaymentDate =
        prevPayments.length == 1 &&
        prevPayments.first.paidOn == prevSpentOn &&
        !found.item.isRefund;
    final clampedPaidOn = FinanceMonthUtils.clampPaidOn(
      normalized,
      state.clock,
    );

    final nextPayments = syncSinglePaymentDate
        ? [prevPayments.first.copyWith(paidOn: clampedPaidOn)]
        : prevPayments;
    final updatedItem = found.item.copyWith(
      spentOn: normalized,
      month: newMonth,
      payments: nextPayments,
    );

    if (newMonth == prevMonth) {
      _replaceItemInMonth(prevMonth, updatedItem, markDirty: true);
    } else {
      final oldBucket = [
        for (final e in state.itemsByMonth[prevMonth] ?? const <ExpenseItem>[])
          if (e.id != itemId) e,
      ];
      final newBucket = <ExpenseItem>[
        updatedItem,
        ...(state.itemsByMonth[newMonth] ?? const <ExpenseItem>[]),
      ];
      final nextMap = Map<String, List<ExpenseItem>>.from(state.itemsByMonth)
        ..[prevMonth] = oldBucket
        ..[newMonth] = newBucket;
      final nextDirty = Set<String>.from(state.dirtyMonths)
        ..add(prevMonth)
        ..add(newMonth);
      state = state.copyWith(
        itemsByMonth: nextMap,
        dirtyMonths: nextDirty,
        syncing: true,
      );
    }

    Future<ExpenseItem> runSync() async {
      var res = await _api.updateExpense(
        id: itemId,
        patch: {'spent_on': normalized},
      );
      if (syncSinglePaymentDate) {
        res = await _api.replacePayments(
          expenseId: itemId,
          payments: [nextPayments.first.toInputJson()],
        );
      }
      return res;
    }

    final syncFuture = runSync();

    showToast(
      'Đã đổi ngày ghi nhận · ${FinanceMonthUtils.fullDayMonthYear(normalized, fallbackMonth: newMonth)}',
      onUndo: () async {
        await syncFuture;
        await _api.updateExpense(id: itemId, patch: {'spent_on': prevSpentOn});
        if (syncSinglePaymentDate) {
          await _api.replacePayments(
            expenseId: itemId,
            payments: [
              prevPayments.first
                  .copyWith(
                    paidOn: FinanceMonthUtils.clampPaidOn(
                      prevPayments.first.paidOn,
                      state.clock,
                    ),
                  )
                  .toInputJson(),
            ],
          );
        }
        await _refreshMonths({prevMonth, newMonth});
      },
    );

    try {
      await syncFuture;
      if (_disposed) return;
      await _refreshMonths({prevMonth, newMonth});
    } catch (e) {
      if (_disposed) return;
      state = rollbackState.copyWith(toast: () => null, syncing: false);
      showToast(_errorMessageOf(e));
    }
  }

  /// Đổi ngày thanh toán của khoản chi (`PUT /finance/expenses/{id}/payments`).
  Future<void> updateExpensePaymentDate(
    String itemId,
    String newPaidOnIso, {
    int paymentIndex = 0,
  }) async {
    final found = _locateItem(itemId);
    if (found == null) return;
    final item = found.item;
    if (item.isRefund || item.payments.isEmpty) return;
    if (paymentIndex < 0 || paymentIndex >= item.payments.length) return;

    final clampedPaidOn = FinanceMonthUtils.clampPaidOn(
      FinanceMonthUtils.toIsoDate(newPaidOnIso, found.month),
      state.clock,
    );
    final prevPayments = item.payments;
    if (prevPayments[paymentIndex].paidOn == clampedPaidOn) return;

    final rollbackState = state;
    final nextPayments = <ExpensePayment>[
      for (var i = 0; i < prevPayments.length; i++)
        i == paymentIndex
            ? prevPayments[i].copyWith(paidOn: clampedPaidOn)
            : prevPayments[i],
    ];
    final updatedItem = item.copyWith(payments: nextPayments);
    _replaceItemInMonth(found.month, updatedItem, markDirty: true);

    final syncFuture = _api.replacePayments(
      expenseId: itemId,
      payments: [
        for (final p in nextPayments)
          p
              .copyWith(
                paidOn: FinanceMonthUtils.clampPaidOn(p.paidOn, state.clock),
              )
              .toInputJson(),
      ],
    );

    showToast(
      'Đã đổi ngày thanh toán · ${FinanceMonthUtils.fullDayMonthYear(clampedPaidOn, fallbackMonth: found.month)}',
      onUndo: () async {
        await syncFuture;
        await _api.replacePayments(
          expenseId: itemId,
          payments: [
            for (final p in prevPayments)
              p
                  .copyWith(
                    paidOn: FinanceMonthUtils.clampPaidOn(
                      p.paidOn,
                      state.clock,
                    ),
                  )
                  .toInputJson(),
          ],
        );
        await _refreshMonths({found.month});
      },
    );

    try {
      final serverItem = await syncFuture;
      if (_disposed) return;
      _replaceItemInMonth(found.month, serverItem, markDirty: true);
      await _refreshMonths({found.month});
    } catch (e) {
      if (_disposed) return;
      state = rollbackState.copyWith(toast: () => null, syncing: false);
      showToast(_errorMessageOf(e));
    }
  }

  /// Đổi nguồn tiền (`PUT /finance/expenses/{id}` + đồng bộ nguồn lần trả cuối nếu đã có `payments`).
  Future<void> updateExpenseAccount(
    String itemId,
    String newAccountIdOrName,
  ) async {
    final found = _locateItem(itemId);
    if (found == null) return;
    final item = found.item;

    final resolvedAcc = _resolveAccount(
      accountId: newAccountIdOrName,
      accountName: newAccountIdOrName,
      fallbackDefault: false,
    );
    final nextAccId = resolvedAcc?.id;
    final nextAccName = resolvedAcc?.name ?? '';

    if (nextAccId == item.accountId &&
        (item.payments.isEmpty || item.payments.last.accountId == nextAccId)) {
      return;
    }

    final prevAccId = item.accountId;
    final prevPayments = item.payments;
    final rollbackState = state;

    var nextPayments = item.payments;
    final canSyncPayments = item.payments.isNotEmpty && !item.isRefund;
    if (canSyncPayments) {
      nextPayments = [
        for (var i = 0; i < item.payments.length; i++)
          if (i == item.payments.length - 1)
            item.payments[i].copyWith(
              accountId: nextAccId,
              accountName: nextAccName,
            )
          else
            item.payments[i],
      ];
    }

    final updatedItem = item.copyWith(
      accountId: nextAccId,
      accountName: nextAccName,
      payments: nextPayments,
    );
    _replaceItemInMonth(found.month, updatedItem, markDirty: true);

    Future<ExpenseItem> runSync() async {
      var res = await _api.updateExpense(
        id: itemId,
        patch: {'account_id': nextAccId},
      );
      if (canSyncPayments) {
        res = await _api.replacePayments(
          expenseId: itemId,
          payments: [
            for (final p in nextPayments)
              p
                  .copyWith(
                    paidOn: FinanceMonthUtils.clampPaidOn(
                      p.paidOn,
                      state.clock,
                    ),
                  )
                  .toInputJson(),
          ],
        );
      }
      return res;
    }

    final syncFuture = runSync();

    showToast(
      nextAccName.isNotEmpty
          ? 'Đã đổi nguồn tiền · $nextAccName'
          : 'Đã bỏ chọn nguồn tiền',
      onUndo: () async {
        await syncFuture;
        await _api.updateExpense(id: itemId, patch: {'account_id': prevAccId});
        if (canSyncPayments) {
          await _api.replacePayments(
            expenseId: itemId,
            payments: [
              for (final p in prevPayments)
                p
                    .copyWith(
                      paidOn: FinanceMonthUtils.clampPaidOn(
                        p.paidOn,
                        state.clock,
                      ),
                    )
                    .toInputJson(),
            ],
          );
        }
        await _refreshMonths({found.month});
      },
    );

    try {
      final serverItem = await syncFuture;
      if (_disposed) return;
      _replaceItemInMonth(found.month, serverItem, markDirty: true);
      await _refreshMonths({found.month});
    } catch (e) {
      if (_disposed) return;
      state = rollbackState.copyWith(toast: () => null, syncing: false);
      showToast(_errorMessageOf(e));
    }
  }

  /// Sao chép khoản chi sang tháng kế tiếp (trạng thái Chưa trả) và ghi lên API.
  Future<void> duplicateToNextMonth(String itemId) async {
    final found = _locateItem(itemId);
    if (found == null) return;
    final item = found.item;
    if (item.amount <= 0) {
      showToast('Không thể sao chép khoản hoàn/chiết khấu âm');
      return;
    }

    final targetMonth = FinanceMonthUtils.shiftMonth(found.month, 1);
    final targetSpentOn = FinanceMonthUtils.shiftDateToMonth(
      item.spentOn,
      targetMonth,
    );
    final adaptedTitle = FinanceMonthUtils.adaptTitleToMonth(
      item.title,
      fromMonth: found.month,
      toMonth: targetMonth,
    );

    final usableGroupId = state.usableGroups.any((g) => g.id == item.groupId)
        ? item.groupId
        : state.defaultGroupId;
    final usableAccId =
        item.accountId != null &&
            state.usableAccounts.any((a) => a.id == item.accountId)
        ? item.accountId
        : null;

    final tempId = 'tmp_${state.nextSeq}';
    final rollbackState = state;
    final nowDisplay = FinanceMonthUtils.formatServerTimestamp(
      VnTime.now(state.clock).toIso8601String(),
    );

    final copy = ExpenseItem(
      id: tempId,
      spentOn: targetSpentOn,
      month: targetMonth,
      groupId: usableGroupId,
      groupName: state.groupById(usableGroupId).name,
      groupColor: state.groupById(usableGroupId).color,
      countsAsExpense: state.groupById(usableGroupId).countsAsExpense,
      title: adaptedTitle,
      amount: item.amount,
      accountId: usableAccId,
      accountName: state.accountById(usableAccId)?.name,
      status: ExpenseStatus.unpaid,
      paidAmount: 0,
      outstanding: item.amount,
      note: item.note,
      createdAt: nowDisplay,
      payments: const [],
      attachments: item.attachments,
    );

    if (state.loadedMonths.contains(targetMonth)) {
      final bucket = <ExpenseItem>[
        copy,
        ...(state.itemsByMonth[targetMonth] ?? const <ExpenseItem>[]),
      ];
      final updatedMap = Map<String, List<ExpenseItem>>.from(state.itemsByMonth)
        ..[targetMonth] = bucket;
      final updatedDirty = Set<String>.from(state.dirtyMonths)
        ..add(targetMonth);
      state = state.copyWith(
        itemsByMonth: updatedMap,
        dirtyMonths: updatedDirty,
        nextSeq: state.nextSeq + 1,
        syncing: true,
      );
    } else {
      state = state.copyWith(nextSeq: state.nextSeq + 1, syncing: true);
    }

    final attachmentInputs = <Map<String, dynamic>>[
      for (final a in item.attachments)
        if (a.url.trim().isNotEmpty) a.toInputJson(),
    ];

    final createFuture = _api.createExpense(
      spentOn: targetSpentOn,
      groupId: usableGroupId,
      title: adaptedTitle,
      amount: item.amount,
      accountId: usableAccId,
      note: item.note,
      payments: const [],
      attachments: attachmentInputs.isEmpty ? null : attachmentInputs,
    );

    showToast(
      'Đã sao chép sang ${FinanceMonthUtils.formatMonthSlash(targetMonth)} (Chưa trả)',
      onUndo: () async {
        final created = await createFuture;
        await _api.deleteExpense(created.id);
        await _refreshMonths({targetMonth});
      },
    );

    try {
      final created = await createFuture;
      if (_disposed) return;
      if (state.loadedMonths.contains(targetMonth)) {
        _replaceItemByIdInMonth(targetMonth, tempId, created);
      }
      await _refreshMonths({targetMonth});
    } catch (e) {
      if (_disposed) return;
      state = rollbackState.copyWith(toast: () => null, syncing: false);
      showToast(_errorMessageOf(e));
    }
  }

  /// Xoá khoản chi (`DELETE /finance/expenses/{id}`) kèm Hoàn tác tạo lại trên máy chủ.
  Future<void> deleteExpense(String itemId) async {
    final found = _locateItem(itemId);
    if (found == null) return;
    final deleted = found.item;
    final rollbackState = state;

    final list = [
      for (final e in state.itemsByMonth[found.month] ?? const <ExpenseItem>[])
        if (e.id != itemId) e,
    ];
    final updatedMap = Map<String, List<ExpenseItem>>.from(state.itemsByMonth)
      ..[found.month] = list;
    final updatedDirty = Set<String>.from(state.dirtyMonths)..add(found.month);

    state = state.copyWith(
      itemsByMonth: updatedMap,
      dirtyMonths: updatedDirty,
      syncing: true,
    );

    final deleteFuture = _api.deleteExpense(itemId);

    final canRecreate = deleted.amount > 0;
    showToast(
      'Đã xoá "${deleted.title}"',
      onUndo: canRecreate
          ? () async {
              await deleteFuture;
              final usableGroupId =
                  state.usableGroups.any((g) => g.id == deleted.groupId)
                  ? deleted.groupId
                  : state.defaultGroupId;
              final usableAccId =
                  deleted.accountId != null &&
                      state.usableAccounts.any((a) => a.id == deleted.accountId)
                  ? deleted.accountId
                  : null;
              final attachmentInputs = <Map<String, dynamic>>[
                for (final a in deleted.attachments)
                  if (a.url.trim().isNotEmpty) a.toInputJson(),
              ];
              final paymentInputs = <Map<String, dynamic>>[
                for (final p in deleted.payments)
                  {
                    'paid_on': FinanceMonthUtils.clampPaidOn(
                      p.paidOn,
                      state.clock,
                    ),
                    'amount': p.amount,
                    'account_id':
                        p.accountId != null &&
                            state.usableAccounts.any((a) => a.id == p.accountId)
                        ? p.accountId
                        : usableAccId,
                    'note': p.note,
                  },
              ];
              await _api.createExpense(
                spentOn: deleted.spentOn,
                groupId: usableGroupId,
                title: deleted.title,
                amount: deleted.amount,
                accountId: usableAccId,
                note: deleted.note,
                payments: paymentInputs,
                attachments: attachmentInputs.isEmpty ? null : attachmentInputs,
              );
              await _refreshMonths({found.month});
            }
          : null,
    );

    try {
      await deleteFuture;
      if (_disposed) return;
      await _refreshMonths({found.month});
    } catch (e) {
      if (_disposed) return;
      state = rollbackState.copyWith(toast: () => null, syncing: false);
      showToast(_errorMessageOf(e));
    }
  }

  /// Thực thi Hoàn tác đồng bộ máy chủ (`undoBtn`).
  Future<void> undo() async {
    final undoFn = state.toast?.onUndo;
    if (undoFn == null) return;
    _toastTimer?.cancel();
    state = state.copyWith(toast: () => null, syncing: true);
    try {
      await undoFn();
      if (_disposed) return;
      showToast('Đã hoàn tác thao tác');
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(syncing: false);
      showToast(_errorMessageOf(e));
    }
  }

  /// Ẩn toast hiện tại.
  void dismissToast() {
    _toastTimer?.cancel();
    state = state.copyWith(toast: () => null);
  }

  /// Hiển thị toast ở đáy màn hình trong 4.5 giây.
  void showToast(String text, {Future<void> Function()? onUndo}) {
    _toastTimer?.cancel();
    final msg = FinanceToastMessage(
      id: ++_toastCounter,
      text: text,
      onUndo: onUndo,
    );
    state = state.copyWith(toast: () => msg);
    _toastTimer = Timer(const Duration(milliseconds: 4500), () {
      if (!_disposed && state.toast?.id == msg.id) {
        state = state.copyWith(toast: () => null);
      }
    });
  }

  void _flashRows(Set<String> ids) {
    _flashTimer?.cancel();
    state = state.copyWith(flashedIds: ids);
    _flashTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!_disposed) {
        state = state.copyWith(flashedIds: const <String>{});
      }
    });
  }

  ({String month, ExpenseItem item})? _locateItem(String itemId) {
    for (final entry in state.itemsByMonth.entries) {
      for (final item in entry.value) {
        if (item.id == itemId) {
          return (month: entry.key, item: item);
        }
      }
    }
    return null;
  }

  void _replaceItemInMonth(
    String month,
    ExpenseItem updated, {
    bool markDirty = false,
  }) {
    final list = state.itemsByMonth[month];
    if (list == null) return;
    final nextList = [
      for (final item in list)
        if (item.id == updated.id) updated else item,
    ];
    final nextMap = Map<String, List<ExpenseItem>>.from(state.itemsByMonth)
      ..[month] = nextList;
    final nextDirty = markDirty
        ? (Set<String>.from(state.dirtyMonths)..add(month))
        : state.dirtyMonths;
    state = state.copyWith(
      itemsByMonth: nextMap,
      dirtyMonths: nextDirty,
      syncing: markDirty ? true : state.syncing,
    );
  }

  void _replaceItemByIdInMonth(
    String month,
    String oldId,
    ExpenseItem replacement,
  ) {
    final list = state.itemsByMonth[month];
    if (list == null) return;
    final nextList = [
      for (final item in list)
        if (item.id == oldId) replacement else item,
    ];
    final nextMap = Map<String, List<ExpenseItem>>.from(state.itemsByMonth)
      ..[month] = nextList;
    state = state.copyWith(itemsByMonth: nextMap);
  }

  MoneyAccount? _resolveAccount({
    String? accountId,
    String? accountName,
    required bool fallbackDefault,
  }) {
    final usable = state.usableAccounts;
    if (accountId != null && accountId.trim().isNotEmpty) {
      for (final a in usable) {
        if (a.id == accountId.trim()) return a;
      }
    }
    if (accountName != null && accountName.trim().isNotEmpty) {
      final targetLower = accountName.trim().toLowerCase();
      for (final a in usable) {
        if (a.name.trim().toLowerCase() == targetLower) return a;
      }
      final folded = foldDiacritics(targetLower);
      if (folded.contains('tien mat')) {
        final cash = usable
            .where((a) => a.kind == MoneyAccountKind.cash)
            .firstOrNull;
        if (cash != null) return cash;
      } else if (folded.contains('ung') || folded.contains('vi')) {
        final adv = usable
            .where((a) => a.kind == MoneyAccountKind.advance)
            .firstOrNull;
        if (adv != null) return adv;
      } else if (folded.contains('ngan hang') ||
          folded.contains('chuyen khoan')) {
        final bank = usable
            .where((a) => a.kind == MoneyAccountKind.bank)
            .firstOrNull;
        if (bank != null) return bank;
      }
    }
    return fallbackDefault ? state.defaultPaymentAccount : null;
  }
}
