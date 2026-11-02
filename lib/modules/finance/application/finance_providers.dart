import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/text_search.dart';
import '../data/finance_api.dart';
import '../domain/finance_models.dart';
import '../domain/smart_expense_parser.dart';

/// Snapshot dùng để Hoàn tác (`Undo`) thao tác vừa thực hiện.
@immutable
class FinanceUndoSnapshot {
  const FinanceUndoSnapshot({
    required this.itemsByMonth,
    required this.recurDone,
    required this.recurOpen,
    required this.recurSel,
    required this.recurAmt,
  });

  final Map<String, List<ExpenseItem>> itemsByMonth;
  final Map<String, bool> recurDone;
  final bool recurOpen;
  final List<bool> recurSel;
  final List<int> recurAmt;
}

/// Thông báo toast ở đáy màn hình kèm khả năng Hoàn tác (`Hoàn tác`).
@immutable
class FinanceToastMessage {
  const FinanceToastMessage({
    required this.id,
    required this.text,
    this.undoSnapshot,
  });

  final int id;
  final String text;
  final FinanceUndoSnapshot? undoSnapshot;

  bool get canUndo => undoSnapshot != null;
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

/// Toàn bộ trạng thái Sổ chi phí khớp 100% với `S` trong `so-chi-phi-mobile.html`
/// cùng các nâng cấp của anh Lê Nguyên (5 khoản cố định, tìm theo số tiền, sắp xếp đa chiều, đính kèm chứng từ).
@immutable
class FinanceLedgerState {
  const FinanceLedgerState({
    required this.activeMonth,
    required this.itemsByMonth,
    required this.groups,
    required this.accounts,
    required this.recurDone,
    required this.recurOpen,
    required this.recurSel,
    required this.recurAmt,
    required this.grpOpen,
    required this.fltStatus,
    required this.fltGroup,
    required this.sortMode,
    required this.searchOpen,
    required this.searchQuery,
    required this.flashedIds,
    required this.nextSeq,
    this.toast,
    this.syncing = false,
  });

  factory FinanceLedgerState.initial() {
    final recurList = FinanceSeedCatalog.defaultRecurringForMonth('2026-11');
    return FinanceLedgerState(
      activeMonth: '2026-11',
      itemsByMonth: FinanceSeedCatalog.buildInitialSeedItems(),
      groups: FinanceSeedCatalog.defaultGroups,
      accounts: FinanceSeedCatalog.defaultAccounts,
      recurDone: const {
        '2026-06': true,
        '2026-07': true,
        '2026-08': true,
        '2026-09': true,
        '2026-10': true,
        '2026-11': false,
      },
      recurOpen: false,
      recurSel: List<bool>.filled(recurList.length, true),
      recurAmt: [for (final r in recurList) r.suggestedAmount],
      grpOpen: false,
      fltStatus: null,
      fltGroup: null,
      sortMode: ExpenseSortMode.spentDateDesc,
      searchOpen: false,
      searchQuery: '',
      flashedIds: const <String>{},
      nextSeq: 200,
    );
  }

  /// Tháng đang chọn (`YYYY-MM`, mặc định `2026-11`).
  final String activeMonth;

  /// Danh sách khoản chi theo từng tháng `YYYY-MM`.
  final Map<String, List<ExpenseItem>> itemsByMonth;

  /// Danh mục nhóm chi phí.
  final List<ExpenseGroup> groups;

  /// Danh mục nguồn tiền.
  final List<MoneyAccount> accounts;

  /// Trạng thái đã ghi khoản cố định của từng tháng (`YYYY-MM` -> `bool`).
  final Map<String, bool> recurDone;

  /// Trạng thái mở rộng thẻ Khoản cố định (`rc.open`).
  final bool recurOpen;

  /// Các khoản cố định đang được tick chọn.
  final List<bool> recurSel;

  /// Số tiền đang chỉnh cho từng khoản cố định.
  final List<int> recurAmt;

  /// Trạng thái mở rộng bảng tỷ trọng nhóm (`grp-panel.open`).
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

  /// Bộ đếm sinh ID cục bộ khi tạo khoản mới.
  final int nextSeq;

  /// Toast thông báo kèm nút Hoàn tác.
  final FinanceToastMessage? toast;

  /// Cờ đồng bộ nền với máy chủ.
  final bool syncing;

  /// Danh sách khoản chi của tháng đang chọn.
  List<ExpenseItem> get activeMonthItems =>
      itemsByMonth[activeMonth] ?? const <ExpenseItem>[];

  /// Tổng hợp tháng đang chọn (`LedgerSummary`), tự động tính cả so sánh với tháng trước.
  LedgerSummary get activeSummary {
    final prevYm = FinanceMonthUtils.shiftMonth(activeMonth, -1);
    final prevItems = itemsByMonth[prevYm] ?? const <ExpenseItem>[];
    final prevTotal = prevItems
        .where((e) => e.countsAsExpense)
        .fold<int>(0, (s, e) => s + e.amount);
    return LedgerSummary.fromItems(
      items: activeMonthItems,
      groups: groups,
      prevMonth: prevItems.isNotEmpty ? prevYm : '',
      prevMonthTotal: prevTotal,
    );
  }

  /// Danh sách khoản cố định gợi ý cho tháng hiện tại.
  List<RecurringExpenseSuggestion> get activeRecurringSuggestions =>
      FinanceSeedCatalog.defaultRecurringForMonth(activeMonth);

  /// Tháng hiện tại còn thẻ Khoản cố định chưa ghi hay không.
  bool get showRecurringCard => !(recurDone[activeMonth] ?? true);

  /// Số khoản cố định đang được tick chọn.
  int get selectedRecurringCount {
    var count = 0;
    for (final sel in recurSel) {
      if (sel) count++;
    }
    return count;
  }

  /// Tổng tiền các khoản cố định đang được tick chọn.
  int get selectedRecurringSum {
    var sum = 0;
    for (var i = 0; i < recurSel.length && i < recurAmt.length; i++) {
      if (recurSel[i]) sum += recurAmt[i];
    }
    return sum;
  }

  /// Tổng tiền cả 5 khoản cố định.
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
    final parts = item.createdAt.trim().split(RegExp(r'\s+'));
    final dm = parts.isNotEmpty
        ? parts.first
        : FinanceMonthUtils.shortDayMonth(item.spentOn);
    final hm = parts.length > 1 ? parts.last : '09:00';
    final isoDate = FinanceMonthUtils.toIsoDate(dm, item.month);
    return '$isoDate $hm';
  }

  bool _matchesFilter(ExpenseItem item, String queryLower) {
    if (fltStatus == 'paid' && !item.isPaid) return false;
    if (fltStatus == 'owe' && item.isPaid) return false;
    if (fltGroup != null && item.groupId != fltGroup) return false;
    if (queryLower.isEmpty) return true;

    final grpName = groupById(item.groupId).name.toLowerCase();
    final accName = (item.effectiveAccountName ?? '').toLowerCase();
    final titleLower = item.title.toLowerCase();
    final foldedQuery = foldDiacritics(queryLower);

    // 1. Khớp tên khoản chi, nhóm, nguồn tiền, tên tệp đính kèm (có dấu & không dấu)
    if (titleLower.contains(queryLower) ||
        grpName.contains(queryLower) ||
        accName.contains(queryLower) ||
        foldDiacritics(titleLower).contains(foldedQuery) ||
        foldDiacritics(grpName).contains(foldedQuery) ||
        foldDiacritics(accName).contains(foldedQuery)) {
      return true;
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
      if (item.amount == parsedAmt ||
          item.paidTotal == parsedAmt ||
          item.remainingAmount == parsedAmt ||
          item.payments.any((p) => p.amount == parsedAmt)) {
        return true;
      }
    }

    // 4. Khớp chuỗi chữ số (2450000, 2.450.000, 2450, 420...)
    final digitsOnly = queryLower.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isNotEmpty &&
        RegExp(r'^[\d.,\sđdvnd]+$').hasMatch(queryLower)) {
      final candidates = <int>[
        item.amount,
        item.paidTotal,
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
              ),
              totalAmount: entry.value.fold<int>(0, (s, e) => s + e.amount),
              items: entry.value,
            ),
        ];

      case ExpenseSortMode.createdAtDesc:
        final byEntryDay = <String, List<ExpenseItem>>{};
        for (final item in list) {
          final dm = item.createdAt.trim().split(RegExp(r'\s+')).first;
          final iso = FinanceMonthUtils.toIsoDate(dm, item.month);
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
            ExpenseListSection(
              key: 'grp_${entry.key}',
              headerLabel: groupById(entry.key).name,
              dotColor: groupById(entry.key).parsedColor,
              totalAmount: entry.value.fold<int>(0, (s, e) => s + e.amount),
              items: entry.value,
            ),
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

  /// Tìm `ExpenseGroup` theo `id` (fallback về nhóm mặc định).
  ExpenseGroup groupById(String groupId) {
    for (final g in groups) {
      if (g.id == groupId) return g;
    }
    for (final g in FinanceSeedCatalog.defaultGroups) {
      if (g.id == groupId) return g;
    }
    return FinanceSeedCatalog.defaultGroups.last;
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

  /// Tổng chi và số khoản của một tháng bất kỳ (dùng cho menu chọn tháng).
  ({int total, int count}) statsForMonth(String ymOrSlash) {
    final ym = FinanceMonthUtils.toYearMonth(ymOrSlash);
    final list = itemsByMonth[ym] ?? const <ExpenseItem>[];
    final total = list
        .where((e) => e.countsAsExpense)
        .fold<int>(0, (s, e) => s + e.amount);
    return (total: total, count: list.length);
  }

  FinanceUndoSnapshot toUndoSnapshot() {
    return FinanceUndoSnapshot(
      itemsByMonth: {
        for (final entry in itemsByMonth.entries)
          entry.key: List<ExpenseItem>.unmodifiable(entry.value),
      },
      recurDone: Map<String, bool>.unmodifiable(recurDone),
      recurOpen: recurOpen,
      recurSel: List<bool>.unmodifiable(recurSel),
      recurAmt: List<int>.unmodifiable(recurAmt),
    );
  }

  FinanceLedgerState copyWith({
    String? activeMonth,
    Map<String, List<ExpenseItem>>? itemsByMonth,
    List<ExpenseGroup>? groups,
    List<MoneyAccount>? accounts,
    Map<String, bool>? recurDone,
    bool? recurOpen,
    List<bool>? recurSel,
    List<int>? recurAmt,
    bool? grpOpen,
    String? Function()? fltStatus,
    String? Function()? fltGroup,
    ExpenseSortMode? sortMode,
    bool? searchOpen,
    String? searchQuery,
    Set<String>? flashedIds,
    int? nextSeq,
    FinanceToastMessage? Function()? toast,
    bool? syncing,
  }) {
    return FinanceLedgerState(
      activeMonth: activeMonth ?? this.activeMonth,
      itemsByMonth: itemsByMonth ?? this.itemsByMonth,
      groups: groups ?? this.groups,
      accounts: accounts ?? this.accounts,
      recurDone: recurDone ?? this.recurDone,
      recurOpen: recurOpen ?? this.recurOpen,
      recurSel: recurSel ?? this.recurSel,
      recurAmt: recurAmt ?? this.recurAmt,
      grpOpen: grpOpen ?? this.grpOpen,
      fltStatus: fltStatus != null ? fltStatus() : this.fltStatus,
      fltGroup: fltGroup != null ? fltGroup() : this.fltGroup,
      sortMode: sortMode ?? this.sortMode,
      searchOpen: searchOpen ?? this.searchOpen,
      searchQuery: searchQuery ?? this.searchQuery,
      flashedIds: flashedIds ?? this.flashedIds,
      nextSeq: nextSeq ?? this.nextSeq,
      toast: toast != null ? toast() : this.toast,
      syncing: syncing ?? this.syncing,
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

  @override
  FinanceLedgerState build() {
    ref.onDispose(() {
      _toastTimer?.cancel();
      _flashTimer?.cancel();
    });
    final initial = FinanceLedgerState.initial();
    Future.microtask(_tryBackgroundHydrate);
    return initial;
  }

  Future<void> _tryBackgroundHydrate() async {
    try {
      final api = ref.read(financeApiProvider);
      final results = await Future.wait<Object?>([
        api.fetchGroups().catchError((_) => const <ExpenseGroup>[]),
        api.fetchAccounts().catchError((_) => const <MoneyAccount>[]),
        api
            .fetchMonthLedger(month: state.activeMonth)
            .then<MonthLedger?>((v) => v)
            .catchError((_) => null),
      ]);
      final remoteGroups = results[0] as List<ExpenseGroup>;
      final remoteAccounts = results[1] as List<MoneyAccount>;
      final remoteLedger = results[2] as MonthLedger?;

      var next = state;
      if (remoteGroups.isNotEmpty) {
        next = next.copyWith(groups: remoteGroups);
      }
      if (remoteAccounts.isNotEmpty) {
        next = next.copyWith(accounts: remoteAccounts);
      }
      if (remoteLedger != null && remoteLedger.items.isNotEmpty) {
        final updatedMap = Map<String, List<ExpenseItem>>.from(
          next.itemsByMonth,
        );
        updatedMap[remoteLedger.month] = remoteLedger.items;
        next = next.copyWith(itemsByMonth: updatedMap);
      }
      state = next;
    } catch (_) {
      // Giữ nguyên dữ liệu mẫu nếu offline hoặc môi trường test không bật backend.
    }
  }

  /// Chọn tháng (`pickMonth` trong HTML).
  void selectMonth(String ymOrSlash) {
    final ym = FinanceMonthUtils.toYearMonth(ymOrSlash);
    if (ym == state.activeMonth &&
        state.fltStatus == null &&
        state.fltGroup == null) {
      return;
    }
    state = state.copyWith(
      activeMonth: ym,
      fltStatus: () => null,
      fltGroup: () => null,
      recurOpen: false,
    );
  }

  /// Bật / tắt thanh tìm kiếm (`toggleSearch` trong HTML).
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

  /// Bật / tắt bảng tỷ trọng nhóm (`toggleGrp` trong HTML).
  void toggleGroupBreakdown() {
    state = state.copyWith(grpOpen: !state.grpOpen);
  }

  /// Lọc theo trạng thái `'paid'` hoặc `'owe'` (`toggleFlt` trong HTML).
  void toggleStatusFilter(String status) {
    final next = state.fltStatus == status ? null : status;
    state = state.copyWith(fltStatus: () => next);
  }

  /// Lọc theo nhóm chi phí (`toggleGrpFlt` trong HTML).
  void toggleGroupFilter(String groupId) {
    final next = state.fltGroup == groupId ? null : groupId;
    state = state.copyWith(fltGroup: () => next);
  }

  /// Xoá toàn bộ bộ lọc và đưa sắp xếp về mặc định (`clearFlt`).
  void clearFilters() {
    state = state.copyWith(
      fltStatus: () => null,
      fltGroup: () => null,
      sortMode: ExpenseSortMode.spentDateDesc,
    );
  }

  /// Mở / đóng thẻ Khoản cố định (`toggleRecur` trong HTML).
  void toggleRecurringExpanded() {
    state = state.copyWith(recurOpen: !state.recurOpen);
  }

  /// Tick / bỏ tick một khoản cố định (`toggleRcItem` trong HTML).
  void toggleRecurringItem(int index) {
    if (index < 0 || index >= state.recurSel.length) return;
    final nextSel = List<bool>.from(state.recurSel);
    nextSel[index] = !nextSel[index];
    state = state.copyWith(recurSel: nextSel);
  }

  /// Chỉnh số tiền của một khoản cố định (`editRcAmt` trong HTML).
  void updateRecurringAmount(int index, int newAmount) {
    if (index < 0 || index >= state.recurAmt.length || newAmount <= 0) return;
    final nextAmt = List<int>.from(state.recurAmt);
    final nextSel = List<bool>.from(state.recurSel);
    nextAmt[index] = newAmount;
    nextSel[index] = true;
    state = state.copyWith(recurAmt: nextAmt, recurSel: nextSel);
  }

  /// Ghi các khoản cố định vào tháng hiện tại (`commitRecur` trong HTML).
  void commitRecurring({bool all = false}) {
    final ym = state.activeMonth;
    if (state.recurDone[ym] == true) return;
    final suggestions = state.activeRecurringSuggestions;
    final selectedIndices = <int>[];
    for (var i = 0; i < suggestions.length; i++) {
      if (all || (i < state.recurSel.length && state.recurSel[i])) {
        selectedIndices.add(i);
      }
    }
    if (selectedIndices.isEmpty) return;

    final undo = state.toUndoSnapshot();
    var seq = state.nextSeq;
    final newItems = <ExpenseItem>[];
    final newIds = <String>{};
    var totalAdded = 0;

    for (final idx in selectedIndices) {
      final s = suggestions[idx];
      final amt = idx < state.recurAmt.length
          ? state.recurAmt[idx]
          : s.suggestedAmount;
      final id = '${seq++}';
      newIds.add(id);
      totalAdded += amt;
      final dm = FinanceMonthUtils.shortDayMonth(s.spentOnForMonth);
      newItems.add(
        ExpenseItem(
          id: id,
          spentOn: s.spentOnForMonth,
          month: ym,
          groupId: s.groupId,
          groupName: s.groupName,
          groupColor: s.groupColor,
          title: s.titleForMonth,
          amount: amt,
          accountId: s.accountId ?? 'acc_bank',
          accountName: s.accountName ?? 'TK ngân hàng',
          status: ExpenseStatus.paid,
          paidAmount: amt,
          outstanding: 0,
          createdAt: '$dm 08:30',
          payments: [
            ExpensePayment(
              id: 'p_$id',
              paidOn: s.spentOnForMonth,
              amount: amt,
              accountId: s.accountId ?? 'acc_bank',
              accountName: s.accountName ?? 'TK ngân hàng',
            ),
          ],
        ),
      );
    }

    final updatedMonthList = <ExpenseItem>[
      ...newItems,
      ...state.activeMonthItems,
    ];
    final updatedItemsByMonth = Map<String, List<ExpenseItem>>.from(
      state.itemsByMonth,
    )..[ym] = updatedMonthList;
    final updatedRecurDone = Map<String, bool>.from(state.recurDone)
      ..[ym] = true;

    state = state.copyWith(
      itemsByMonth: updatedItemsByMonth,
      recurDone: updatedRecurDone,
      recurOpen: false,
      nextSeq: seq,
    );
    _flashRows(newIds);
    showToast(
      'Đã ghi ${newItems.length} khoản cố định · ${FinanceMonthUtils.formatVndSpace(totalAdded)}',
      undoSnapshot: undo,
    );
  }

  /// Thêm một khoản chi mới (`saveAdd` trong HTML).
  ExpenseItem addExpense({
    required String title,
    required int amount,
    required String groupId,
    required String spentOn,
    required bool isPaid,
    required String accountName,
    String? createdAt,
    List<ExpenseAttachment> attachments = const [],
  }) {
    final undo = state.toUndoSnapshot();
    final ym = state.activeMonth;
    final isoDate = FinanceMonthUtils.toIsoDate(spentOn, ym);
    final grp = state.groupById(groupId);
    final id = '${state.nextSeq}';
    final accId = _accountIdForName(accountName);
    final cleanTitle = title.trim().isNotEmpty ? title.trim() : grp.name;
    final dm = FinanceMonthUtils.shortDayMonth(isoDate);

    final item = ExpenseItem(
      id: id,
      spentOn: isoDate,
      month: ym,
      groupId: grp.id,
      groupName: grp.name,
      groupColor: grp.color,
      countsAsExpense: grp.countsAsExpense,
      title: cleanTitle,
      amount: amount,
      accountId: accId,
      accountName: accountName,
      status: isPaid ? ExpenseStatus.paid : ExpenseStatus.unpaid,
      paidAmount: isPaid ? amount : 0,
      outstanding: isPaid ? 0 : amount,
      createdAt: createdAt ?? '$dm 10:30',
      payments: isPaid
          ? [
              ExpensePayment(
                id: 'p_$id',
                paidOn: isoDate,
                amount: amount,
                accountId: accId,
                accountName: accountName,
              ),
            ]
          : const [],
      attachments: attachments,
    );

    final updatedList = <ExpenseItem>[item, ...state.activeMonthItems];
    final updatedMap = Map<String, List<ExpenseItem>>.from(state.itemsByMonth)
      ..[ym] = updatedList;

    state = state.copyWith(
      itemsByMonth: updatedMap,
      nextSeq: state.nextSeq + 1,
      fltStatus: () => null,
      fltGroup: () => null,
    );
    _flashRows({id});
    showToast(
      'Đã thêm "$cleanTitle" · ${FinanceMonthUtils.formatVndSpace(amount)}',
      undoSnapshot: undo,
    );

    unawaited(
      ref
          .read(financeApiProvider)
          .createExpense(
            spentOn: isoDate,
            groupId: grp.id,
            title: cleanTitle,
            amount: amount,
            status: item.status,
            paidAmount: isPaid ? amount : null,
            accountId: accId,
          )
          .then<void>((_) {})
          .catchError((_) {}),
    );

    return item;
  }

  /// Đính kèm thêm một chứng từ / tệp vào khoản chi.
  void addAttachmentToExpense(String itemId, ExpenseAttachment attachment) {
    final found = _locateItem(itemId);
    if (found == null) return;
    final undo = state.toUndoSnapshot();
    final updatedItem = found.item.copyWith(
      attachments: [...found.item.attachments, attachment],
    );
    _replaceItemInMonth(found.month, updatedItem);
    showToast('Đã đính kèm "${attachment.name}"', undoSnapshot: undo);
  }

  /// Xoá một chứng từ đính kèm khỏi khoản chi.
  void removeAttachmentFromExpense(String itemId, String attachmentId) {
    final found = _locateItem(itemId);
    if (found == null) return;
    final undo = state.toUndoSnapshot();
    final updatedItem = found.item.copyWith(
      attachments: [
        for (final a in found.item.attachments)
          if (a.id != attachmentId) a,
      ],
    );
    _replaceItemInMonth(found.month, updatedItem);
    showToast('Đã gỡ chứng từ đính kèm', undoSnapshot: undo);
  }

  /// Trả đủ ngay lập tức (`quickPayFull` trong HTML).
  void markPaidFull(String itemId, {String? accountName}) {
    final found = _locateItem(itemId);
    if (found == null) return;
    final item = found.item;
    final left = item.remainingAmount;
    if (left <= 0) return;

    final undo = state.toUndoSnapshot();
    final payAccName =
        accountName ?? item.effectiveAccountName ?? 'TK ngân hàng';
    final payAccId = _accountIdForName(payAccName);
    final paidOn = FinanceMonthUtils.defaultSpentOnForMonth(found.month);

    final updatedPayments = <ExpensePayment>[
      ...item.payments,
      ExpensePayment(
        id: 'p_${item.id}_${item.payments.length + 1}',
        paidOn: paidOn,
        amount: left,
        accountId: payAccId,
        accountName: payAccName,
      ),
    ];
    final updatedItem = item.copyWith(
      status: ExpenseStatus.paid,
      paidAmount: item.amount,
      outstanding: 0,
      accountId: payAccId,
      accountName: payAccName,
      payments: updatedPayments,
    );

    _replaceItemInMonth(found.month, updatedItem);
    _flashRows({item.id});
    showToast(
      'Đã trả đủ · ${FinanceMonthUtils.formatVndSpace(left)} ($payAccName)',
      undoSnapshot: undo,
    );
  }

  /// Ghi nhận một lần thanh toán bất kỳ (trả 1 phần hoặc trả hết qua bàn phím).
  void recordPayment(
    String itemId, {
    required int amount,
    String? accountName,
  }) {
    final found = _locateItem(itemId);
    if (found == null || amount <= 0) return;
    final item = found.item;
    final left = item.remainingAmount;
    if (left <= 0) return;

    final undo = state.toUndoSnapshot();
    final add = math.min(amount, left);
    final payAccName =
        accountName ?? item.effectiveAccountName ?? 'TK ngân hàng';
    final payAccId = _accountIdForName(payAccName);
    final paidOn = FinanceMonthUtils.defaultSpentOnForMonth(found.month);

    final updatedPayments = <ExpensePayment>[
      ...item.payments,
      ExpensePayment(
        id: 'p_${item.id}_${item.payments.length + 1}',
        paidOn: paidOn,
        amount: add,
        accountId: payAccId,
        accountName: payAccName,
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
      accountId: payAccId,
      accountName: payAccName,
      payments: updatedPayments,
    );

    _replaceItemInMonth(found.month, updatedItem);
    _flashRows({item.id});
    showToast(
      newLeft <= 0
          ? 'Đã trả đủ · ${FinanceMonthUtils.formatVndSpace(add)} ($payAccName)'
          : 'Đã ghi trả ${FinanceMonthUtils.formatVndSpace(add)} · còn ${FinanceMonthUtils.formatVndSpace(newLeft)}',
      undoSnapshot: undo,
    );
  }

  /// Đổi số tiền của khoản chi (`editDetailAmt` trong HTML).
  void updateExpenseAmount(String itemId, int newAmount) {
    final found = _locateItem(itemId);
    if (found == null || newAmount <= 0 || newAmount == found.item.amount) {
      return;
    }
    final item = found.item;
    final undo = state.toUndoSnapshot();

    List<ExpensePayment> nextPayments = item.payments;
    if (item.payments.length == 1 && item.remainingAmount == 0) {
      nextPayments = [item.payments.first.copyWith(amount: newAmount)];
    }
    final newPaid = nextPayments.fold<int>(0, (s, p) => s + p.amount);
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

    _replaceItemInMonth(found.month, updatedItem);
    _flashRows({item.id});
    showToast(
      'Đã cập nhật số tiền · ${FinanceMonthUtils.formatVndSpace(newAmount)}',
      undoSnapshot: undo,
    );
  }

  /// Đổi tiêu đề khoản chi (`saveTitle` trong HTML).
  void updateExpenseTitle(String itemId, String newTitle) {
    final trimmed = newTitle.trim();
    if (trimmed.isEmpty) return;
    final found = _locateItem(itemId);
    if (found == null || found.item.title == trimmed) return;

    final updatedItem = found.item.copyWith(title: trimmed);
    _replaceItemInMonth(found.month, updatedItem);
    showToast('Đã đổi tên khoản chi');
  }

  /// Đổi nhóm chi phí (`openDetailGroupMenu` trong HTML).
  void updateExpenseGroup(String itemId, String newGroupId) {
    final found = _locateItem(itemId);
    if (found == null || found.item.groupId == newGroupId) return;

    final undo = state.toUndoSnapshot();
    final grp = state.groupById(newGroupId);
    final updatedItem = found.item.copyWith(
      groupId: grp.id,
      groupName: grp.name,
      groupColor: grp.color,
      countsAsExpense: grp.countsAsExpense,
    );
    _replaceItemInMonth(found.month, updatedItem);
    showToast('Đã chuyển sang nhóm "${grp.name}"', undoSnapshot: undo);
  }

  /// Đổi ngày ghi nhận (`openDetailDateMenu` trong HTML).
  void updateExpenseDate(String itemId, String newIsoDate) {
    final found = _locateItem(itemId);
    if (found == null) return;
    final normalized = FinanceMonthUtils.toIsoDate(newIsoDate, found.month);
    if (found.item.spentOn == normalized) return;

    final undo = state.toUndoSnapshot();
    var nextPayments = found.item.payments;
    if (nextPayments.length == 1) {
      nextPayments = [nextPayments.first.copyWith(paidOn: normalized)];
    }
    final updatedItem = found.item.copyWith(
      spentOn: normalized,
      payments: nextPayments,
    );
    _replaceItemInMonth(found.month, updatedItem);
    showToast(
      'Đã đổi ngày ghi nhận · ${FinanceMonthUtils.fullDayMonthYear(normalized, fallbackMonth: found.month)}',
      undoSnapshot: undo,
    );
  }

  /// Đổi nguồn tiền (`openDetailAccMenu` trong HTML).
  void updateExpenseAccount(String itemId, String newAccountName) {
    final found = _locateItem(itemId);
    if (found == null) return;
    final accId = _accountIdForName(newAccountName);
    final undo = state.toUndoSnapshot();

    var nextPayments = found.item.payments;
    if (nextPayments.isNotEmpty) {
      nextPayments = [
        for (var i = 0; i < nextPayments.length; i++)
          if (i == nextPayments.length - 1)
            nextPayments[i].copyWith(
              accountId: accId,
              accountName: newAccountName,
            )
          else
            nextPayments[i],
      ];
    }

    final updatedItem = found.item.copyWith(
      accountId: accId,
      accountName: newAccountName,
      payments: nextPayments,
    );
    _replaceItemInMonth(found.month, updatedItem);
    showToast('Đã đổi nguồn tiền · $newAccountName', undoSnapshot: undo);
  }

  /// Sao chép khoản chi sang tháng kế tiếp hoặc về `11/2026` (`dupItemById` trong HTML).
  void duplicateToNextMonth(String itemId) {
    final found = _locateItem(itemId);
    if (found == null) return;
    final item = found.item;
    final undo = state.toUndoSnapshot();

    final targetMonth = state.activeMonth == '2026-11'
        ? '2026-11'
        : FinanceMonthUtils.shiftMonth(state.activeMonth, 1);
    final targetBucketMonth = state.itemsByMonth.containsKey(targetMonth)
        ? targetMonth
        : '2026-11';
    final dayPart = FinanceMonthUtils.shortDayMonth(
      item.spentOn,
    ).split('/').first;
    final targetSpentOn = '$targetBucketMonth-${dayPart.padLeft(2, '0')}';
    final newId = '${state.nextSeq}';

    final adaptedTitle = FinanceMonthUtils.adaptTitleToMonth(
      item.title,
      fromMonth: found.month,
      toMonth: targetBucketMonth,
    );
    final dm = FinanceMonthUtils.shortDayMonth(targetSpentOn);

    final copy = ExpenseItem(
      id: newId,
      spentOn: targetSpentOn,
      month: targetBucketMonth,
      groupId: item.groupId,
      groupName: item.resolvedGroupName,
      groupColor:
          item.groupColor ?? FinanceSeedCatalog.colorForGroupId(item.groupId),
      countsAsExpense: item.countsAsExpense,
      title: adaptedTitle,
      amount: item.amount,
      accountId: item.accountId ?? 'acc_bank',
      accountName: item.effectiveAccountName ?? 'TK ngân hàng',
      status: ExpenseStatus.unpaid,
      paidAmount: 0,
      outstanding: item.amount,
      createdAt: '$dm 09:00',
      payments: const [],
      attachments: item.attachments,
    );

    final bucket = <ExpenseItem>[
      copy,
      ...(state.itemsByMonth[targetBucketMonth] ?? const <ExpenseItem>[]),
    ];
    final updatedMap = Map<String, List<ExpenseItem>>.from(state.itemsByMonth)
      ..[targetBucketMonth] = bucket;

    state = state.copyWith(
      itemsByMonth: updatedMap,
      nextSeq: state.nextSeq + 1,
    );
    if (targetBucketMonth == state.activeMonth) {
      _flashRows({newId});
    }
    showToast('Đã sao chép "${item.title}" (Chưa trả)', undoSnapshot: undo);
  }

  /// Xoá khoản chi (`delItemById` trong HTML).
  void deleteExpense(String itemId) {
    final found = _locateItem(itemId);
    if (found == null) return;
    final undo = state.toUndoSnapshot();

    final list = [
      for (final e in state.itemsByMonth[found.month] ?? const <ExpenseItem>[])
        if (e.id != itemId) e,
    ];
    final updatedMap = Map<String, List<ExpenseItem>>.from(state.itemsByMonth)
      ..[found.month] = list;

    state = state.copyWith(itemsByMonth: updatedMap);
    showToast('Đã xoá "${found.item.title}"', undoSnapshot: undo);

    unawaited(
      ref
          .read(financeApiProvider)
          .deleteExpense(itemId)
          .then<void>((_) {})
          .catchError((_) {}),
    );
  }

  /// Thực thi Hoàn tác (`undoBtn` trong HTML).
  void undo() {
    final snapshot = state.toast?.undoSnapshot;
    if (snapshot == null) return;
    _toastTimer?.cancel();
    state = state.copyWith(
      itemsByMonth: {
        for (final entry in snapshot.itemsByMonth.entries)
          entry.key: List<ExpenseItem>.from(entry.value),
      },
      recurDone: Map<String, bool>.from(snapshot.recurDone),
      recurOpen: snapshot.recurOpen,
      recurSel: List<bool>.from(snapshot.recurSel),
      recurAmt: List<int>.from(snapshot.recurAmt),
      toast: () => null,
    );
    showToast('Đã hoàn tác thao tác');
  }

  /// Ẩn toast hiện tại.
  void dismissToast() {
    _toastTimer?.cancel();
    state = state.copyWith(toast: () => null);
  }

  /// Hiển thị toast ở đáy màn hình trong 4.2 giây.
  void showToast(String text, {FinanceUndoSnapshot? undoSnapshot}) {
    _toastTimer?.cancel();
    final msg = FinanceToastMessage(
      id: ++_toastCounter,
      text: text,
      undoSnapshot: undoSnapshot,
    );
    state = state.copyWith(toast: () => msg);
    _toastTimer = Timer(const Duration(milliseconds: 4200), () {
      if (state.toast?.id == msg.id) {
        state = state.copyWith(toast: () => null);
      }
    });
  }

  void _flashRows(Set<String> ids) {
    _flashTimer?.cancel();
    state = state.copyWith(flashedIds: ids);
    _flashTimer = Timer(const Duration(milliseconds: 1400), () {
      state = state.copyWith(flashedIds: const <String>{});
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

  void _replaceItemInMonth(String month, ExpenseItem updated) {
    final list = state.itemsByMonth[month];
    if (list == null) return;
    final nextList = [
      for (final item in list)
        if (item.id == updated.id) updated else item,
    ];
    final nextMap = Map<String, List<ExpenseItem>>.from(state.itemsByMonth)
      ..[month] = nextList;
    state = state.copyWith(itemsByMonth: nextMap);
  }

  String _accountIdForName(String accountName) {
    for (final a in state.accounts) {
      if (a.name.toLowerCase() == accountName.trim().toLowerCase()) {
        return a.id;
      }
    }
    if (accountName.contains('Tiền mặt')) return 'acc_cash';
    if (accountName.contains('Ví')) return 'acc_wallet';
    return 'acc_bank';
  }
}
