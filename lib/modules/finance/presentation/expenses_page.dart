import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/nav/shell_bar_inset.dart';
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
/// - Header cùng khuôn các màn khác: `OmniTopBar` + viên kính tìm (sắp xếp); "+" là nút kính góc phải dưới;
///   tháng chọn ngay trên thẻ tổng chi (‹ Tháng 11/2026 ›, chạm tên tháng mở menu, vuốt ngang thẻ)
class ExpensesPage extends ConsumerStatefulWidget {
  const ExpensesPage({super.key});

  @override
  ConsumerState<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends ConsumerState<ExpensesPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final GlobalKey _monthBtnKey = GlobalKey();
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
      anchorContext: _monthBtnKey.currentContext,
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
      // Cùng khuôn với Khách / Cơ hội: hàng logo + chuông + tài khoản, bên
      // dưới là một viên kính 44 chứa ô tìm và sắp xếp. Danh sách chạy
      // dưới thanh và nhoè dần.
      extendBodyBehindAppBar: true,
      backgroundColor: p.bg,
      appBar: OmniTopBar(
        allowBack: true,
        semanticsTitle: 'Sổ chi phí',
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: _buildSearchRow(p, state, notifier, sortActive),
        ),
      ),
      // Thêm khoản chi: nút + kính góc phải dưới (rà soát 12/11); ô tìm chỉ
      // còn tìm + sắp xếp.
      body: OmniFabLayer(
        fab: OmniLiquidFab(
          key: const ValueKey('finance-add-btn'),
          tooltip: 'Thêm khoản chi',
          onPressed: (_) => showExpenseAddSheet(context: context),
        ),
        body: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: OmniTopBarOverlap.wrap(
                  child: Builder(
                    builder: (context) {
                      final top = OmniTopBarOverlap.of(context);
                      return RefreshIndicator(
                        edgeOffset: top,
                        onRefresh: notifier.refresh,
                        color: p.primary,
                        // builder: tháng đông khoản chi chỉ dựng các nhóm ngày
                        // đang hiện trên màn, không dựng cả tháng một lượt.
                        child: _lazyList(
                          physics: const AlwaysScrollableScrollPhysics(),
                          // Chừa thanh tab kính + vùng an toàn + nút + kính.
                          padding: EdgeInsets.fromLTRB(
                            16,
                            top + 8,
                            16,
                            OmniFabLayer.listBottom(context),
                          ),
                          children: [
                            if (state.isLoading && !activeLoaded)
                              _buildLoadingCard(p, state)
                            else if (state.errorMessage != null &&
                                !activeLoaded)
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
                              // Vuốt ngang thẻ để sang tháng liền kề.
                              GestureDetector(
                                key: const ValueKey('finance-month-carousel'),
                                onHorizontalDragEnd: (details) {
                                  final vx = details.primaryVelocity ?? 0;
                                  if (vx.abs() < 120) return;
                                  notifier.selectMonth(
                                    FinanceMonthUtils.shiftMonth(
                                      state.activeMonth,
                                      vx < 0 ? 1 : -1,
                                    ),
                                  );
                                },
                                child: _buildSummaryCard(p, state, notifier),
                              ),
                              // TIER 2: Monthly Recurring Card (5 khoản cố định)
                              if (state.showRecurringCard)
                                Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: _buildRecurringCard(
                                    p,
                                    state,
                                    notifier,
                                  ),
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
                      );
                    },
                  ),
                ),
              ),
            ),
            // Floating Undo Toast
            if (state.toast != null)
              Positioned(
                left: 16,
                right: 16,
                // Trên thanh tab kính + nút + (soát 12/11): ở 20 nó nằm dưới kính.
                bottom: ShellBarInset.floatingBottom(
                  context,
                  gap: OmniFabLayer.gap + OmniLiquidFab.size + 12,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: _buildToastBanner(state.toast!, notifier),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static Widget _lazyList({
    required ScrollPhysics physics,
    required EdgeInsetsGeometry padding,
    required List<Widget> children,
  }) {
    return ListView.builder(
      physics: physics,
      padding: padding,
      itemCount: children.length,
      itemBuilder: (_, i) => children[i],
    );
  }

  Widget _buildLoadingCard(FinancePalette p, FinanceLedgerState state) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 36),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(18),
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
        borderRadius: BorderRadius.circular(18),
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

  /// Nội dung viên kính dưới thanh trên: ô tìm và sắp xếp.
  /// [OmniTopBar] lo viên kính, lớp mờ khi đang tìm và nút "Huỷ".
  Widget _buildSearchRow(
    FinancePalette p,
    FinanceLedgerState state,
    FinanceLedgerNotifier notifier,
    bool sortActive,
  ) {
    return Material(
      type: MaterialType.transparency,
      child: SizedBox(
        height: 44,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 2, 0),
          child: Row(
            children: [
              Icon(Icons.search_rounded, size: OmniIconSize.md, color: p.muted),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: const ValueKey('finance-search-input'),
                  controller: _searchCtrl,
                  focusNode: _searchFocus,
                  onChanged: notifier.setSearchQuery,
                  textInputAction: TextInputAction.search,
                  style: OmniType.search.copyWith(
                    color: p.ink,
                    fontStyle: FontStyle.normal,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: false,
                    hintText: 'Tìm khoản chi, số tiền',
                    hintStyle: OmniType.searchHint.copyWith(color: p.muted),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (state.searchQuery.isNotEmpty)
                IconButton(
                  tooltip: 'Xoá tìm kiếm',
                  onPressed: () {
                    notifier.clearSearch();
                    _searchFocus.requestFocus();
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 44,
                  ),
                  icon: Icon(Icons.close_rounded, size: 18, color: p.muted),
                ),
              _buildBarIcon(
                key: const ValueKey('finance-sort-btn'),
                anchorKey: _sortBtnKey,
                tooltip: 'Sắp xếp danh sách',
                icon: Icons.swap_vert_rounded,
                color: sortActive ? p.primaryInk : p.ink,
                onTap: _openSortMenu,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Biểu tượng phẳng trong viên kính tìm, vùng chạm 40×44.
  Widget _buildBarIcon({
    required Key key,
    Key? anchorKey,
    required String tooltip,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        key: key,
        onTap: onTap,
        radius: 22,
        child: SizedBox(
          key: anchorKey,
          width: 40,
          height: 44,
          child: Icon(icon, size: OmniIconSize.md, color: color),
        ),
      ),
    );
  }

  /// Nút ‹ › đổi tháng liền kề trên thẻ tổng chi, vùng chạm 40×40.
  Widget _buildMonthStepButton(
    FinancePalette p, {
    required Key key,
    required String tooltip,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        key: key,
        onTap: onTap,
        radius: 20,
        child: SizedBox.square(
          dimension: 40,
          child: Icon(icon, size: 22, color: p.muted),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    FinancePalette p,
    FinanceLedgerState state,
    FinanceLedgerNotifier notifier,
  ) {
    final summary = state.activeSummary;
    final prevYm = FinanceMonthUtils.shiftMonth(state.activeMonth, -1);
    final nextYm = FinanceMonthUtils.shiftMonth(state.activeMonth, 1);
    final delta = summary.deltaPill;
    final grpBtnActive = state.grpOpen || state.fltGroup != null;

    return OmniGroupSection(
      dividerIndent: 14,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 7, 14, 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hàng 1: bộ chọn tháng (‹ Tháng 11/2026 ›) bên trái, nút tỷ trọng
              // theo nhóm bên phải. Tháng đứng ngay trên con số nó chi phối nên
              // không cần nhãn "Tổng chi tháng X".
              Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      // Lùi 14 để nét mũi tên gần lề chữ của thẻ; vùng chạm vẫn 40.
                      child: Transform.translate(
                        offset: const Offset(-14, 0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildMonthStepButton(
                              p,
                              key: const ValueKey('finance-prev-month-btn'),
                              tooltip: 'Tháng trước',
                              icon: Icons.chevron_left_rounded,
                              onTap: () => notifier.selectMonth(prevYm),
                            ),
                            Flexible(
                              child: Tooltip(
                                message: 'Chọn tháng khác',
                                child: InkWell(
                                  key: _monthBtnKey,
                                  onTap: _openMonthPickerMenu,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            FinanceMonthUtils.formatMonthFull(
                                              state.activeMonth,
                                            ),
                                            maxLines: 1,
                                            softWrap: false,
                                            style: OmniType.body.copyWith(
                                              color: p.ink,
                                              fontWeight: FontWeight.w600,
                                              fontFeatures: const [
                                                FontFeature.tabularFigures(),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        Icon(
                                          Icons.expand_more_rounded,
                                          size: 18,
                                          color: p.muted,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            _buildMonthStepButton(
                              p,
                              key: const ValueKey('finance-next-month-btn'),
                              tooltip: 'Tháng sau',
                              icon: Icons.chevron_right_rounded,
                              onTap: () => notifier.selectMonth(nextYm),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
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
              // Hàng 2: số tổng chi (không co nhỏ bằng FittedBox) + nhãn biến động.
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 6,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          FinanceMonthUtils.formatNumber(summary.total),
                          maxLines: 1,
                          softWrap: false,
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
                  if (delta != null)
                    Container(
                      height: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      constraints: const BoxConstraints(),
                      decoration: BoxDecoration(
                        color: delta.isIncrease ? p.amberSoft : p.okSoft,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Center(
                        widthFactor: 1,
                        child: Text(
                          delta.text,
                          style: OmniType.micro.copyWith(
                            color: delta.isIncrease ? p.amber : p.ok,
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              // Thanh tiến độ 6px
              Padding(
                padding: const EdgeInsets.only(top: 10),
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
              if (summary.excluded.count > 0 && summary.excluded.total != 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Ngoài chi phí: ${FinanceMonthUtils.formatVndSpace(summary.excluded.total)} (${summary.excluded.count} khoản không tính CP)',
                    maxLines: 1,
                    style: OmniType.micro.copyWith(
                      color: p.muted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
            ],
          ),
        ),
        OmniGroupRow(
          key: const ValueKey('finance-flt-paid'),
          title: 'Đã trả',
          selected: state.fltStatus == 'paid',
          onTap: () => notifier.toggleStatusFilter('paid'),
          trailing: Text(
            FinanceMonthUtils.formatVndSpace(summary.paid),
            maxLines: 1,
            style: OmniType.bodyStrong.copyWith(
              color: p.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        OmniGroupRow(
          key: const ValueKey('finance-flt-owe'),
          title: 'Phải trả',
          selected: state.fltStatus == 'owe',
          onTap: () => notifier.toggleStatusFilter('owe'),
          trailing: Text(
            FinanceMonthUtils.formatVndSpace(summary.outstanding),
            maxLines: 1,
            style: OmniType.bodyStrong.copyWith(
              color: summary.outstanding > 0 ? p.amber : p.ink2,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        // Expandable group breakdown (grp-panel)
        if (state.grpOpen)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
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
                OmniIconTile(
                  Icons.category_outlined,
                  color: p.primary,
                  background: p.primarySoft,
                ),
                const SizedBox(width: 8),
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
                Text(
                  FinanceMonthUtils.formatVndSpace(g.amount),
                  maxLines: 1,
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
                  valueColor: AlwaysStoppedAnimation<Color>(p.primary),
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
    final selectedCount = state.selectedRecurringCount;
    final selectedSum = state.selectedRecurringSum;
    final allSum = state.allRecurringSum;

    return OmniGroupSection(
      dividerIndent: 54,
      children: [
        // Header: rc-head với OmniIconTile một tông màu chính
        InkWell(
          key: const ValueKey('finance-recur-head'),
          onTap: notifier.toggleRecurringExpanded,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                OmniIconTile(
                  Icons.autorenew_rounded,
                  color: p.primary,
                  background: p.primarySoft,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Khoản cố định',
                        style: OmniType.bodySm.copyWith(
                          color: p.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        allSum > 0
                            ? '${suggestions.length} khoản · ${FinanceMonthUtils.formatVndSpace(allSum)}'
                            : '${suggestions.length} khoản gợi ý · Chạm để nhập số tiền',
                        style: OmniType.caption.copyWith(
                          color: p.muted,
                          fontFeatures: const [FontFeature.tabularFigures()],
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
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 11),
                    alignment: Alignment.center,
                    decoration: OmniGlass.buttonDecoration(context),
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
          Column(
            children: [
              for (var i = 0; i < suggestions.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    border: i == suggestions.length - 1
                        ? null
                        : Border(
                            bottom: BorderSide(color: p.divider, width: 0.5),
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
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () => notifier.toggleRecurringItem(i),
                          child: Text(
                            suggestions[i].titleForMonth,
                            maxLines: 2,
                            style: OmniType.bodySm.copyWith(
                              color: p.ink,
                              fontWeight: FontWeight.w500,
                            ),
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
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 29,
                          padding: const EdgeInsets.symmetric(horizontal: 9),
                          decoration: BoxDecoration(
                            color: p.control,
                            borderRadius: BorderRadius.circular(12),
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
                                maxLines: 1,
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
                padding: const EdgeInsets.fromLTRB(14, 9, 14, 11),
                child: SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton(
                    onPressed: selectedCount > 0 && selectedSum > 0
                        ? () => notifier.commitRecurring()
                        : null,
                    child: Text(
                      selectedCount > 0 && selectedSum > 0
                          ? 'Ghi $selectedCount khoản · ${FinanceMonthUtils.formatVndSpace(selectedSum)}'
                          : (selectedCount > 0
                                ? 'Nhập số tiền cho khoản đã chọn'
                                : 'Chọn ít nhất 1 khoản'),
                      maxLines: 1,
                      softWrap: false,
                      style: OmniType.bodySm.copyWith(
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
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
            borderRadius: BorderRadius.circular(18),
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
              const SizedBox(width: 8),
              Text(
                FinanceMonthUtils.formatVndSpace(section.totalAmount),
                maxLines: 1,
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
            borderRadius: BorderRadius.circular(18),
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
        color: OmniColors.ink.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: OmniColors.ink.withValues(alpha: 0.24),
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
                    color: OmniColors.orbit,
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
