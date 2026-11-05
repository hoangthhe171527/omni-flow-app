import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../application/finance_providers.dart';
import '../domain/finance_models.dart';
import 'widgets/expense_row_tile.dart';
import 'widgets/finance_palette.dart';

/// Chế độ kỳ tổng hợp trên màn hình **Tổng hợp chi phí** (`/finance/summary`).
enum ExpenseSummaryScope {
  month('Theo Tháng'),
  quarter('Theo Quý'),
  year('Theo Năm');

  const ExpenseSummaryScope(this.label);
  final String label;
}

/// Chế độ xem diễn biến trong Năm (`4 Quý` hoặc `12 Tháng`).
enum YearTrendBreakdown {
  quarter('4 Quý'),
  month('12 Tháng');

  const YearTrendBreakdown(this.label);
  final String label;
}

/// Chiều phân tích cơ cấu chi phí (`Theo nhóm` hoặc `Nguồn tiền`).
enum SummaryDimension {
  group('Theo nhóm'),
  account('Nguồn tiền');

  const SummaryDimension(this.label);
  final String label;
}

/// Dữ liệu một dòng diễn biến kỳ con (Tháng hoặc Quý).
@immutable
class _SummaryTrendRow {
  const _SummaryTrendRow({
    required this.key,
    required this.label,
    required this.amount,
    required this.sharePct,
    required this.barRatio,
    this.isPeak = false,
    this.isCurrent = false,
    this.currentLabel = 'Kỳ này',
    this.onTap,
  });

  final String key;
  final String label;
  final int amount;
  final double sharePct;
  final double barRatio;
  final bool isPeak;
  final bool isCurrent;
  final String currentLabel;
  final VoidCallback? onTap;
}

/// Dữ liệu một dòng cơ cấu theo Nhóm chi phí hoặc Nguồn tiền.
@immutable
class _SummaryDimensionRow {
  const _SummaryDimensionRow({
    required this.id,
    required this.name,
    required this.color,
    required this.amount,
    required this.count,
    required this.countLabel,
    required this.sharePct,
    required this.items,
  });

  final String id;
  final String name;
  final Color color;
  final int amount;
  final int count;
  final String countLabel;
  final double sharePct;
  final List<ExpenseItem> items;
}

/// Màn hình độc lập **Tổng hợp chi phí** (`/finance/summary`),
/// tách biệt hoàn toàn với **Sổ chi phí** ghi chép hàng ngày (`/finance/expenses`):
/// - Chuyển đổi 1 chạm giữa **Theo Tháng** · **Theo Quý** · **Theo Năm**
/// - Thẻ Hero Tổng hợp Kỳ: Tổng chi (`Zero-Ellipsis`), TB tháng/ngày, tổng số khoản, biến động so với kỳ trước, Đã trả / Phải trả
/// - Thẻ Diễn biến trong Kỳ: So sánh 3 tháng trong Quý, 4 Quý / 12 Tháng trong Năm, hoặc 3 tháng gần nhất
/// - Thẻ Cơ cấu Chi phí: Chuyển đổi 1 chạm giữa **Theo nhóm** và **Nguồn tiền**, kèm thanh tỷ trọng đa sắc (`Stacked Bar`) và xem danh sách khoản chi của từng mục
class ExpenseSummaryPage extends ConsumerStatefulWidget {
  const ExpenseSummaryPage({
    super.key,
    this.initialScope = ExpenseSummaryScope.quarter,
  });

  final ExpenseSummaryScope initialScope;

  @override
  ConsumerState<ExpenseSummaryPage> createState() => _ExpenseSummaryPageState();
}

class _ExpenseSummaryPageState extends ConsumerState<ExpenseSummaryPage> {
  late ExpenseSummaryScope _scope;
  late int _selectedYear;
  late int _selectedQuarter;
  late int _selectedMonth;
  YearTrendBreakdown _yearTrend = YearTrendBreakdown.quarter;
  SummaryDimension _dimension = SummaryDimension.group;
  final GlobalKey _yearBtnKey = GlobalKey();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _scope = widget.initialScope;
    final state = ref.read(financeLedgerProvider);
    final currentYm = state.activeMonth;
    _selectedYear = FinanceMonthUtils.yearOf(currentYm);
    _selectedMonth = FinanceMonthUtils.monthNumberOf(currentYm);
    _selectedQuarter = ((_selectedMonth - 1) ~/ 3) + 1;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initialized = true;
      _ensureActiveScopeLoaded();
    });
  }

  List<String> _monthsForQuarter(int year, int quarter) {
    final startMonth = (quarter - 1) * 3 + 1;
    return [
      for (var m = startMonth; m < startMonth + 3; m++)
        '$year-${m.toString().padLeft(2, '0')}',
    ];
  }

  List<String> _monthsForYear(int year) {
    return [
      for (var m = 1; m <= 12; m++) '$year-${m.toString().padLeft(2, '0')}',
    ];
  }

  List<String> _activePeriodMonths() {
    return switch (_scope) {
      ExpenseSummaryScope.month => [
        '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}',
      ],
      ExpenseSummaryScope.quarter => _monthsForQuarter(
        _selectedYear,
        _selectedQuarter,
      ),
      ExpenseSummaryScope.year => _monthsForYear(_selectedYear),
    };
  }

  List<String> _comparisonPeriodMonths() {
    switch (_scope) {
      case ExpenseSummaryScope.month:
        final ym =
            '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}';
        return [
          FinanceMonthUtils.shiftMonth(ym, -1),
          FinanceMonthUtils.shiftMonth(ym, -2),
        ];
      case ExpenseSummaryScope.quarter:
        final prevQ = _selectedQuarter == 1 ? 4 : _selectedQuarter - 1;
        final prevY = _selectedQuarter == 1 ? _selectedYear - 1 : _selectedYear;
        return _monthsForQuarter(prevY, prevQ);
      case ExpenseSummaryScope.year:
        return const [];
    }
  }

  Future<void> _ensureActiveScopeLoaded({bool forceRefresh = false}) async {
    if (!mounted) return;
    final toLoad = <String>{
      ..._activePeriodMonths(),
      ..._comparisonPeriodMonths(),
    };
    await ref
        .read(financeLedgerProvider.notifier)
        .ensureMonthsLoaded(toLoad, forceRefresh: forceRefresh);
  }

  void _setScope(ExpenseSummaryScope next) {
    if (_scope == next) return;
    setState(() => _scope = next);
    unawaited(_ensureActiveScopeLoaded());
  }

  void _selectQuarter(int q) {
    final clamped = q.clamp(1, 4);
    setState(() => _selectedQuarter = clamped);
    unawaited(_ensureActiveScopeLoaded());
  }

  void _selectMonth(int m, {int? year}) {
    setState(() {
      if (year != null) _selectedYear = year;
      _selectedMonth = m.clamp(1, 12);
      _selectedQuarter = ((_selectedMonth - 1) ~/ 3) + 1;
    });
    unawaited(_ensureActiveScopeLoaded());
  }

  void _selectYear(int y) {
    setState(() => _selectedYear = y);
    unawaited(_ensureActiveScopeLoaded());
  }

  void _shiftPeriod(int delta) {
    setState(() {
      switch (_scope) {
        case ExpenseSummaryScope.month:
          final ym =
              '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}';
          final shifted = FinanceMonthUtils.shiftMonth(ym, delta);
          _selectedYear = FinanceMonthUtils.yearOf(shifted);
          _selectedMonth = FinanceMonthUtils.monthNumberOf(shifted);
          _selectedQuarter = ((_selectedMonth - 1) ~/ 3) + 1;
        case ExpenseSummaryScope.quarter:
          var q = _selectedQuarter + delta;
          var y = _selectedYear;
          while (q < 1) {
            q += 4;
            y -= 1;
          }
          while (q > 4) {
            q -= 4;
            y += 1;
          }
          _selectedQuarter = q;
          _selectedYear = y;
        case ExpenseSummaryScope.year:
          _selectedYear = (_selectedYear + delta).clamp(2020, 2035);
      }
    });
    unawaited(_ensureActiveScopeLoaded());
  }

  Future<void> _openYearPicker(FinanceLedgerState state) async {
    final currentYear = FinanceMonthUtils.yearOf(
      FinanceMonthUtils.currentVnMonth(state.clock),
    );
    final years = <int>{
      for (var i = 0; i <= 3; i++) currentYear - i,
      _selectedYear,
    }.toList()..sort((a, b) => b.compareTo(a));

    final picked = await showFinancePopoverMenu<int>(
      context: context,
      anchorContext: _yearBtnKey.currentContext,
      header: 'Chọn năm tổng hợp',
      width: 210,
      items: [
        for (final y in years)
          FinancePopoverItem<int>(
            value: y,
            label: 'Năm $y',
            selected: y == _selectedYear,
          ),
      ],
    );
    if (picked != null && mounted) {
      _selectYear(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(financeLedgerProvider);
    final p = FinancePalette.of(context);
    if (!_initialized && state.loadedMonths.isNotEmpty) {
      _initialized = true;
    }

    final periodMonths = _activePeriodMonths();
    final anyLoaded = periodMonths.any(state.isMonthLoaded);

    return Scaffold(
      backgroundColor: p.bg,
      appBar: OmniAppBar(
        title: 'Tổng hợp chi phí',
        backgroundColor: p.bg,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Tooltip(
              message: 'Làm mới dữ liệu',
              child: InkWell(
                key: const ValueKey('finance-summary-refresh-btn'),
                onTap: () => _ensureActiveScopeLoaded(forceRefresh: true),
                borderRadius: BorderRadius.circular(99),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: p.card,
                    shape: BoxShape.circle,
                    border: Border.all(color: p.line, width: 0.5),
                  ),
                  alignment: Alignment.center,
                  child: state.syncing
                      ? SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              p.primary,
                            ),
                          ),
                        )
                      : Icon(Icons.refresh_rounded, size: 17, color: p.ink),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            children: [
              // KHỐI 1: Bộ chuyển Tháng / Quý / Năm + Thanh chọn kỳ
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                child: Column(
                  children: [
                    _buildScopeSwitchRow(p, state),
                    const SizedBox(height: 7),
                    _buildPeriodRibbon(p, state),
                  ],
                ),
              ),
              // Nội dung tổng hợp cuộn
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => _ensureActiveScopeLoaded(forceRefresh: true),
                  color: p.primary,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 48),
                    children: [
                      if ((state.isLoading || state.syncing) && !anyLoaded)
                        _buildLoadingCard(p)
                      else ...[
                        // KHỐI 2: Thẻ Hero Tổng hợp Kỳ
                        _buildHeroSummaryCard(p, state, periodMonths),
                        const SizedBox(height: 10),
                        // KHỐI 3: Thẻ Diễn biến trong Kỳ
                        _buildTrendCard(p, state),
                        const SizedBox(height: 10),
                        // KHỐI 4: Thẻ Cơ cấu Chi phí (Theo nhóm | Nguồn tiền)
                        _buildBreakdownCard(p, state, periodMonths),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScopeSwitchRow(FinancePalette p, FinanceLedgerState state) {
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
                for (final s in ExpenseSummaryScope.values)
                  Expanded(
                    child: GestureDetector(
                      key: ValueKey('finance-summary-tab-${s.name}'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _setScope(s),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _scope == s ? p.card : Colors.transparent,
                          borderRadius: BorderRadius.circular(7),
                          boxShadow: _scope == s
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
                          s.label,
                          maxLines: 1,
                          style: OmniType.caption.copyWith(
                            color: _scope == s ? p.primaryInk : p.muted,
                            fontWeight: _scope == s
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_scope != ExpenseSummaryScope.year) ...[
          const SizedBox(width: 8),
          InkWell(
            key: const ValueKey('finance-summary-year-btn'),
            onTap: () => _openYearPicker(state),
            borderRadius: BorderRadius.circular(9),
            child: Container(
              key: _yearBtnKey,
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(
                color: p.primarySoft,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: p.selLine, width: 0.5),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_selectedYear',
                    style: OmniType.caption.copyWith(
                      color: p.primaryInk,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 15,
                    color: p.primaryInk,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPeriodRibbon(FinancePalette p, FinanceLedgerState state) {
    final currentYear = FinanceMonthUtils.yearOf(
      FinanceMonthUtils.currentVnMonth(state.clock),
    );
    final years = <int>{
      currentYear - 2,
      currentYear - 1,
      currentYear,
      _selectedYear,
    }.toList()..sort();

    return Row(
      children: [
        InkWell(
          key: const ValueKey('finance-summary-prev-btn'),
          onTap: () => _shiftPeriod(-1),
          borderRadius: BorderRadius.circular(9),
          child: Container(
            width: 30,
            height: 34,
            decoration: BoxDecoration(
              color: p.track,
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.chevron_left_rounded, size: 18, color: p.ink2),
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Container(
            height: 34,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: p.track,
              borderRadius: BorderRadius.circular(9),
            ),
            child: switch (_scope) {
              ExpenseSummaryScope.quarter => Row(
                children: [
                  for (var q = 1; q <= 4; q++)
                    Expanded(
                      child: GestureDetector(
                        key: ValueKey('finance-summary-quarter-$q'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _selectQuarter(q),
                        child: _buildRibbonChip(
                          p,
                          label: 'Quý $q',
                          active: _selectedQuarter == q,
                        ),
                      ),
                    ),
                ],
              ),
              ExpenseSummaryScope.year => Row(
                children: [
                  for (final y in years)
                    Expanded(
                      child: GestureDetector(
                        key: ValueKey('finance-summary-year-chip-$y'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _selectYear(y),
                        child: _buildRibbonChip(
                          p,
                          label: 'Năm $y',
                          active: _selectedYear == y,
                        ),
                      ),
                    ),
                ],
              ),
              ExpenseSummaryScope.month => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    for (var m = 1; m <= 12; m++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.5),
                        child: GestureDetector(
                          key: ValueKey('finance-summary-month-chip-$m'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _selectMonth(m),
                          child: _buildRibbonChip(
                            p,
                            label: 'Tháng $m',
                            active: _selectedMonth == m,
                            horizontalPadding: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            },
          ),
        ),
        const SizedBox(width: 5),
        InkWell(
          key: const ValueKey('finance-summary-next-btn'),
          onTap: () => _shiftPeriod(1),
          borderRadius: BorderRadius.circular(9),
          child: Container(
            width: 30,
            height: 34,
            decoration: BoxDecoration(
              color: p.track,
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.chevron_right_rounded, size: 18, color: p.ink2),
          ),
        ),
      ],
    );
  }

  Widget _buildRibbonChip(
    FinancePalette p, {
    required String label,
    required bool active,
    double horizontalPadding = 6,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? p.card : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        boxShadow: active
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
        label,
        maxLines: 1,
        style: OmniType.caption.copyWith(
          color: active ? p.ink : p.muted,
          fontWeight: active ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildLoadingCard(FinancePalette p) {
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
            'Đang tổng hợp dữ liệu chi phí…',
            textAlign: TextAlign.center,
            style: OmniType.bodySm.copyWith(color: p.muted),
          ),
        ],
      ),
    );
  }

  /// KHỐI 2: Thẻ Hero Tổng hợp Kỳ (Tháng / Quý / Năm).
  Widget _buildHeroSummaryCard(
    FinancePalette p,
    FinanceLedgerState state,
    List<String> periodMonths,
  ) {
    var total = 0;
    var paid = 0;
    var outstanding = 0;
    var count = 0;
    var activeMonthsWithSpend = 0;

    for (final ym in periodMonths) {
      final s = state.summaryForMonth(ym);
      total += s.total;
      paid += s.paid;
      outstanding += s.outstanding;
      count += s.count;
      if (s.total > 0 || s.count > 0) {
        activeMonthsWithSpend++;
      }
    }

    final paidRatio = total <= 0 ? 0.0 : (paid / total).clamp(0.0, 1.0);

    final String titleText;
    final String avgPrefix;
    final int avgAmount;
    ({String text, bool isIncrease})? deltaBadge;

    switch (_scope) {
      case ExpenseSummaryScope.month:
        final ym = periodMonths.first;
        titleText = 'Tổng hợp Tháng $_selectedMonth/$_selectedYear';
        final days = DateTime.utc(
          FinanceMonthUtils.yearOf(ym),
          FinanceMonthUtils.monthNumberOf(ym) + 1,
          0,
        ).day;
        avgPrefix = 'TB ngày: ';
        avgAmount = days > 0 ? (total / days).round() : 0;
        final summary = state.summaryForMonth(ym);
        deltaBadge = summary.deltaPill;
      case ExpenseSummaryScope.quarter:
        final startM = (_selectedQuarter - 1) * 3 + 1;
        final endM = startM + 2;
        titleText =
            'Tổng chi Quý $_selectedQuarter/$_selectedYear (T$startM – T$endM)';
        avgPrefix = 'TB tháng: ';
        final divisor = activeMonthsWithSpend > 0 ? activeMonthsWithSpend : 3;
        avgAmount = (total / divisor).round();

        final prevQ = _selectedQuarter == 1 ? 4 : _selectedQuarter - 1;
        final prevY = _selectedQuarter == 1 ? _selectedYear - 1 : _selectedYear;
        final prevMonths = _monthsForQuarter(prevY, prevQ);
        final prevTotal = prevMonths.fold<int>(
          0,
          (sum, m) => sum + state.summaryForMonth(m).total,
        );
        if (prevTotal > 0) {
          final pct = (((total - prevTotal) / prevTotal) * 100).round();
          if (pct != 0) {
            final sign = pct > 0 ? '+' : '';
            deltaBadge = (
              text: '$sign$pct% vs Quý $prevQ',
              isIncrease: pct > 0,
            );
          }
        }
      case ExpenseSummaryScope.year:
        titleText = 'Tổng chi Năm $_selectedYear (12 tháng)';
        avgPrefix = 'TB tháng: ';
        final divisor = activeMonthsWithSpend > 0 ? activeMonthsWithSpend : 12;
        avgAmount = (total / divisor).round();
    }

    return Container(
      key: const ValueKey('finance-summary-hero-card'),
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.line, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  titleText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OmniType.caption.copyWith(
                    color: p.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (deltaBadge != null) ...[
                const SizedBox(width: 8),
                Container(
                  height: 23,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: deltaBadge.isIncrease ? p.amberSoft : p.okSoft,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    deltaBadge.text,
                    style: OmniType.micro.copyWith(
                      color: deltaBadge.isIncrease ? p.amber : p.ok,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 3),
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
                    FinanceMonthUtils.formatNumber(total),
                    maxLines: 1,
                    style: OmniType.displayLg.copyWith(
                      color: p.ink,
                      fontWeight: FontWeight.w700,
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
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              RichText(
                text: TextSpan(
                  style: OmniType.micro.copyWith(
                    color: p.muted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  children: [
                    TextSpan(text: avgPrefix),
                    TextSpan(
                      text: FinanceMonthUtils.formatVndSpace(avgAmount),
                      style: TextStyle(
                        color: p.ink2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text('•', style: OmniType.micro.copyWith(color: p.muted)),
              RichText(
                text: TextSpan(
                  style: OmniType.micro.copyWith(color: p.muted),
                  children: [
                    TextSpan(
                      text: '$count',
                      style: TextStyle(
                        color: p.ink2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const TextSpan(text: ' khoản chi'),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 9),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: SizedBox(
                height: 6,
                child: LinearProgressIndicator(
                  value: paidRatio,
                  backgroundColor: p.amberSoft,
                  valueColor: AlwaysStoppedAnimation<Color>(p.primary),
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _buildKpiBox(
                  p,
                  dotColor: p.ok,
                  label: 'Đã trả',
                  amountText: FinanceMonthUtils.formatVndSpace(paid),
                  amountColor: p.ink,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildKpiBox(
                  p,
                  dotColor: outstanding > 0 ? p.amber : p.ok,
                  label: 'Phải trả',
                  amountText: FinanceMonthUtils.formatVndSpace(outstanding),
                  amountColor: outstanding > 0 ? p.amber : p.ink2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiBox(
    FinancePalette p, {
    required Color dotColor,
    required String label,
    required String amountText,
    required Color amountColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: p.control,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              Text(
                label,
                style: OmniType.micro.copyWith(
                  color: p.muted,
                  fontWeight: FontWeight.w500,
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
    );
  }

  /// KHỐI 3: Thẻ Diễn biến trong Kỳ (So sánh 3 tháng trong Quý / 4 Quý hoặc 12 Tháng trong Năm / 3 tháng gần nhất).
  Widget _buildTrendCard(FinancePalette p, FinanceLedgerState state) {
    final currentVnYm = FinanceMonthUtils.currentVnMonth(state.clock);
    final currentVnYear = FinanceMonthUtils.yearOf(currentVnYm);
    final currentVnMonth = FinanceMonthUtils.monthNumberOf(currentVnYm);
    final currentVnQuarter = ((currentVnMonth - 1) ~/ 3) + 1;

    final String headerTitle;
    final List<_SummaryTrendRow> rows = [];

    if (_scope == ExpenseSummaryScope.quarter) {
      headerTitle = '3 THÁNG TRONG QUÝ $_selectedQuarter/$_selectedYear';
      final months = _monthsForQuarter(_selectedYear, _selectedQuarter);
      final totals = [for (final ym in months) state.summaryForMonth(ym).total];
      final sumTotal = totals.fold<int>(0, (s, v) => s + v);
      final maxVal = totals.fold<int>(0, math.max);

      for (var i = 0; i < months.length; i++) {
        final ym = months[i];
        final mNum = FinanceMonthUtils.monthNumberOf(ym);
        final amt = totals[i];
        final share = sumTotal > 0 ? (amt / sumTotal) * 100 : 0.0;
        final ratio = maxVal > 0 ? (amt / maxVal).clamp(0.0, 1.0) : 0.0;
        rows.add(
          _SummaryTrendRow(
            key: ym,
            label: 'Tháng $mNum/$_selectedYear',
            amount: amt,
            sharePct: share,
            barRatio: ratio,
            isPeak: maxVal > 0 && amt == maxVal,
            isCurrent: ym == currentVnYm,
            currentLabel: 'Tháng này',
            onTap: () {
              setState(() {
                _selectedMonth = mNum;
                _scope = ExpenseSummaryScope.month;
              });
              unawaited(_ensureActiveScopeLoaded());
            },
          ),
        );
      }
    } else if (_scope == ExpenseSummaryScope.year) {
      headerTitle = 'DIỄN BIẾN NĂM $_selectedYear';
      if (_yearTrend == YearTrendBreakdown.quarter) {
        final qTotals = <int>[];
        for (var q = 1; q <= 4; q++) {
          final qMonths = _monthsForQuarter(_selectedYear, q);
          final qSum = qMonths.fold<int>(
            0,
            (s, ym) => s + state.summaryForMonth(ym).total,
          );
          qTotals.add(qSum);
        }
        final yearSum = qTotals.fold<int>(0, (s, v) => s + v);
        final maxVal = qTotals.fold<int>(0, math.max);

        for (var q = 1; q <= 4; q++) {
          final startM = (q - 1) * 3 + 1;
          final endM = startM + 2;
          final amt = qTotals[q - 1];
          final share = yearSum > 0 ? (amt / yearSum) * 100 : 0.0;
          final ratio = maxVal > 0 ? (amt / maxVal).clamp(0.0, 1.0) : 0.0;
          final quarterIndex = q;
          rows.add(
            _SummaryTrendRow(
              key: 'Q$q-$_selectedYear',
              label: 'Quý $q/$_selectedYear (T$startM–T$endM)',
              amount: amt,
              sharePct: share,
              barRatio: ratio,
              isPeak: maxVal > 0 && amt == maxVal,
              isCurrent:
                  _selectedYear == currentVnYear && q == currentVnQuarter,
              currentLabel: 'Quý này',
              onTap: () {
                setState(() {
                  _selectedQuarter = quarterIndex;
                  _scope = ExpenseSummaryScope.quarter;
                });
                unawaited(_ensureActiveScopeLoaded());
              },
            ),
          );
        }
      } else {
        final months = _monthsForYear(_selectedYear);
        final mTotals = [
          for (final ym in months) state.summaryForMonth(ym).total,
        ];
        final yearSum = mTotals.fold<int>(0, (s, v) => s + v);
        final maxVal = mTotals.fold<int>(0, math.max);

        for (var i = 0; i < months.length; i++) {
          final ym = months[i];
          final mNum = i + 1;
          final amt = mTotals[i];
          if (amt <= 0 && ym != currentVnYm && yearSum > 0) continue;
          final share = yearSum > 0 ? (amt / yearSum) * 100 : 0.0;
          final ratio = maxVal > 0 ? (amt / maxVal).clamp(0.0, 1.0) : 0.0;
          rows.add(
            _SummaryTrendRow(
              key: ym,
              label: 'Tháng $mNum/$_selectedYear',
              amount: amt,
              sharePct: share,
              barRatio: ratio,
              isPeak: maxVal > 0 && amt == maxVal,
              isCurrent: ym == currentVnYm,
              currentLabel: 'Tháng này',
              onTap: () {
                setState(() {
                  _selectedMonth = mNum;
                  _scope = ExpenseSummaryScope.month;
                });
                unawaited(_ensureActiveScopeLoaded());
              },
            ),
          );
        }
      }
    } else {
      headerTitle = 'SO SÁNH 3 THÁNG GẦN NHẤT';
      final activeYm =
          '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}';
      final months = [
        FinanceMonthUtils.shiftMonth(activeYm, -2),
        FinanceMonthUtils.shiftMonth(activeYm, -1),
        activeYm,
      ];
      final totals = [for (final ym in months) state.summaryForMonth(ym).total];
      final sumTotal = totals.fold<int>(0, (s, v) => s + v);
      final maxVal = totals.fold<int>(0, math.max);

      for (var i = 0; i < months.length; i++) {
        final ym = months[i];
        final mNum = FinanceMonthUtils.monthNumberOf(ym);
        final yNum = FinanceMonthUtils.yearOf(ym);
        final amt = totals[i];
        final share = sumTotal > 0 ? (amt / sumTotal) * 100 : 0.0;
        final ratio = maxVal > 0 ? (amt / maxVal).clamp(0.0, 1.0) : 0.0;
        rows.add(
          _SummaryTrendRow(
            key: ym,
            label: 'Tháng $mNum/$yNum',
            amount: amt,
            sharePct: share,
            barRatio: ratio,
            isPeak: maxVal > 0 && amt == maxVal,
            isCurrent: ym == activeYm,
            currentLabel: 'Đang xem',
            onTap: () => _selectMonth(mNum, year: yNum),
          ),
        );
      }
    }

    return Container(
      key: const ValueKey('finance-summary-trend-card'),
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.line, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  headerTitle,
                  style: OmniType.overline.copyWith(
                    color: p.muted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              if (_scope == ExpenseSummaryScope.year)
                _buildMiniSegmentedToggle<YearTrendBreakdown>(
                  p,
                  values: YearTrendBreakdown.values,
                  selected: _yearTrend,
                  labelOf: (v) => v.label,
                  keyPrefix: 'finance-summary-year-by',
                  onSelected: (v) => setState(() => _yearTrend = v),
                )
              else
                Text(
                  'Chạm để xem kỳ ›',
                  style: OmniType.micro.copyWith(
                    color: p.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 7),
            _buildTrendRowItem(p, rows[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildTrendRowItem(FinancePalette p, _SummaryTrendRow row) {
    return InkWell(
      key: ValueKey('finance-summary-trend-${row.key}'),
      onTap: row.onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: row.isCurrent ? p.primarySoft : p.control,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: row.isCurrent ? p.selLine : Colors.transparent,
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        row.label,
                        style: OmniType.caption.copyWith(
                          color: p.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (row.isPeak)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: p.amberSoft,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            'Cao nhất',
                            style: OmniType.micro.copyWith(
                              color: p.amber,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (row.isCurrent)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: p.primary,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            row.currentLabel,
                            style: OmniType.micro.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  FinanceMonthUtils.formatVndSpace(row.amount),
                  style: OmniType.caption.copyWith(
                    color: p.ink,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 38,
                  child: Text(
                    row.amount > 0
                        ? '${row.sharePct.toStringAsFixed(1).replaceAll('.', ',')}%'
                        : '0%',
                    textAlign: TextAlign.right,
                    style: OmniType.micro.copyWith(
                      color: p.muted,
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
                height: 5,
                child: LinearProgressIndicator(
                  value: row.barRatio,
                  backgroundColor: p.ink.withValues(alpha: 0.07),
                  valueColor: AlwaysStoppedAnimation<Color>(p.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// KHỐI 4: Thẻ Cơ cấu Chi phí trong Kỳ (`Theo nhóm` | `Nguồn tiền`).
  Widget _buildBreakdownCard(
    FinancePalette p,
    FinanceLedgerState state,
    List<String> periodMonths,
  ) {
    final rows = _computeDimensionRows(p, state, periodMonths);

    return Container(
      key: const ValueKey('finance-summary-breakdown-card'),
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.line, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'CƠ CẤU CHI PHÍ TRONG KỲ',
                  style: OmniType.overline.copyWith(
                    color: p.muted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              _buildMiniSegmentedToggle<SummaryDimension>(
                p,
                values: SummaryDimension.values,
                selected: _dimension,
                labelOf: (v) => v.label,
                keyPrefix: 'finance-summary-dim',
                onSelected: (v) => setState(() => _dimension = v),
              ),
            ],
          ),
          const SizedBox(height: 11),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Chưa có khoản chi phát sinh trong kỳ này.',
                textAlign: TextAlign.center,
                style: OmniType.caption.copyWith(color: p.muted),
              ),
            )
          else ...[
            // Stacked multi-color progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    for (var i = 0; i < rows.length; i++) ...[
                      if (i > 0) const SizedBox(width: 2),
                      Expanded(
                        flex: math.max(1, (rows[i].sharePct * 10).round()),
                        child: Container(color: rows[i].color),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _buildDimensionRowItem(p, rows[i]),
            ],
          ],
        ],
      ),
    );
  }

  List<_SummaryDimensionRow> _computeDimensionRows(
    FinancePalette p,
    FinanceLedgerState state,
    List<String> periodMonths,
  ) {
    final allItems = <ExpenseItem>[];
    for (final ym in periodMonths) {
      final list = state.itemsByMonth[ym] ?? const <ExpenseItem>[];
      for (final item in list) {
        if (item.countsAsExpense && item.amount > 0) {
          allItems.add(item);
        }
      }
    }
    if (allItems.isEmpty) return const [];

    final totalSpend = allItems.fold<int>(0, (s, e) => s + e.amount);
    if (totalSpend <= 0) return const [];

    if (_dimension == SummaryDimension.group) {
      final byGroup = <String, List<ExpenseItem>>{};
      for (final item in allItems) {
        byGroup.putIfAbsent(item.groupId, () => []).add(item);
      }
      final list = <_SummaryDimensionRow>[];
      for (final entry in byGroup.entries) {
        final items = entry.value;
        final first = items.first;
        final grp = state.groupById(
          entry.key,
          fallbackName: first.groupName,
          fallbackColor: first.groupColor,
          fallbackCountsAsExpense: first.countsAsExpense,
        );
        final amt = items.fold<int>(0, (s, e) => s + e.amount);
        final share = (amt / totalSpend) * 100;
        list.add(
          _SummaryDimensionRow(
            id: grp.id,
            name: grp.name,
            color: FinanceMonthUtils.parseHexColor(
              grp.color,
              fallback: p.primary,
            ),
            amount: amt,
            count: items.length,
            countLabel: '${items.length} khoản',
            sharePct: share,
            items: items,
          ),
        );
      }
      list.sort((a, b) => b.amount.compareTo(a.amount));
      return list;
    } else {
      final paletteColors = <Color>[
        p.primary,
        const Color(0xFF0284C7),
        const Color(0xFF12B76A),
        const Color(0xFF7C3AED),
        const Color(0xFFD97706),
        const Color(0xFFE11D48),
      ];
      final byAccount = <String, List<ExpenseItem>>{};
      final accountNames = <String, String>{};
      for (final item in allItems) {
        final accName =
            item.effectiveAccountName ??
            state.accountNameById(item.accountId) ??
            'Chưa gắn nguồn tiền';
        final key = item.accountId?.isNotEmpty == true
            ? item.accountId!
            : accName;
        accountNames[key] = accName;
        byAccount.putIfAbsent(key, () => []).add(item);
      }
      final list = <_SummaryDimensionRow>[];
      var colorIdx = 0;
      for (final entry in byAccount.entries) {
        final items = entry.value;
        final amt = items.fold<int>(0, (s, e) => s + e.amount);
        final share = (amt / totalSpend) * 100;
        final color = paletteColors[colorIdx % paletteColors.length];
        colorIdx++;
        list.add(
          _SummaryDimensionRow(
            id: entry.key,
            name: accountNames[entry.key] ?? 'Nguồn khác',
            color: color,
            amount: amt,
            count: items.length,
            countLabel: '${items.length} khoản',
            sharePct: share,
            items: items,
          ),
        );
      }
      list.sort((a, b) => b.amount.compareTo(a.amount));
      return list;
    }
  }

  Widget _buildDimensionRowItem(FinancePalette p, _SummaryDimensionRow row) {
    final ratio = (row.sharePct / 100).clamp(0.0, 1.0);
    return InkWell(
      key: ValueKey('finance-summary-row-${row.id}'),
      onTap: () => _openDimensionDrilldownSheet(row),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: row.color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: OmniType.caption.copyWith(
                        color: p.ink,
                        fontWeight: FontWeight.w600,
                      ),
                      children: [
                        TextSpan(text: row.name),
                        TextSpan(
                          text: ' (${row.countLabel})',
                          style: OmniType.micro.copyWith(
                            color: p.muted,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  FinanceMonthUtils.formatVndSpace(row.amount),
                  style: OmniType.caption.copyWith(
                    color: p.ink,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  constraints: const BoxConstraints(minWidth: 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: p.control,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${row.sharePct.toStringAsFixed(1).replaceAll('.', ',')}%',
                    textAlign: TextAlign.right,
                    style: OmniType.micro.copyWith(
                      color: p.muted,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.only(left: 17),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: SizedBox(
                  height: 4,
                  child: LinearProgressIndicator(
                    value: ratio,
                    backgroundColor: p.control,
                    valueColor: AlwaysStoppedAnimation<Color>(row.color),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniSegmentedToggle<T>(
    FinancePalette p, {
    required List<T> values,
    required T selected,
    required String Function(T) labelOf,
    required String keyPrefix,
    required ValueChanged<T> onSelected,
  }) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: p.control,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: p.line, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final v in values)
            GestureDetector(
              key: ValueKey('$keyPrefix-${(v as Enum).name}'),
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelected(v),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: v == selected ? p.card : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                  boxShadow: v == selected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  labelOf(v),
                  style: OmniType.micro.copyWith(
                    color: v == selected ? p.ink : p.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openDimensionDrilldownSheet(_SummaryDimensionRow row) async {
    final p = FinancePalette.of(context);
    final sorted = List<ExpenseItem>.from(row.items)
      ..sort((a, b) => b.spentOn.compareTo(a.spentOn));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.78,
          ),
          decoration: BoxDecoration(
            color: p.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: p.muted.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: row.color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: OmniType.body.copyWith(
                                color: p.ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${row.countLabel} · ${FinanceMonthUtils.formatVndSpace(row.amount)}',
                              style: OmniType.micro.copyWith(
                                color: p.muted,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.of(ctx).pop(),
                        borderRadius: BorderRadius.circular(99),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: p.card,
                            shape: BoxShape.circle,
                            border: Border.all(color: p.line, width: 0.5),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: p.ink2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: sorted.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (_, idx) {
                      final item = sorted[idx];
                      return Container(
                        decoration: BoxDecoration(
                          color: p.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: p.line, width: 0.5),
                        ),
                        child: ExpenseRowTile(
                          item: item,
                          showBottomDivider: false,
                          isFlashed: false,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
