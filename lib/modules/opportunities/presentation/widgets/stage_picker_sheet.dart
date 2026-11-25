import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../design/components/components.dart';
import '../../application/opportunities_providers.dart';
import '../../domain/opportunity.dart';
import '../../domain/pipeline_catalog.dart';
import 'stage_strip.dart';

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
///
/// Liquid: giai đoạn làm việc là một nhóm lồng; Chốt / Thất bại là kết quả
/// nên tách nhóm riêng bên dưới. Giai đoạn hiện tại = dấu ✓, không tô nền.
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
    final working = [
      for (final stage in pipeline.stages)
        if (!stage.isClosed) stage,
    ];
    final outcomes = [
      for (final stage in pipeline.stages)
        if (stage.isClosed) stage,
    ];

    OmniGroupRow row(PipelineStageDef stage) {
      final won = stage.outcome == StageOutcome.won;
      final dotColor = readableStageColor(
        stageColorOf(stage, scheme),
        scheme.surface,
        minRatio: 3,
      );
      return OmniGroupRow(
        leading: !stage.isClosed
            ? SizedBox(
                width: 28,
                height: 28,
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox(width: 10, height: 10),
                  ),
                ),
              )
            : null,
        icon: !stage.isClosed
            ? null
            : won
            ? LucideIcons.trophy
            : LucideIcons.circleX,
        title: stage.label,
        subtitle: stage.probability == null
            ? null
            : 'Xác suất mặc định ${stage.probability}%',
        selected: stage.code == currentCode,
        chevron: false,
        onTap: () => Navigator.pop(context, stage.code),
      );
    }

    return OmniSheetBody(
      // Đầu sheet tự có nút ✕ tròn xám (spec phong cách iOS §3.4).
      header: const OmniSheetHeader(title: 'Chuyển giai đoạn'),
      children: [
        OmniGroupSection(children: [for (final stage in working) row(stage)]),
        OmniGroupSection(children: [for (final stage in outcomes) row(stage)]),
      ],
    );
  }
}
