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
/// đồng bộ dữ liệu trực tiếp với API `/api/v1/finance/*` và Web:
/// - 5 khoản cố định hàng tháng (Chi phí kho, Điện nước, Lương nhân sự, Lãi vay, Lương kế toán dịch vụ)
/// - Tìm kiếm theo số tiền (`450k`, `2.45tr`, `2.450.000`), ngày, loại, chứng từ
/// - Sắp xếp đa chiều chuẩn iOS (`Ngày ghi nhận`, `Thời gian nhập`, `Ngày thanh toán`, `Loại chi phí`, `Số tiền`)
/// - Đính kèm chứng từ / phiếu chi thật lên máy chủ
/// - Hiển thị toàn bộ số tiền rõ ràng, tự co giãn thông minh (`FittedBox`), tuyệt đối không cắt `...`
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
    final months = FinanceMonthUtils.pickerMonths(
      activeMonth: state.activeMonth,
      clock: state.clock,
    );
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
            subtitle: state.statsForMonth(ym).loaded
                ? '${state.statsForMonth(ym).count} khoản · ${FinanceMonthUtils.formatVndSpace(state.statsForMonth(ym).total)}'
                : 'Chạm để tải dữ liệu',
            stackSubtitle: true,
            selected: ym == state.activeMonth,
          ),
      ],
    );
    if (picked != null && mounted) {
      await ref.read(financeLedgerProvider.notifier).selectMonth(picked);
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
    final activeLoaded = state.isMonthLoaded(state.activeMonth);

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
              message: 'Sắp xếp danh sách',
              child: InkWell(
                key: const ValueKey('finance-sort-btn'),
                onTap: _openSortMenu,
                borderRadius: BorderRadius.circular(99),
                child: Container(
                  key: _sortBtnKey,
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
          // Primary Add button (+)
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
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
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
                    child: RefreshIndicator(
                      onRefresh: notifier.refresh,
                      color: p.primary,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 2, 16, 100),
                        children: [
                          if (state.isLoading && !activeLoaded)
                            _buildLoadingCard(p, state)
                          else if (state.errorMessage != null && !activeLoaded)
                            _buildErrorCard(p, state.errorMessage!, notifier)
                          else ...[
                            if (state.errorMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _buildInlineErrorBanner(
                                  p,
                                  state.errorMessage!,
                                  notifier,
                                ),
                              ),
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
                                child: _buildActiveFilterBanner(
                                  p,
                                  state,
                                  notifier,
                                ),
                              ),
                            // TIER 3: Grouped Expense List
                            ..._buildGroupedSections(p, state),
                          ],
                        ],
                      ),
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

  Widget _buildLoadingCard(FinancePalette p, FinanceLedgerState state) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 36),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.line, width: 0.5),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation<Color>(p.primary),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Đang tải sổ chi phí ${FinanceMonthUtils.formatMonthFull(state.activeMonth)}…',
            textAlign: TextAlign.center,
            style: OmniType.bodySm.copyWith(color: p.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(
    FinancePalette p,
    String message,
    FinanceLedgerNotifier notifier,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.line, width: 0.5),
      ),
      child: Column(
        children: [
          Icon(Icons.cloud_off_rounded, size: 32, color: p.danger),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: OmniType.bodySm.copyWith(color: p.ink),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 36,
            child: FilledButton.icon(
              onPressed: notifier.refresh,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Thử lại'),
              style: FilledButton.styleFrom(
                backgroundColor: p.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineErrorBanner(
    FinancePalette p,
    String message,
    FinanceLedgerNotifier notifier,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: p.dangerSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 16, color: p.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: OmniType.caption.copyWith(color: p.danger),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: notifier.refresh,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              child: Text(
                'Thử lại',
                style: OmniType.caption.copyWith(
                  color: p.danger,
                  fontWeight: FontWeight.w600,
                ),
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
    final defaultSeg = FinanceMonthUtils.recentThreeMonths(state.clock);
    final inDefaultSeg = defaultSeg.contains(state.activeMonth);
    final slots = inDefaultSeg
        ? defaultSeg
        : <String>[state.activeMonth, defaultSeg[1], defaultSeg[2]];

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
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              FinanceMonthUtils.formatMonthShort(ym),
                              maxLines: 1,
                              style: OmniType.caption.copyWith(
                                color: ym == state.activeMonth
                                    ? p.ink
                                    : p.muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 12),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.line, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hàng 1: Nhãn "Tổng chi tháng X" bên trái + Pill biến động & nút biểu đồ tròn bên phải
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tổng chi tháng $monthNum',
                  maxLines: 1,
                  style: OmniType.caption.copyWith(
                    color: p.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (delta != null) ...[
                Container(
                  height: 24,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
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
          const SizedBox(height: 2),
          // Hàng 2: Số tiền tổng chi chiếm trọn chiều ngang card, tự co giãn vừa khít, không bao giờ cắt "..."
          Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    FinanceMonthUtils.formatNumber(summary.total),
                    maxLines: 1,
                    style: OmniType.displayLg.copyWith(
                      color: p.ink,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
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
            ),
          ),
          // Thanh tiến độ 6px
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 9),
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
          // Hai ô lọc Đã trả / Phải trả: bố cục 2 dòng gọn gàng để số tiền luôn hiển thị trọn vẹn 100%
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
              const SizedBox(width: 8),
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
          if (summary.excluded.count > 0 && summary.excluded.total != 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'Ngoài chi phí: ${FinanceMonthUtils.formatVndSpace(summary.excluded.total)} (${summary.excluded.count} khoản không tính CP)',
                  maxLines: 1,
                  style: OmniType.micro.copyWith(
                    color: p.muted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          // Expandable group breakdown (grp-panel)
          if (state.grpOpen) ...[
            const SizedBox(height: 11),
            Container(
              padding: const EdgeInsets.only(top: 11),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: p.divider, width: 0.5)),
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
                  if (summary.byGroup.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Chưa có phát sinh theo nhóm trong kỳ này.',
                        style: OmniType.caption.copyWith(color: p.muted),
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
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: active ? p.primarySoft : p.control,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? p.selLine : Colors.transparent,
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: OmniType.micro.copyWith(
                        color: p.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                amountText,
                maxLines: 1,
                style: OmniType.bodySm.copyWith(
                  color: amountColor,
                  fontWeight: FontWeight.w700,
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
    final isExcluded = !g.countsAsExpense;
    final pct = (!isExcluded && total > 0 && g.amount > 0)
        ? (g.amount / total * 100).round()
        : 0;
    final ratio = (!isExcluded && total > 0 && g.amount > 0)
        ? (g.amount / total).clamp(0.0, 1.0)
        : 0.0;

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
                  isExcluded ? 'Không tính CP' : '$pct%',
                  style: OmniType.micro.copyWith(
                    color: p.muted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    FinanceMonthUtils.formatVndSpace(g.amount),
                    maxLines: 1,
                    style: OmniType.caption.copyWith(
                      color: p.ink,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
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
    final allSum = state.allRecurringSum;

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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  // Overlapping category color dots
                  SizedBox(
                    width: 30,
                    height: 11,
                    child: Stack(
                      children: [
                        for (var i = 0; i < suggestions.length && i < 4; i++)
                          Positioned(
                            left: i * 6.0,
                            top: 0.5,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: suggestions[i].resolvedColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: p.card, width: 1.4),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Khoản cố định tháng $monthNum',
                            maxLines: 1,
                            style: OmniType.bodySm.copyWith(
                              color: p.ink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 1),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            allSum > 0
                                ? '${suggestions.length} khoản · ${FinanceMonthUtils.formatVndSpace(allSum)}'
                                : '${suggestions.length} khoản gợi ý · Chạm để nhập số tiền',
                            maxLines: 1,
                            style: OmniType.caption.copyWith(
                              color: p.muted,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  // "Ghi tất cả" pill button (hoặc mở danh sách nếu chưa có số tiền lịch sử)
                  InkWell(
                    key: const ValueKey('finance-recur-commit-all'),
                    onTap: allSum > 0
                        ? () => notifier.commitRecurring(all: true)
                        : notifier.toggleRecurringExpanded,
                    borderRadius: BorderRadius.circular(99),
                    child: Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: p.card,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: p.primary, width: 1.2),
                      ),
                      child: Text(
                        allSum > 0 ? 'Ghi tất cả' : 'Mở nhập',
                        style: OmniType.caption.copyWith(
                          color: p.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  AnimatedRotation(
                    turns: state.recurOpen ? 0.25 : 0.0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 17,
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
                border: Border(top: BorderSide(color: p.divider, width: 0.5)),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < suggestions.length; i++)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
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
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: state.recurSel[i]
                                    ? p.primary
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: state.recurSel[i]
                                      ? p.primary
                                      : p.muted.withValues(alpha: 0.5),
                                  width: 1.5,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: state.recurSel[i]
                                  ? const Icon(
                                      Icons.check_rounded,
                                      size: 13,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () => notifier.toggleRecurringItem(i),
                              child: Row(
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: suggestions[i].resolvedColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        suggestions[i].titleForMonth,
                                        maxLines: 1,
                                        style: OmniType.bodySm.copyWith(
                                          color: p.ink,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => _openRecurringAmountKeypad(
                              i,
                              suggestions[i],
                              state.recurAmt[i],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              height: 29,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
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
                                    state.recurAmt[i] > 0
                                        ? FinanceMonthUtils.formatVndSpace(
                                            state.recurAmt[i],
                                          )
                                        : 'Nhập số tiền',
                                    style: OmniType.caption.copyWith(
                                      color: state.recurAmt[i] > 0
                                          ? p.ink
                                          : p.primary,
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
                    padding: const EdgeInsets.fromLTRB(12, 9, 12, 11),
                    child: SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: FilledButton(
                        onPressed: selectedCount > 0 && selectedSum > 0
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
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            selectedCount > 0 && selectedSum > 0
                                ? 'Ghi $selectedCount khoản · ${FinanceMonthUtils.formatVndSpace(selectedSum)}'
                                : (selectedCount > 0
                                      ? 'Nhập số tiền cho khoản đã chọn'
                                      : 'Chọn ít nhất 1 khoản'),
                            style: OmniType.bodySm.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
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
      final isMonthEmpty =
          state.activeMonthItems.isEmpty && !state.hasActiveFilter;
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
            isMonthEmpty
                ? 'Chưa có khoản chi nào trong ${FinanceMonthUtils.formatMonthFull(state.activeMonth)}.'
                : 'Không có khoản chi phù hợp bộ lọc.',
            textAlign: TextAlign.center,
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
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  FinanceMonthUtils.formatVndSpace(section.totalAmount),
                  maxLines: 1,
                  style: OmniType.caption.copyWith(
                    color: p.muted,
                    fontWeight: FontWeight.w500,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
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
