import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../application/opportunities_providers.dart';
import '../../domain/opportunity.dart';
import '../../opportunities_module.dart';
import 'stage_picker_sheet.dart';

class OpportunityCard extends ConsumerWidget {
  const OpportunityCard({
    super.key,
    required this.opportunity,
    this.canMove = false,
  });

  final Opportunity opportunity;
  final bool canMove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return OmniCard(
      onTap: () => context.pushNamed(
        OpportunitiesModule.detail,
        pathParameters: {'id': opportunity.id},
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      opportunity.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: OmniType.bodyStrong.copyWith(color: scheme.onSurface),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      opportunity.customerName ?? 'Chưa gắn khách hàng',
                      style: OmniType.caption.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: OmniSpacing.sm),
              Text(
                Formatters.vnd(opportunity.value),
                style: OmniType.money.copyWith(color: scheme.onSurface),
              ),
            ],
          ),
          const SizedBox(height: OmniSpacing.md),
          Row(
            children: [
              _ProbabilityBar(value: opportunity.effectiveProbability),
              const SizedBox(width: OmniSpacing.md),
              if (opportunity.expectedCloseAt != null)
                OmniTag(
                  label: Formatters.date(opportunity.expectedCloseAt),
                  icon: Icons.event_outlined,
                  tone: opportunity.isOverdue ? OmniColors.destructive : null,
                ),
              const Spacer(),
              OmniSourcePill(channel: opportunity.source, compact: true),
              if (opportunity.ownerName != null) ...[
                const SizedBox(width: OmniSpacing.sm),
                OmniAvatar(name: opportunity.ownerName!, size: 22),
              ],
            ],
          ),
          if (canMove) ...[
            const SizedBox(height: OmniSpacing.md),
            Divider(height: 1, color: scheme.outline),
            const SizedBox(height: OmniSpacing.sm),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _moveStage(context, ref),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 17),
                  label: const Text('Đổi giai đoạn'),
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: OmniSpacing.sm),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _moveStage(BuildContext context, WidgetRef ref) async {
    final stage = await showOmniSheet<PipelineStage>(
      context: context,
      builder: (_) => StagePickerSheet(current: opportunity.stage),
    );
    if (stage == null || stage == opportunity.stage) return;

    try {
      await moveOpportunityStage(ref, opportunity.id, stage);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã chuyển sang "${stage.label}".')),
      );
    } on AppException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class _ProbabilityBar extends StatelessWidget {
  const _ProbabilityBar({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 46,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: value / 100,
              minHeight: 5,
              backgroundColor: scheme.surfaceContainerHighest,
              color: value >= 70
                  ? OmniColors.success
                  : (value >= 40 ? OmniColors.info : OmniColors.warning),
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          '$value%',
          style: OmniType.micro.copyWith(
            color: scheme.onSurfaceVariant,
            fontFeatures: OmniType.tabular,
          ),
        ),
      ],
    );
  }
}
