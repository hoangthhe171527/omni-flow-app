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

  /// Nhãn của nút kỳ: "Tháng 11 · 2026", "Quý 4 · 2026", "Năm 2026".
  String get _periodLabel => switch (_scope) {
    ExpenseSummaryScope.month => 'Tháng $_selectedMonth · $_selectedYear',
    ExpenseSummaryScope.quarter => 'Quý $_selectedQuarter · $_selectedYear',
    ExpenseSummaryScope.year => 'Năm $_selectedYear',
  };

  /// Sheet chọn kỳ: năm (chip) rồi quý / tháng; chế độ Năm chỉ chọn năm.
  Future<void> _openPeriodPicker(FinanceLedgerState state) async {
    final currentYear = FinanceMonthUtils.yearOf(
      FinanceMonthUtils.currentVnMonth(state.clock),
    );
    final years = <int>{
      for (var i = 0; i <= 3; i++) currentYear - i,
      _selectedYear,
    }.toList()..sort((a, b) => b.compareTo(a));

    final picked = await showOmniSheet<({int year, int part})>(
      context: context,
      builder: (_) => _PeriodPickerSheet(
        scope: _scope,
        years: years,
        year: _selectedYear,
        part: switch (_scope) {
          ExpenseSummaryScope.month => _selectedMonth,
          ExpenseSummaryScope.quarter => _selectedQuarter,
          ExpenseSummaryScope.year => 0,
        },
      ),
    );
    if (picked == null || !mounted) return;
    switch (_scope) {
      case ExpenseSummaryScope.month:
        _selectMonth(picked.part, year: picked.year);
      case ExpenseSummaryScope.quarter:
        setState(() => _selectedYear = picked.year);
        _selectQuarter(picked.part);
      case ExpenseSummaryScope.year:
        _selectYear(picked.year);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(
      financeLedgerProvider.select(
        (s) => (
          s.loadedMonths,
          s.isLoading,
          s.syncing,
          s.itemsByMonth,
          s.summariesByMonth,
          s.clock,
        ),
      ),
    );
    final state = ref.read(financeLedgerProvider);
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
        // Không nút làm mới: kéo xuống để làm mới như mọi màn khác.
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            children: [
              // KHỐI 1: Bộ chuyển Tháng / Quý / Năm + Thanh chọn kỳ
              // Hai hàng: Tháng / Quý / Năm, rồi ‹ kỳ › (chạm giữa mở sheet).
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  children: [
                    OmniSegmented(
                      key: const ValueKey('finance-summary-scope'),
                      labels: const ['Tháng', 'Quý', 'Năm'],
                      index: ExpenseSummaryScope.values.indexOf(_scope),
                      onChanged: (i) =>
                          _setScope(ExpenseSummaryScope.values[i]),
                    ),
                    const SizedBox(height: 8),
                    _buildPeriodRow(state),
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
                    // Thanh tab kính phủ lên body: chừa phần đáy bị che thật.
                    padding: EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      OmniFabLayer.listBottom(context, hasFab: false),
                    ),
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

  /// ‹ Quý 4 · 2026 ›: nút kính trước / sau, viên giữa mở sheet chọn kỳ.
  Widget _buildPeriodRow(FinanceLedgerState state) {
    final scheme = Theme.of(context).colorScheme;
    final unit = switch (_scope) {
      ExpenseSummaryScope.month => 'Tháng',
      ExpenseSummaryScope.quarter => 'Quý',
      ExpenseSummaryScope.year => 'Năm',
    };
    final label = _periodLabel;
    return Row(
      children: [
        OmniGlassCircle(
          child: IconButton(
            key: const ValueKey('finance-summary-prev-btn'),
            tooltip: '$unit trước',
            onPressed: () => _shiftPeriod(-1),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OmniGlass(
            blur: false,
            radius: 22,
            child: Semantics(
              button: true,
              label: 'Chọn kỳ, $label',
              excludeSemantics: true,
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  key: const ValueKey('finance-summary-period-btn'),
                  customBorder: const StadiumBorder(),
                  onTap: () => _openPeriodPicker(state),
                  child: SizedBox(
                    height: 44,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            style: OmniType.bodyStrong.copyWith(
                              color: scheme.onSurface,
                              fontFeatures: OmniType.tabular,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        OmniGlassCircle(
          child: IconButton(
            key: const ValueKey('finance-summary-next-btn'),
            tooltip: '$unit sau',
            onPressed: () => _shiftPeriod(1),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingCard(FinancePalette p) {
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
        titleText = 'Tổng chi';
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
        // Kỳ đã hiện ở nút ‹ kỳ › ngay trên: tiêu đề không lặp lại.
        titleText = 'Tổng chi';
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
        titleText = 'Tổng chi';
        avgPrefix = 'TB tháng: ';
        final divisor = activeMonthsWithSpend > 0 ? activeMonthsWithSpend : 12;
        avgAmount = (total / divisor).round();
    }

    return OmniGroupSection(
      key: const ValueKey('finance-summary-hero-card'),
      dividerIndent: 14,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      titleText,
                      maxLines: 2,
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
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        FinanceMonthUtils.formatNumber(total),
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
                padding: const EdgeInsets.only(top: 10),
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
            ],
          ),
        ),
        OmniGroupRow(
          title: 'Đã trả',
          chevron: false,
          trailing: Text(
            FinanceMonthUtils.formatVndSpace(paid),
            maxLines: 1,
            style: OmniType.bodyStrong.copyWith(
              color: p.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        OmniGroupRow(
          title: 'Phải trả',
          chevron: false,
          trailing: Text(
            FinanceMonthUtils.formatVndSpace(outstanding),
            maxLines: 1,
            style: OmniType.bodyStrong.copyWith(
              color: outstanding > 0 ? p.amber : p.ink2,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }

  /// KHỐI 3: Thẻ Diễn biến trong Kỳ (So sánh 3 tháng trong Quý / 4 Quý hoặc 12 Tháng trong Năm / 3 tháng gần nhất).
  Widget _buildTrendCard(FinancePalette p, FinanceLedgerState state) {
    final currentVnYm = FinanceMonthUtils.currentVnMonth(state.clock);
    final currentVnYear = FinanceMonthUtils.yearOf(currentVnYm);
    final currentVnMonth = FinanceMonthUtils.monthNumberOf(currentVnYm);
    final currentVnQuarter = ((currentVnMonth - 1) ~/ 3) + 1;

    final List<_SummaryTrendRow> rows = [];

    if (_scope == ExpenseSummaryScope.quarter) {
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
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_scope == ExpenseSummaryScope.year) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                for (var i = 0; i < YearTrendBreakdown.values.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  OmniChoicePill(
                    key: ValueKey(
                      'finance-summary-year-by-${YearTrendBreakdown.values[i].name}',
                    ),
                    label: YearTrendBreakdown.values[i].label,
                    selected: _yearTrend == YearTrendBreakdown.values[i],
                    onTap: () => setState(
                      () => _yearTrend = YearTrendBreakdown.values[i],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
          ],
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
          color: row.isCurrent ? p.control : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
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
                          fontWeight: row.isCurrent
                              ? FontWeight.w600
                              : FontWeight.w500,
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
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 50,
                  child: Text(
                    row.amount > 0
                        ? '${row.sharePct.toStringAsFixed(1).replaceAll('.', ',')}%'
                        : '0%',
                    maxLines: 1,
                    softWrap: false,
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

    return Column(
      key: const ValueKey('finance-summary-breakdown-card'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OmniSegmented(
          key: const ValueKey('finance-summary-dim'),
          labels: [for (final v in SummaryDimension.values) v.label],
          index: SummaryDimension.values.indexOf(_dimension),
          onChanged: (i) =>
              setState(() => _dimension = SummaryDimension.values[i]),
        ),
        const SizedBox(height: 10),
        OmniGroupSection(
          dividerIndent: 54,
          children: [
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 20,
                ),
                child: Text(
                  'Chưa có khoản chi phát sinh trong kỳ này.',
                  textAlign: TextAlign.center,
                  style: OmniType.caption.copyWith(color: p.muted),
                ),
              )
            else
              for (var i = 0; i < rows.length; i++)
                _buildDimensionRowItem(p, rows[i], rank: i),
          ],
        ),
      ],
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
            color: p.primary,
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
      for (final entry in byAccount.entries) {
        final items = entry.value;
        final amt = items.fold<int>(0, (s, e) => s + e.amount);
        final share = (amt / totalSpend) * 100;
        list.add(
          _SummaryDimensionRow(
            id: entry.key,
            name: accountNames[entry.key] ?? 'Nguồn khác',
            color: p.primary,
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

  Widget _buildDimensionRowItem(
    FinancePalette p,
    _SummaryDimensionRow row, {
    required int rank,
  }) {
    final ratio = (row.sharePct / 100).clamp(0.0, 1.0);
    final barAlpha = rank == 0 ? 1.0 : (rank == 1 ? 0.72 : 0.48);
    final icon = _dimension == SummaryDimension.group
        ? Icons.category_outlined
        : Icons.account_balance_wallet_outlined;
    return InkWell(
      key: ValueKey('finance-summary-row-${row.id}'),
      onTap: () => _openDimensionDrilldownSheet(row),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OmniIconTile(icon, color: p.primary, background: p.primarySoft),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          row.name,
                          maxLines: 2,
                          style: OmniType.bodyStrong.copyWith(color: p.ink),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        FinanceMonthUtils.formatVndSpace(row.amount),
                        maxLines: 1,
                        style: OmniType.bodyStrong.copyWith(
                          color: p.ink,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${row.countLabel} · '
                    '${row.sharePct.toStringAsFixed(1).replaceAll('.', ',')}%',
                    maxLines: 1,
                    style: OmniType.caption.copyWith(
                      color: p.muted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: SizedBox(
                      height: 4,
                      child: LinearProgressIndicator(
                        value: ratio,
                        backgroundColor: p.control,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          p.primary.withValues(alpha: barAlpha),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDimensionDrilldownSheet(_SummaryDimensionRow row) async {
    final p = FinancePalette.of(context);
    final sorted = List<ExpenseItem>.from(row.items)
      ..sort((a, b) => b.spentOn.compareTo(a.spentOn));
    final icon = _dimension == SummaryDimension.group
        ? Icons.category_outlined
        : Icons.account_balance_wallet_outlined;

    await showOmniSheet<void>(
      context: context,
      maxHeight: MediaQuery.sizeOf(context).height * 0.78,
      builder: (ctx) {
        return OmniSheetBody(
          semanticsLabel: row.name,
          header: OmniSheetHeader(
            title: row.name,
            subtitle:
                '${row.countLabel} · ${FinanceMonthUtils.formatVndSpace(row.amount)}',
            leading: OmniIconTile(
              icon,
              color: p.primary,
              background: p.primarySoft,
            ),
            trailing: OmniGlassCircle(
              child: IconButton(
                tooltip: 'Đóng',
                onPressed: () => Navigator.of(ctx).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ),
          // Các khoản gom trong MỘT nhóm lồng, không từng thẻ viền.
          children: [
            Material(
              color: p.card,
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < sorted.length; i++)
                    ExpenseRowTile(
                      item: sorted[i],
                      showBottomDivider: i < sorted.length - 1,
                      isFlashed: false,
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Sheet chọn kỳ tổng hợp: chip năm (đổi tại chỗ) rồi chip quý / tháng (chạm
/// là chọn và đóng). Chế độ Năm: chạm năm là chọn.
class _PeriodPickerSheet extends StatefulWidget {
  const _PeriodPickerSheet({
    required this.scope,
    required this.years,
    required this.year,
    required this.part,
  });

  final ExpenseSummaryScope scope;
  final List<int> years;
  final int year;

  /// Tháng (1–12) hoặc quý (1–4) đang chọn; 0 ở chế độ Năm.
  final int part;

  @override
  State<_PeriodPickerSheet> createState() => _PeriodPickerSheetState();
}

class _PeriodPickerSheetState extends State<_PeriodPickerSheet> {
  late int _year = widget.year;

  void _pick(int part) => Navigator.of(context).pop((year: _year, part: part));

  @override
  Widget build(BuildContext context) {
    final years = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final y in widget.years)
          OmniChoicePill(
            key: ValueKey('finance-summary-year-chip-$y'),
            label: 'Năm $y',
            selected: y == _year,
            onTap: widget.scope == ExpenseSummaryScope.year
                ? () => Navigator.of(context).pop((year: y, part: 0))
                : () => setState(() => _year = y),
          ),
      ],
    );
    final sameYear = _year == widget.year;
    final parts = switch (widget.scope) {
      ExpenseSummaryScope.year => null,
      ExpenseSummaryScope.quarter => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var q = 1; q <= 4; q++)
            OmniChoicePill(
              key: ValueKey('finance-summary-quarter-$q'),
              label: 'Quý $q',
              selected: sameYear && q == widget.part,
              onTap: () => _pick(q),
            ),
        ],
      ),
      ExpenseSummaryScope.month => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var m = 1; m <= 12; m++)
            OmniChoicePill(
              key: ValueKey('finance-summary-month-chip-$m'),
              label: 'Tháng $m',
              selected: sameYear && m == widget.part,
              onTap: () => _pick(m),
            ),
        ],
      ),
    };

    return OmniSheetBody(
      header: OmniSheetHeader(
        title: 'Chọn kỳ',
        trailing: OmniGlassCircle(
          child: IconButton(
            tooltip: 'Đóng',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            icon: const Icon(Icons.close_rounded, size: OmniIconSize.md),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
      ),
      children: [
        OmniGroupSection(
          title: 'Năm',
          children: [Padding(padding: const EdgeInsets.all(14), child: years)],
        ),
        if (parts != null)
          OmniGroupSection(
            title: widget.scope == ExpenseSummaryScope.quarter
                ? 'Quý'
                : 'Tháng',
            children: [
              Padding(padding: const EdgeInsets.all(14), child: parts),
            ],
          ),
      ],
    );
  }
}
