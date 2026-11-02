import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../application/finance_providers.dart';
import '../domain/finance_models.dart';
import 'widgets/expense_add_sheet.dart';
import 'widgets/expense_keypad_sheet.dart';
import 'widgets/expense_row_tile.dart';
import 'widgets/finance_palette.dart';

/// Màn hình gốc **Sổ chi phí** (`lib/modules/finance/presentation/expenses_page.dart`),
/// khớp 100% thiết kế và tương tác của `so-chi-phi-mobile.html` cùng các nâng cấp:
/// - 5 khoản cố định hàng tháng (Chi phí kho, Điện nước, Lương nhân sự, Lãi vay, Lương kế toán dịch vụ)
/// - Tìm kiếm theo số tiền (`450k`, `2.45tr`, `2.450.000`), ngày, loại, chứng từ
/// - Sắp xếp đa chiều chuẩn iOS (`Ngày ghi nhận`, `Thời gian nhập`, `Ngày thanh toán`, `Loại chi phí`, `Số tiền`)
/// - Đính kèm chứng từ / phiếu chi
class ExpensesPage extends ConsumerStatefulWidget {
  const ExpensesPage({super.key});

  @override
  ConsumerState<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends ConsumerState<ExpensesPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final GlobalKey _segMoreKey = GlobalKey();
  final GlobalKey _sortBtnKey = GlobalKey();

  @override
  void dispose() {
    _searchFocus.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openMonthPickerMenu() async {
    final state = ref.read(financeLedgerProvider);
    final months = FinanceSeedCatalog.allMonths.reversed.toList();
    final picked = await showFinancePopoverMenu<String>(
      context: context,
      anchorContext: _segMoreKey.currentContext,
      header: 'Chọn kỳ sổ chi phí',
      width: 248,
      items: [
        for (final ym in months)
          FinancePopoverItem<String>(
            value: ym,
            label: FinanceMonthUtils.formatMonthFull(ym),
            subtitle:
                '${state.statsForMonth(ym).count} khoản · ${FinanceMonthUtils.formatVndSpace(state.statsForMonth(ym).total)}',
            stackSubtitle: true,
            selected: ym == state.activeMonth,
          ),
      ],
    );
    if (picked != null && mounted) {
      ref.read(financeLedgerProvider.notifier).selectMonth(picked);
    }
  }

  Future<void> _openSortMenu() async {
    final state = ref.read(financeLedgerProvider);
    final picked = await showFinancePopoverMenu<ExpenseSortMode>(
      context: context,
      anchorContext: _sortBtnKey.currentContext,
      header: 'Sắp xếp danh sách',
      width: 256,
      items: [
        for (final mode in ExpenseSortMode.values)
          FinancePopoverItem<ExpenseSortMode>(
            value: mode,
            label: mode.label,
            selected: mode == state.sortMode,
          ),
      ],
    );
    if (picked != null && mounted) {
      ref.read(financeLedgerProvider.notifier).setSortMode(picked);
    }
  }

  Future<void> _openRecurringAmountKeypad(
    int index,
    RecurringExpenseSuggestion suggestion,
    int currentAmount,
  ) async {
    final chips = FinanceSeedCatalog.buildHistoryChips(suggestion.history);
    final res = await showExpenseKeypadSheet(
      context: context,
      title: suggestion.titleForMonth,
      initialAmount: currentAmount,
      chips: chips,
    );
    if (res != null && res.amount > 0 && mounted) {
      ref
          .read(financeLedgerProvider.notifier)
          .updateRecurringAmount(index, res.amount);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(financeLedgerProvider);
    final notifier = ref.read(financeLedgerProvider.notifier);
    final p = FinancePalette.of(context);
    final sortActive = state.sortMode != ExpenseSortMode.spentDateDesc;

    if (_searchCtrl.text != state.searchQuery) {
      _searchCtrl.value = TextEditingValue(
        text: state.searchQuery,
        selection: TextSelection.collapsed(offset: state.searchQuery.length),
      );
    }

    return Scaffold(
      backgroundColor: p.bg,
      appBar: OmniAppBar(
        title: 'Sổ chi phí',
        backgroundColor: p.bg,
        actions: [
          // Search toggle button
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Tooltip(
              message: 'Tìm kiếm',
              child: InkWell(
                key: const ValueKey('finance-search-toggle'),
                onTap: () {
                  notifier.toggleSearch();
                  if (!state.searchOpen) {
                    Future.delayed(const Duration(milliseconds: 60), () {
                      if (mounted) _searchFocus.requestFocus();
                    });
                  }
                },
                borderRadius: BorderRadius.circular(99),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: state.searchOpen ? p.primarySoft : p.card,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: state.searchOpen ? p.selLine : p.line,
                      width: 0.5,
                    ),
                  ),
                  child: Icon(
                    Icons.search_rounded,
                    size: 17,
                    color: state.searchOpen ? p.primaryInk : p.ink,
                  ),
                ),
              ),
            ),
          ),
          // Sort popover button
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Tooltip(
              message: 'Sắp xếp chi phí',
              child: InkWell(
                key: _sortBtnKey,
                onTap: _openSortMenu,
                borderRadius: BorderRadius.circular(99),
                child: Container(
                  key: const ValueKey('finance-sort-btn'),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: sortActive ? p.primarySoft : p.card,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: sortActive ? p.selLine : p.line,
                      width: 0.5,
                    ),
                  ),
                  child: Icon(
                    Icons.swap_vert_rounded,
                    size: 17,
                    color: sortActive ? p.primaryInk : p.ink,
                  ),
                ),
              ),
            ),
          ),
          // Add expense '+' button
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Tooltip(
              message: 'Thêm khoản chi',
              child: InkWell(
                key: const ValueKey('finance-add-btn'),
                onTap: () => showExpenseAddSheet(context: context),
                borderRadius: BorderRadius.circular(99),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: p.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: p.primary.withValues(alpha: 0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                children: [
                  // Collapsible search bar + 3-month segmented control
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                    child: Column(
                      children: [
                        if (state.searchOpen)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              height: 36,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                              ),
                              decoration: BoxDecoration(
                                color: p.card,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: p.line, width: 0.5),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.search_rounded,
                                    size: 15,
                                    color: p.muted,
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: TextField(
                                      key: const ValueKey(
                                        'finance-search-input',
                                      ),
                                      controller: _searchCtrl,
                                      focusNode: _searchFocus,
                                      onChanged: notifier.setSearchQuery,
                                      style: OmniType.bodySm.copyWith(
                                        color: p.ink,
                                      ),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        hintText:
                                            'Tìm tên, số tiền (450k, 2.45tr), ngày, loại…',
                                        hintStyle: OmniType.bodySm.copyWith(
                                          color: p.muted,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: notifier.clearSearch,
                                    borderRadius: BorderRadius.circular(99),
                                    child: Container(
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        color: p.control,
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.close_rounded,
                                        size: 12,
                                        color: p.muted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        _buildMonthSegmentedRow(p, state, notifier),
                      ],
                    ),
                  ),
                  // Scrollable ledger content
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 100),
                      children: [
                        // TIER 1: Summary Card
                        _buildSummaryCard(p, state, notifier),
                        // TIER 2: Monthly Recurring Card (5 khoản cố định)
                        if (state.showRecurringCard)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: _buildRecurringCard(p, state, notifier),
                          ),
                        // Active Filter / Sort Banner
                        if (state.hasActiveFilter)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: _buildActiveFilterBanner(p, state, notifier),
                          ),
                        // TIER 3: Grouped Expense List
                        ..._buildGroupedSections(p, state),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Floating Undo Toast
          if (state.toast != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: _buildToastBanner(state.toast!, notifier),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMonthSegmentedRow(
    FinancePalette p,
    FinanceLedgerState state,
    FinanceLedgerNotifier notifier,
  ) {
    final defaultSeg = FinanceSeedCatalog.segMonths;
    final inDefaultSeg = defaultSeg.contains(state.activeMonth);
    final slots = inDefaultSeg
        ? defaultSeg
        : <String>[state.activeMonth, '2026-10', '2026-11'];

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 34,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: p.track,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              children: [
                for (final ym in slots)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => notifier.selectMonth(ym),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: ym == state.activeMonth
                              ? p.card
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(7),
                          boxShadow: ym == state.activeMonth
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          FinanceMonthUtils.formatMonthShort(ym),
                          style: OmniType.caption.copyWith(
                            color: ym == state.activeMonth ? p.ink : p.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        Tooltip(
          message: 'Chọn tháng khác',
          child: InkWell(
            key: _segMoreKey,
            onTap: _openMonthPickerMenu,
            borderRadius: BorderRadius.circular(9),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: !inDefaultSeg ? p.primarySoft : p.track,
                borderRadius: BorderRadius.circular(9),
                border: !inDefaultSeg
                    ? Border.all(color: p.selLine, width: 0.5)
                    : null,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.calendar_month_outlined,
                size: 16,
                color: !inDefaultSeg ? p.primaryInk : p.ink2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    FinancePalette p,
    FinanceLedgerState state,
    FinanceLedgerNotifier notifier,
  ) {
    final summary = state.activeSummary;
    final monthNum = FinanceMonthUtils.monthNumberOf(state.activeMonth);
    final delta = summary.deltaPill;
    final grpBtnActive = state.grpOpen || state.fltGroup != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 13),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.line, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // sum-top
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tổng chi tháng $monthNum',
                      style: OmniType.caption.copyWith(
                        color: p.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: Text(
                            FinanceMonthUtils.formatNumber(summary.total),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: OmniType.displayLg.copyWith(
                              color: p.ink,
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'đ',
                          style: OmniType.section.copyWith(
                            color: p.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (delta != null) ...[
                    Container(
                      height: 26,
                      padding: const EdgeInsets.symmetric(horizontal: 9),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: delta.isIncrease ? p.amberSoft : p.okSoft,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        delta.text,
                        style: OmniType.micro.copyWith(
                          color: delta.isIncrease ? p.amber : p.ok,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Tooltip(
                    message: 'Tỷ trọng theo nhóm',
                    child: InkWell(
                      key: const ValueKey('finance-grp-toggle'),
                      onTap: notifier.toggleGroupBreakdown,
                      borderRadius: BorderRadius.circular(99),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: grpBtnActive ? p.primarySoft : p.control,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.pie_chart_outline_rounded,
                          size: 15,
                          color: grpBtnActive ? p.primaryInk : p.ink2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // 6px progress bar
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: SizedBox(
                height: 6,
                child: LinearProgressIndicator(
                  value: summary.paidRatio,
                  backgroundColor: p.amberSoft,
                  valueColor: AlwaysStoppedAnimation<Color>(p.primary),
                ),
              ),
            ),
          ),
          // Paid / Owed interactive filter buttons (sum-sub)
          Row(
            children: [
              Expanded(
                child: _buildSummaryStatusPill(
                  p,
                  key: const ValueKey('finance-flt-paid'),
                  active: state.fltStatus == 'paid',
                  dotColor: p.ok,
                  label: 'Đã trả',
                  amountText: FinanceMonthUtils.formatVndSpace(summary.paid),
                  amountColor: p.ink,
                  onTap: () => notifier.toggleStatusFilter('paid'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildSummaryStatusPill(
                  p,
                  key: const ValueKey('finance-flt-owe'),
                  active: state.fltStatus == 'owe',
                  dotColor: summary.outstanding > 0 ? p.amber : p.ok,
                  label: 'Phải trả',
                  amountText: FinanceMonthUtils.formatVndSpace(
                    summary.outstanding,
                  ),
                  amountColor: summary.outstanding > 0 ? p.amber : p.ink2,
                  onTap: () => notifier.toggleStatusFilter('owe'),
                ),
              ),
            ],
          ),
          // Expandable group breakdown (grp-panel)
          if (state.grpOpen) ...[
            const SizedBox(height: 11),
            Container(
              padding: const EdgeInsets.only(top: 11),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: p.divider, width: 0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TỶ TRỌNG THEO NHÓM',
                          style: OmniType.overline.copyWith(
                            color: p.muted,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),
                        Text(
                          'Chạm nhóm để lọc',
                          style: OmniType.micro.copyWith(color: p.muted),
                        ),
                      ],
                    ),
                  ),
                  for (final g in summary.byGroup)
                    _buildGroupBreakdownRow(
                      p,
                      g,
                      total: summary.total,
                      selected: state.fltGroup == g.groupId,
                      onTap: () => notifier.toggleGroupFilter(g.groupId),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryStatusPill(
    FinancePalette p, {
    required Key key,
    required bool active,
    required Color dotColor,
    required String label,
    required String amountText,
    required Color amountColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: active ? p.primarySoft : p.control,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? p.selLine : Colors.transparent,
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: OmniType.caption.copyWith(
                color: p.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Flexible(
              child: Text(
                amountText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: OmniType.caption.copyWith(
                  color: amountColor,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupBreakdownRow(
    FinancePalette p,
    LedgerGroupTotal g, {
    required int total,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final pct = total > 0 ? (g.amount / total * 100).round() : 0;
    final ratio = total > 0 ? (g.amount / total).clamp(0.0, 1.0) : 0.0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        margin: const EdgeInsets.only(top: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? p.primarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: g.resolvedColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    g.resolvedName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: OmniType.caption.copyWith(
                      color: p.ink,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$pct%',
                  style: OmniType.micro.copyWith(
                    color: p.muted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  FinanceMonthUtils.formatVndSpace(g.amount),
                  style: OmniType.caption.copyWith(
                    color: p.ink,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: SizedBox(
                height: 4,
                child: LinearProgressIndicator(
                  value: ratio,
                  backgroundColor: p.track,
                  valueColor: AlwaysStoppedAnimation<Color>(g.resolvedColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecurringCard(
    FinancePalette p,
    FinanceLedgerState state,
    FinanceLedgerNotifier notifier,
  ) {
    final suggestions = state.activeRecurringSuggestions;
    final monthNum = FinanceMonthUtils.monthNumberOf(state.activeMonth);
    final selectedCount = state.selectedRecurringCount;
    final selectedSum = state.selectedRecurringSum;

    return Container(
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.line, width: 0.5),
      ),
      child: Column(
        children: [
          // Header: rc-head
          InkWell(
            key: const ValueKey('finance-recur-head'),
            onTap: notifier.toggleRecurringExpanded,
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(14),
              bottom: Radius.circular(state.recurOpen ? 0 : 14),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  // Overlapping category color dots
                  SizedBox(
                    width: 34,
                    height: 12,
                    child: Stack(
                      children: [
                        for (
                          var i = 0;
                          i < suggestions.length && i < 4;
                          i++
                        )
                          Positioned(
                            left: i * 6.5,
                            top: 0.5,
                            child: Container(
                              width: 11,
                              height: 11,
                              decoration: BoxDecoration(
                                color: suggestions[i].resolvedColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: p.card, width: 1.5),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Khoản cố định tháng $monthNum',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: OmniType.bodySm.copyWith(
                            color: p.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '${suggestions.length} khoản · ${FinanceMonthUtils.formatVndSpace(state.allRecurringSum)}',
                          style: OmniType.caption.copyWith(
                            color: p.muted,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // "Ghi tất cả" pill button
                  InkWell(
                    key: const ValueKey('finance-recur-commit-all'),
                    onTap: () => notifier.commitRecurring(all: true),
                    borderRadius: BorderRadius.circular(99),
                    child: Container(
                      height: 30,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: p.card,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: p.primary, width: 1.25),
                      ),
                      child: Text(
                        'Ghi tất cả',
                        style: OmniType.caption.copyWith(
                          color: p.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: state.recurOpen ? 0.25 : 0.0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: p.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Expanded checklist: rc-body
          if (state.recurOpen)
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: p.divider, width: 0.5),
                ),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < suggestions.length; i++)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        border: i == suggestions.length - 1
                            ? null
                            : Border(
                                bottom: BorderSide(
                                  color: p.divider,
                                  width: 0.5,
                                ),
                              ),
                      ),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () => notifier.toggleRecurringItem(i),
                            borderRadius: BorderRadius.circular(99),
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: state.recurSel[i]
                                    ? p.primary
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: state.recurSel[i]
                                      ? p.primary
                                      : p.muted.withValues(alpha: 0.5),
                                  width: 1.6,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: state.recurSel[i]
                                  ? const Icon(
                                      Icons.check_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () => notifier.toggleRecurringItem(i),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: suggestions[i].resolvedColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      suggestions[i].titleForMonth,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: OmniType.bodySm.copyWith(
                                        color: p.ink,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => _openRecurringAmountKeypad(
                              i,
                              suggestions[i],
                              state.recurAmt[i],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              height: 30,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              decoration: BoxDecoration(
                                color: p.control,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: p.line, width: 0.5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    FinanceMonthUtils.formatVndSpace(
                                      state.recurAmt[i],
                                    ),
                                    style: OmniType.bodySm.copyWith(
                                      color: p.ink,
                                      fontWeight: FontWeight.w600,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.edit_outlined,
                                    size: 12,
                                    color: p.muted,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: FilledButton(
                        onPressed: selectedCount > 0
                            ? () => notifier.commitRecurring()
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: p.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          selectedCount > 0
                              ? 'Ghi $selectedCount khoản · ${FinanceMonthUtils.formatVndSpace(selectedSum)}'
                              : 'Chọn ít nhất 1 khoản',
                          style: OmniType.bodySm.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveFilterBanner(
    FinancePalette p,
    FinanceLedgerState state,
    FinanceLedgerNotifier notifier,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: p.primarySoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.selLine, width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              'Đang lọc: ${state.activeFilterDescription}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: OmniType.caption.copyWith(
                color: p.primaryInk,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            key: const ValueKey('finance-clear-filter'),
            onTap: notifier.clearFilters,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                '× Bỏ lọc',
                style: OmniType.caption.copyWith(
                  color: p.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedSections(
    FinancePalette p,
    FinanceLedgerState state,
  ) {
    final sections = state.groupedSections;
    if (sections.isEmpty) {
      return [
        Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.line, width: 0.5),
          ),
          alignment: Alignment.center,
          child: Text(
            'Không có khoản chi phù hợp bộ lọc.',
            style: OmniType.bodySm.copyWith(color: p.muted),
          ),
        ),
      ];
    }

    return [
      for (final section in sections) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    if (section.dotColor != null) ...[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: section.dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        section.headerLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: OmniType.caption.copyWith(
                          color: p.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                FinanceMonthUtils.formatVndSpace(section.totalAmount),
                style: OmniType.caption.copyWith(
                  color: p.muted,
                  fontWeight: FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.line, width: 0.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < section.items.length; i++)
                ExpenseRowTile(
                  key: ValueKey('expense-row-${section.items[i].id}'),
                  item: section.items[i],
                  showBottomDivider: i < section.items.length - 1,
                  isFlashed: state.flashedIds.contains(section.items[i].id),
                ),
            ],
          ),
        ),
      ],
    ];
  }

  Widget _buildToastBanner(
    FinanceToastMessage toast,
    FinanceLedgerNotifier notifier,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xF50F172A),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              toast.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: OmniType.bodySm.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (toast.canUndo) ...[
            const SizedBox(width: 12),
            InkWell(
              key: const ValueKey('finance-undo-btn'),
              onTap: notifier.undo,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  'Hoàn tác',
                  style: OmniType.bodySm.copyWith(
                    color: const Color(0xFF5EEAD4),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
