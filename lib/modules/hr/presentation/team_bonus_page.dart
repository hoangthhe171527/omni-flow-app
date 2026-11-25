import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/components/components.dart';
import '../application/hr_providers.dart';
import '../domain/hr_format.dart';
import '../domain/hr_models.dart';
import 'widgets/hr_ui.dart';
import 'widgets/team_kpi_card.dart';

/// Màn **Thưởng đội** (spec 02 §6): Tháng này / Tháng trước; thẻ tiến độ đội,
/// phần của tôi (tổ, hệ số, ngày công), tiêu chuẩn hoàn thiện.
class TeamBonusPage extends ConsumerStatefulWidget {
  const TeamBonusPage({super.key});

  @override
  ConsumerState<TeamBonusPage> createState() => _TeamBonusPageState();
}

class _TeamBonusPageState extends ConsumerState<TeamBonusPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final thisMonth = ref.watch(hrThisMonthProvider);
    final period = _tab == 0 ? thisMonth : HrFormat.shiftMonth(thisMonth, -1);
    final data = ref.watch(hrKpiMeProvider(period));

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const OmniTopBar(allowBack: true, semanticsTitle: 'Thưởng đội'),
      body: OmniTopBarOverlap.wrap(
        child: Builder(
          builder: (context) {
            final top = OmniTopBarOverlap.of(context);
            return RefreshIndicator.adaptive(
              edgeOffset: top,
              onRefresh: () async {
                ref.invalidate(hrKpiMeProvider(period));
                await ref
                    .read(hrKpiMeProvider(period).future)
                    .then((_) {}, onError: (_) {});
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: hrListPadding(context, top),
                children: [
                  OmniSegmented(
                    labels: const ['Tháng này', 'Tháng trước'],
                    index: _tab,
                    onChanged: (i) => setState(() => _tab = i),
                  ),
                  const SizedBox(height: OmniGroupSection.gap),
                  ...switch (data) {
                    AsyncData(:final value) when value == null => const [
                      OmniEmptyState(
                        icon: Icons.groups_outlined,
                        title: 'Bạn chưa thuộc đội nào',
                      ),
                    ],
                    AsyncData(:final value) => _content(value!, period),
                    AsyncError(:final error) when !data.isLoading => [
                      OmniErrorView(
                        error: error,
                        onRetry: () => ref.invalidate(hrKpiMeProvider(period)),
                      ),
                    ],
                    _ => const [OmniSkeletonBox(height: 280, radius: 18)],
                  },
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _content(KpiMe kpi, String period) {
    final mine = kpi.mine;
    final nextMonth = HrFormat.monthShort(period);
    return [
      TeamKpiCard(kpi: kpi),
      if (mine != null) ...[
        const SizedBox(height: OmniGroupSection.gap),
        OmniGroupSection(
          title: 'Phần của tôi',
          children: [
            HrStatRow(
              title: kpi.closed ? 'Thưởng' : 'Thưởng tạm tính',
              value: HrFormat.money(mine.amount),
              strong: true,
            ),
            if (mine.squad != null)
              HrStatRow(
                title: 'Tổ',
                value: '${mine.squad} · hệ số ${HrFormat.decimal(mine.weight)}',
              ),
            HrStatRow(
              title: 'Ngày công',
              value: HrFormat.decimal(mine.workdays),
            ),
          ],
        ),
      ],
      if (kpi.standards.isNotEmpty) ...[
        const SizedBox(height: OmniGroupSection.gap),
        OmniGroupSection(
          title: 'Tiêu chuẩn hoàn thiện',
          children: [
            for (final s in kpi.standards)
              OmniGroupRow(icon: Icons.check_rounded, title: s),
          ],
        ),
      ],
      if (!kpi.closed)
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
          child: Text(
            'Chốt ngày 1–3 tháng sau, vào phiếu lương tháng $nextMonth',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
    ];
  }
}
