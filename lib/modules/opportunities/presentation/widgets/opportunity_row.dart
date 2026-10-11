import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../application/opportunities_providers.dart';
import '../../domain/opportunity.dart';
import '../../domain/pipeline_catalog.dart';
import '../../opportunities_module.dart';
import 'stage_picker_sheet.dart';
import 'stage_strip.dart';

/// Dòng cơ hội của đoạn "Cơ hội": vòng % ở trái, tên + "khách · hạn" ở giữa,
/// giá trị và tên giai đoạn bên phải. Chạm mở chi tiết; bấm giữ đổi giai đoạn
/// khi [canMove].
class OpportunityRow extends ConsumerWidget {
  const OpportunityRow({
    super.key,
    required this.opportunity,
    required this.pipeline,
    this.canMove = false,
  });

  final Opportunity opportunity;
  final PipelineDef? pipeline;
  final bool canMove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final stage = pipeline?.stage(opportunity.stageCode);
    final rawColor = stageColorOf(stage, scheme);
    // Cung vòng cần 3:1, chữ tên giai đoạn cần 4.5:1 trên nền dòng.
    final arcColor = readableStageColor(rawColor, scheme.surface, minRatio: 3);
    final textColor = readableStageColor(rawColor, scheme.surface);
    final overdue = opportunity.isOverdue;
    final due = opportunity.expectedCloseAt;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: InkWell(
        onTap: () => context.pushNamed(
          OpportunitiesModule.detail,
          pathParameters: {'id': opportunity.id},
        ),
        onLongPress: canMove ? () => _moveStage(context, ref) : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
            child: Row(
              children: [
                OmniProgressRing(
                  percent: opportunity.displayPercent(pipeline),
                  color: arcColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        opportunity.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          opportunity.customerName ?? 'Chưa gắn khách hàng',
                          if (due != null) 'Hạn ${Formatters.dayMonth(due)}',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: OmniType.micro.copyWith(
                          color: overdue
                              ? scheme.error
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Formatters.vndCompact(opportunity.value),
                      style: OmniType.bodyStrong.copyWith(
                        color: scheme.onSurface,
                        fontFeatures: OmniType.tabular,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stage?.label ?? opportunity.stageCode,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: OmniType.micro.copyWith(color: textColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _moveStage(BuildContext context, WidgetRef ref) async {
    // Dòng có thể bị dựng lại (danh sách nạp lại) trước khi người dùng chọn
    // xong: giữ những thứ cần sau `await` từ trước.
    final messenger = ScaffoldMessenger.of(context);
    final actions = ref.read(opportunityActionsProvider);
    try {
      final stage = await pickOpportunityStage(context, ref, opportunity);
      if (stage == null) return;
      await actions.moveStage(opportunity, stage.code);
      messenger.showSnackBar(
        SnackBar(content: Text('Đã chuyển sang "${stage.label}".')),
      );
    } on AppException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}
