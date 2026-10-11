import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../application/plans_providers.dart';
import '../domain/plan.dart';
import '../domain/workshop_kpi.dart';
import 'edit_sections_page.dart';
import 'widgets/kpi_card.dart';

/// Báo cáo một kế hoạch (menu kế hoạch, nhóm 2).
///
/// Hai nguồn, đều có sẵn ở API:
///  * khối số từ `plan.stats` (`MongoProjectRepository::attachStats`): tổng,
///    xong, trễ, tiến độ;
///  * `KpiCard` từ `GET /tasks/kpi?project_id=&month=`, lùi / tới theo tháng
///    như thẻ KPI ở Dòng việc.
///
/// `/tasks/stats` không lọc theo kế hoạch nên không dùng.
class PlanReportPage extends ConsumerStatefulWidget {
  const PlanReportPage({
    super.key,
    required this.planId,
    this.canConfigure = false,
  });

  final String planId;

  /// Quản lý kế hoạch: KPI chưa cấu hình thì chạm để mở "Sắp xếp nhóm việc"
  /// (đánh dấu nhóm đích). null: không có lối đó.
  final bool canConfigure;

  @override
  ConsumerState<PlanReportPage> createState() => _PlanReportPageState();
}

class _PlanReportPageState extends ConsumerState<PlanReportPage> {
  /// Tháng đang xem, luôn ngày 1. Sống theo màn: mỗi lần mở là tháng này.
  late DateTime _month = _thisMonth();

  /// Thẻ KPI vừa hiện (tháng của nó và số tháng trước). Đổi tháng thì thẻ
  /// này đứng lại, mờ, tới khi tháng mới về — không để một khoảng trống
  /// 132 px nhảy lên rồi nhảy xuống.
  ({WorkshopKpi kpi, DateTime month, int? previous})? _shown;

  /// Đổi tháng. Chụp thẻ đang hiện vào [_shown] NGAY LÚC ĐỔI (không ghi
  /// state trong build): tháng mới còn tải thì thẻ này đứng mờ thay chỗ.
  void _go(int delta, WorkshopKpi data, int? previous) => setState(() {
    _shown = (kpi: data, month: _month, previous: previous);
    _month = DateTime(_month.year, _month.month + delta);
  });

  static DateTime _thisMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(planProvider(widget.planId));

    return Scaffold(
      appBar: AppBar(title: const Text('Báo cáo kế hoạch')),
      body: OmniAsyncView(
        value: plan,
        onRetry: () => ref.invalidate(planProvider(widget.planId)),
        data: (plan) => ListView(
          padding: const EdgeInsets.fromLTRB(
            OmniSpacing.lg,
            OmniSpacing.md,
            OmniSpacing.lg,
            OmniSpacing.bottomSafe,
          ),
          children: [
            _StatsBlock(plan: plan),
            const SizedBox(height: OmniSpacing.lg),
            _kpi(),
          ],
        ),
      ),
    );
  }

  Widget _kpi() {
    final key = (planId: widget.planId, month: _month);
    final kpi = ref.watch(planKpiProvider(key));
    final previous = ref.watch(
      planKpiProvider((
        planId: widget.planId,
        month: DateTime(_month.year, _month.month - 1),
      )),
    );
    final current = _thisMonth();
    final atCurrent =
        _month.year == current.year && _month.month == current.month;

    return kpi.when(
      data: (data) {
        final before = previous.valueOrNull?.delivered;

        return KpiCard(
          kpi: data,
          month: _month,
          previousDelivered: previous.valueOrNull?.delivered,
          onPrevMonth: () => _go(-1, data, before),
          // Không đi tới tương lai: tháng chưa tới luôn ra 0.
          onNextMonth: atCurrent ? null : () => _go(1, data, before),
          onConfigure: widget.canConfigure
              ? () => Navigator.of(context).push(
                  MaterialPageRoute<bool>(
                    builder: (_) => EditSectionsPage(planId: widget.planId),
                  ),
                )
              : null,
        );
      },
      loading: () {
        final shown = _shown;
        if (shown == null) return const SizedBox(height: 132);

        return IgnorePointer(
          child: Opacity(
            opacity: 0.5,
            child: KpiCard(
              kpi: shown.kpi,
              month: shown.month,
              previousDelivered: shown.previous,
            ),
          ),
        );
      },
      error: (error, _) => SizedBox(
        height: 240,
        child: OmniErrorView(
          error: error,
          onRetry: () => ref.invalidate(planKpiProvider(key)),
        ),
      ),
    );
  }
}

/// Bốn ô số: tổng / xong / trễ / tiến độ.
class _StatsBlock extends StatelessWidget {
  const _StatsBlock({required this.plan});

  final Plan plan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final danger = OmniTaskTones.of(context).highPriority.foreground;
    final cells = [
      ('plan-report-total', 'Tổng việc', '${plan.taskCount}', null),
      ('plan-report-done', 'Xong', '${plan.doneCount}', null),
      (
        'plan-report-overdue',
        'Trễ hạn',
        '${plan.overdueCount}',
        plan.overdueCount > 0 ? danger : null,
      ),
      (
        'plan-report-progress',
        'Tiến độ',
        '${(plan.progress * 100).round()}%',
        null,
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          for (final (key, label, value, color) in cells)
            Expanded(
              child: Semantics(
                container: true,
                label: '$label: $value',
                excludeSemantics: true,
                child: Column(
                  key: Key(key),
                  children: [
                    Text(
                      value,
                      style: OmniType.title.copyWith(
                        color: color ?? scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: OmniType.micro.copyWith(
                        fontWeight: FontWeight.w400,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
