// Notifier Sổ chi phí (gọi API, hàng chờ, thông báo). Trạng thái và các phép
// suy nằm ở `finance_ledger_state.dart`, export lại ở đây để chỗ gọi cũ không
// đổi import (rà soát kiến trúc 27/11/2026).
export 'finance_ledger_state.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/network/active_tenant.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/text_search.dart';
import '../data/finance_api.dart';
import '../domain/finance_models.dart';
import 'finance_ledger_state.dart';

/// Đồng hồ nghiệp vụ cho Sổ chi phí (`null` = giờ thực tế, có thể override trong test).
final financeClockProvider = Provider<DateTime?>((ref) => null);

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
    // Bắt buộc watch `activeTenantIdProvider` + `financeApiProvider` để khi đổi
    // workspace/tenant hoặc logout, provider tự huỷ bộ nhớ đệm cũ.
    ref.watch(activeTenantIdProvider);
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

    final monthList = toFetch.toList();
    final results = <MonthLedger?>[];
    const batchSize = 3;
    for (var i = 0; i < monthList.length; i += batchSize) {
      if (_disposed) return;
      final end = math.min(i + batchSize, monthList.length);
      final batch = monthList.sublist(i, end);
      final batchResults = await Future.wait<MonthLedger?>([
        for (final m in batch)
          _api
              .fetchMonthLedger(month: m)
              .then<MonthLedger?>((v) => v)
              .catchError((_) => null),
      ]);
      results.addAll(batchResults);
    }
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
