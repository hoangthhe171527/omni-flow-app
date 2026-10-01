import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../application/opportunities_providers.dart';
import '../../domain/opportunity.dart';
import '../../domain/pipeline_catalog.dart';

/// Mở [StagePickerSheet] với quy trình CỦA cơ hội. Trả về giai đoạn mới, hoặc
/// null khi người dùng đóng sheet hay chọn lại giai đoạn đang đứng.
Future<PipelineStageDef?> pickOpportunityStage(
  BuildContext context,
  WidgetRef ref,
  Opportunity opportunity,
) async {
  final catalog = await ref.read(pipelineCatalogProvider.future);
  if (!context.mounted) return null;
  final pipeline = catalog.pipelineOf(opportunity.pipelineCode);
  final code = await showOmniSheet<String>(
    context: context,
    builder: (_) => StagePickerSheet(
      pipeline: pipeline,
      currentCode: opportunity.stageCode,
    ),
  );
  if (code == null || code == opportunity.stageCode) return null;
  return pipeline.stage(code);
}

/// Chọn giai đoạn trong quy trình của cơ hội; trả về MÃ giai đoạn.
class StagePickerSheet extends StatelessWidget {
  const StagePickerSheet({
    super.key,
    required this.pipeline,
    required this.currentCode,
  });

  final PipelineDef pipeline;
  final String currentCode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // `MStagePicker.dc.html`: tiêu đề 20/800; giai đoạn làm việc là vòng
    // rỗng, giai đoạn hiện tại viền dày màu chính và dòng tô mòng két nhạt;
    // Thắng/Thua là ô tròn có icon (vàng / xám).
    return Padding(
      padding: const EdgeInsets.only(bottom: OmniSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(
              'Chuyển giai đoạn',
              style: OmniType.navTitle.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ),
          for (final stage in pipeline.stages)
            _StageRow(
              stage: stage,
              selected: stage.code == currentCode,
              onTap: () => Navigator.pop(context, stage.code),
            ),
        ],
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.stage,
    required this.selected,
    required this.onTap,
  });

  final PipelineStageDef stage;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final outcome = stage.isClosed;
    final won = stage.outcome == StageOutcome.won;
    final (outcomeFg, outcomeBg) = (won ? OmniTone.warning : OmniTone.neutral)
        .of(context);

    final Widget marker = outcome
        ? Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: outcomeBg, shape: BoxShape.circle),
            child: Icon(
              won ? Icons.emoji_events_outlined : Icons.cancel_outlined,
              size: OmniIconSize.md,
              color: outcomeFg,
            ),
          )
        : Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? scheme.primary : scheme.outlineVariant,
                width: selected ? 3 : 2,
              ),
            ),
          );

    return Material(
      color: selected
          ? scheme.primary.withValues(alpha: 0.05)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              marker,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stage.label,
                      style: OmniType.listTitle.copyWith(
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: selected
                            ? scheme.onPrimaryContainer
                            : scheme.onSurface,
                      ),
                    ),
                    if (stage.probability case final probability?)
                      Text(
                        'Xác suất mặc định $probability%',
                        style: OmniType.caption.copyWith(
                          fontWeight: FontWeight.w400,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_rounded, color: scheme.onPrimaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}
