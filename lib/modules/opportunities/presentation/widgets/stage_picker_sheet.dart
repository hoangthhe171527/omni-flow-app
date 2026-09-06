import 'package:flutter/material.dart';

import '../../../../design/tokens/tokens.dart';
import '../../domain/opportunity.dart';

class StagePickerSheet extends StatelessWidget {
  const StagePickerSheet({super.key, required this.current});

  final PipelineStage current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.lg,
        0,
        OmniSpacing.lg,
        OmniSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chuyển giai đoạn',
            style: OmniType.section.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: OmniSpacing.md),
          for (final stage in PipelineStage.board)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: stage == current
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  switch (stage) {
                    PipelineStage.won => Icons.emoji_events_outlined,
                    PipelineStage.lost => Icons.cancel_outlined,
                    _ => Icons.circle_outlined,
                  },
                  size: OmniIconSize.sm,
                  color: stage == current
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                ),
              ),
              title: Text(
                stage.label,
                style: OmniType.caption.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Xác suất mặc định ${stage.defaultProbability}%',
                style: OmniType.micro.copyWith(color: scheme.onSurfaceVariant),
              ),
              trailing: stage == current
                  ? Icon(Icons.check_circle_rounded, color: scheme.primary)
                  : null,
              onTap: () => Navigator.pop(context, stage),
            ),
        ],
      ),
    );
  }
}
