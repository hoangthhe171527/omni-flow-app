import 'package:flutter/material.dart';

import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../domain/opportunity.dart';

class StagePickerSheet extends StatelessWidget {
  const StagePickerSheet({super.key, required this.current});

  final PipelineStage current;

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
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
          ),
          for (final stage in PipelineStage.board)
            _StageRow(
              stage: stage,
              selected: stage == current,
              onTap: () => Navigator.pop(context, stage),
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

  final PipelineStage stage;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final outcome = stage == PipelineStage.won || stage == PipelineStage.lost;
    final (
      outcomeFg,
      outcomeBg,
    ) = (stage == PipelineStage.won ? OmniTone.warning : OmniTone.neutral).of(
      context,
    );

    final Widget marker = outcome
        ? Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: outcomeBg, shape: BoxShape.circle),
            child: Icon(
              stage == PipelineStage.won
                  ? Icons.emoji_events_outlined
                  : Icons.cancel_outlined,
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
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: selected
                            ? scheme.onPrimaryContainer
                            : scheme.onSurface,
                      ),
                    ),
                    Text(
                      'Xác suất mặc định ${stage.defaultProbability}%',
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
