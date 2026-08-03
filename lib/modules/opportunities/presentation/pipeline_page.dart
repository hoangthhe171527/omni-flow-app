import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../application/opportunities_providers.dart';
import '../domain/opportunity.dart';
import '../opportunities_module.dart';
import 'widgets/opportunity_card.dart';

/// The pipeline as a mobile board: one stage at a time, with the totals for
/// every stage always visible in the tab strip.
///
/// A desktop kanban doesn't survive a 390pt screen — six columns become six
/// unreadable slivers. Stage tabs keep the same mental model while giving each
/// card room to be read and acted on.
class PipelinePage extends ConsumerWidget {
  const PipelinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stage = ref.watch(selectedStageProvider);
    final summary = ref.watch(pipelineSummaryProvider);
    final opportunities = ref.watch(stageOpportunitiesProvider(stage));
    final access = ref.watch(opportunityAccessProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cơ hội'),
        titleSpacing: OmniSpacing.lg,
      ),
      floatingActionButton: access.canCreate
          ? FloatingActionButton.extended(
              onPressed: () => context.pushNamed(OpportunitiesModule.create),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Cơ hội mới'),
            )
          : null,
      body: Column(
        children: [
          _SummaryStrip(summary: summary.valueOrNull),
          _StageTabs(
            selected: stage,
            summary: summary.valueOrNull,
            onSelected: (next) =>
                ref.read(selectedStageProvider.notifier).state = next,
          ),
          Divider(height: 1, color: scheme.outline),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(pipelineSummaryProvider);
                ref.invalidate(stageOpportunitiesProvider(stage));
              },
              child: OmniAsyncView(
                value: opportunities,
                onRetry: () => ref.invalidate(stageOpportunitiesProvider(stage)),
                isEmpty: (list) => list.isEmpty,
                empty: OmniEmptyState(
                  icon: Icons.trending_up_rounded,
                  title: 'Chưa có cơ hội ở "${stage.label}"',
                  message: 'Cơ hội chuyển sang giai đoạn này sẽ hiện ở đây.',
                ),
                data: (list) => ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    OmniSpacing.lg,
                    OmniSpacing.md,
                    OmniSpacing.lg,
                    OmniSpacing.bottomSafe,
                  ),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: OmniSpacing.sm),
                  itemBuilder: (context, index) => OpportunityCard(
                    opportunity: list[index],
                    canMove: access.canUpdate,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({this.summary});

  final PipelineSummary? summary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.lg,
        0,
        OmniSpacing.lg,
        OmniSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: OmniStatTile(
              label: 'Pipeline đang mở',
              value: Formatters.vndCompact(summary?.openValue ?? 0),
              caption: '${summary?.openCount ?? 0} cơ hội',
            ),
          ),
          const SizedBox(width: OmniSpacing.sm),
          Expanded(
            child: OmniStatTile(
              label: 'Đã thắng',
              value: Formatters.vndCompact(
                summary?.totalFor(PipelineStage.won).value ?? 0,
              ),
              tone: OmniColors.success,
              caption: '${summary?.totalFor(PipelineStage.won).count ?? 0} cơ hội',
            ),
          ),
        ],
      ),
    );
  }
}

class _StageTabs extends StatelessWidget {
  const _StageTabs({
    required this.selected,
    required this.onSelected,
    this.summary,
  });

  final PipelineStage selected;
  final ValueChanged<PipelineStage> onSelected;
  final PipelineSummary? summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 62,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: OmniSpacing.lg),
        itemCount: PipelineStage.board.length,
        separatorBuilder: (_, _) => const SizedBox(width: OmniSpacing.sm),
        itemBuilder: (context, index) {
          final stage = PipelineStage.board[index];
          final total = summary?.totalFor(stage);
          final isSelected = stage == selected;

          return GestureDetector(
            onTap: () => onSelected(stage),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: OmniSpacing.md),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isSelected ? scheme.primary : Colors.transparent,
                    width: 2.5,
                  ),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        stage.label,
                        style: OmniType.caption.copyWith(
                          color: isSelected ? scheme.primary : scheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (total != null) ...[
                        const SizedBox(width: 5),
                        Text(
                          '${total.count}',
                          style: OmniType.micro.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontFeatures: OmniType.tabular,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Formatters.vndCompact(total?.value ?? 0),
                    style: OmniType.micro.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontFeatures: OmniType.tabular,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
