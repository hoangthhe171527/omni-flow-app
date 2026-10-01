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
      appBar: OmniAppBar(
        backgroundColor: scheme.surface,
        title: 'Cơ hội',
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
                  style: OmniType.money.copyWith(
                    height: 1.1,
                    color: scheme.onSurface,
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
          preferredSize: const Size.fromHeight(51),
          child: Column(
            children: [
              _StageTabs(
                selected: stage,
                summary: summary.valueOrNull,
                onSelected: (next) =>
                    ref.read(selectedStageProvider.notifier).state = next,
              ),
              Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
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
      body: Column(
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
                  message: 'Cơ hội chuyển sang giai đoạn này sẽ hiện ở đây.',
                ),
                data: (list) => ListView.separated(
                  padding: const EdgeInsets.only(
                    bottom: OmniSpacing.bottomSafe,
                  ),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    thickness: 1,
                    indent: 0,
                    endIndent: 0,
                    color: scheme.outlineVariant,
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
    final dark = Theme.of(context).brightness == Brightness.dark;

    // Cùng kiểu viên với hộp thư (`MPipeline.dc.html`): viên đang chọn là
    // khối mực, và chỉ nó mang thêm TỔNG TIỀN của giai đoạn — màu quỹ đạo
    // sáng. Người bán đọc tiền của giai đoạn mình đang đứng, không phải cả hàng.
    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 2),
        itemCount: PipelineStage.board.length,
        separatorBuilder: (_, _) => const SizedBox(width: OmniSpacing.sm),
        itemBuilder: (context, index) {
          final stage = PipelineStage.board[index];
          final total = summary?.totalFor(stage);
          final isSelected = stage == selected;
          final hasCount = total != null && total.count > 0;
          final foreground = isSelected
              ? (dark ? scheme.surface : Colors.white)
              : scheme.onSurface;

          return Center(
            child: Material(
              color: isSelected
                  ? (dark ? scheme.onSurface : OmniColors.ink)
                  : scheme.surfaceContainerHighest,
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onSelected(stage),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 34),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: stage.label),
                        if (hasCount) TextSpan(text: ' ${total.count}'),
                        if (hasCount && isSelected)
                          TextSpan(
                            text: ' · ${Formatters.vndCompact(total.value)}',
                            style: TextStyle(
                              color: dark
                                  ? OmniColors.primary
                                  : OmniColors.orbit,
                            ),
                          ),
                      ],
                    ),
                    style: OmniType.caption.copyWith(
                      height: 1.2,
                      color: foreground,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                      fontFeatures: OmniType.tabular,
                    ),
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
