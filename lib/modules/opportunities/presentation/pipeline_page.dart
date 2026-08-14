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
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        title: const Text('Cơ hội'),
        titleSpacing: OmniSpacing.lg,
        toolbarHeight: 56,
        // The headline number lives in the bar. It used to be one of two big
        // stat tiles in a band of its own, above a two-line tab strip that
        // already carried every stage's count and value — roughly 150px of
        // summary before a single opportunity appeared, most of it saying the
        // same thing twice.
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: OmniSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Formatters.vndCompact(summary.valueOrNull?.openValue ?? 0),
                  style: OmniType.body.copyWith(
                    fontSize: 16,
                    height: 1.1,
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                    fontFeatures: OmniType.tabular,
                  ),
                ),
                Text(
                  'đang mở',
                  style: OmniChatType.meta.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(
            children: [
              _StageTabs(
                selected: stage,
                summary: summary.valueOrNull,
                onSelected: (next) =>
                    ref.read(selectedStageProvider.notifier).state = next,
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: OmniColors.chat(
                  context,
                  OmniColors.chatDivider,
                  OmniColors.chatDividerDark,
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: access.canCreate
          ? FloatingActionButton.extended(
              onPressed: () => context.pushNamed(OpportunitiesModule.create),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Cơ hội mới'),
            )
          : null,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 1100) {
            return _DesktopPipeline(canMove: access.canUpdate);
          }
          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(pipelineSummaryProvider);
                    ref.invalidate(stageOpportunitiesProvider(stage));
                  },
                  child: OmniAsyncView(
                    value: opportunities,
                    onRetry: () =>
                        ref.invalidate(stageOpportunitiesProvider(stage)),
                    isEmpty: (list) => list.isEmpty,
                    empty: OmniEmptyState(
                      icon: Icons.trending_up_rounded,
                      title: 'Chưa có cơ hội ở "${stage.label}"',
                      message:
                          'Cơ hội chuyển sang giai đoạn này sẽ hiện ở đây.',
                    ),
                    data: (list) => ListView.separated(
                      padding: const EdgeInsets.only(
                        bottom: OmniSpacing.bottomSafe,
                      ),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        thickness: 1,
                        indent: 16,
                        endIndent: 16,
                        color: OmniColors.chat(
                          context,
                          OmniColors.chatDivider,
                          OmniColors.chatDividerDark,
                        ),
                      ),
                      itemBuilder: (context, index) => OpportunityCard(
                        opportunity: list[index],
                        canMove: access.canUpdate,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DesktopPipeline extends ConsumerWidget {
  const _DesktopPipeline({required this.canMove});

  final bool canMove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OmniDesktopFrame(
      maxWidth: 1680,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final stage in PipelineStage.board) ...[
            Expanded(
              child: _DesktopStage(stage: stage, canMove: canMove),
            ),
            if (stage != PipelineStage.board.last) const SizedBox(width: 14),
          ],
        ],
      ),
    );
  }
}

class _DesktopStage extends ConsumerWidget {
  const _DesktopStage({required this.stage, required this.canMove});

  final PipelineStage stage;
  final bool canMove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final opportunities = ref.watch(stageOpportunitiesProvider(stage));
    return Container(
      constraints: const BoxConstraints(minHeight: 420),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .38),
        borderRadius: OmniRadius.lgAll,
      ),
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Row(
              children: [
                Expanded(child: Text(stage.label, style: OmniType.bodyStrong)),
                opportunities.when(
                  data: (items) => Text(
                    '${items.length}',
                    style: OmniType.micro.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  loading: () => const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
                  error: (_, _) => const Icon(Icons.error_outline, size: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: opportunities.when(
              data: (items) => items.isEmpty
                  ? Center(
                      child: Text(
                        'Chưa có cơ hội',
                        style: OmniType.micro.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => OpportunityCard(
                        opportunity: items[index],
                        canMove: canMove,
                      ),
                    ),
              loading: () => const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (error, _) => Center(
                child: Icon(
                  Icons.cloud_off_outlined,
                  color: scheme.onSurfaceVariant,
                ),
              ),
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

    // One line of pills, matching the inbox filter row. Two stacked lines per
    // tab meant every stage permanently showed a value nobody was looking at —
    // a rep reads the money for the stage they are IN. So the value appears
    // only on the selected pill, which costs no extra height at all.
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: PipelineStage.board.length,
        separatorBuilder: (_, _) => const SizedBox(width: OmniSpacing.sm),
        itemBuilder: (context, index) {
          final stage = PipelineStage.board[index];
          final total = summary?.totalFor(stage);
          final isSelected = stage == selected;

          return Center(
            child: Material(
              color: isSelected ? OmniColors.chatPrimary : Colors.transparent,
              borderRadius: OmniRadius.pillAll,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onSelected(stage),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        stage.label,
                        style: OmniType.caption.copyWith(
                          fontSize: 13.5,
                          height: 1.1,
                          color: isSelected
                              ? Colors.white
                              : scheme.onSurfaceVariant,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      if (total != null && total.count > 0) ...[
                        const SizedBox(width: 5),
                        Text(
                          isSelected
                              ? '${total.count} · ${Formatters.vndCompact(total.value)}'
                              : '${total.count}',
                          style: OmniType.caption.copyWith(
                            fontSize: 13.5,
                            height: 1.1,
                            color:
                                (isSelected
                                        ? Colors.white
                                        : scheme.onSurfaceVariant)
                                    .withValues(alpha: 0.7),
                            fontWeight: FontWeight.w600,
                            fontFeatures: OmniType.tabular,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
