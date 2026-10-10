import 'package:flutter/material.dart';

import '../../../../design/platform/omni_motion_scope.dart';
import '../../../../design/tokens/tokens.dart';
import '../../domain/opportunity.dart';
import '../../domain/pipeline_catalog.dart';

/// Màu giai đoạn do web cấu hình (`#rrggbb`); thiếu hoặc sai → màu chính.
Color stageColorOf(PipelineStageDef? stage, ColorScheme scheme) {
  final hex = stage?.color?.trim().replaceFirst('#', '');
  if (hex == null || hex.length != 6) return scheme.primary;
  final value = int.tryParse(hex, radix: 16);
  return value == null ? scheme.primary : Color(0xFF000000 | value);
}

/// Dải ô giai đoạn (`Customers.dc.html`): mỗi ô một số đếm, nhãn và vạch đáy
/// màu giai đoạn. Chạm ô để lọc, chạm lại để bỏ lọc. Quá 4 giai đoạn thì dải
/// cuộn ngang, ô rộng bằng một phần tư.
class StageStrip extends StatelessWidget {
  const StageStrip({
    super.key,
    required this.stages,
    required this.summary,
    required this.selected,
    required this.onSelected,
  });

  /// Chỉ các giai đoạn mở.
  final List<PipelineStageDef> stages;
  final PipelineSummary? summary;

  /// Mã giai đoạn đang lọc; null = không lọc.
  final String? selected;

  /// Gọi với mã vừa chạm, hoặc null khi chạm lại ô đang chọn.
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.sizeOf(context).width - 32) / 4;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final stage in stages)
            SizedBox(
              width: width,
              child: _StageTile(
                stage: stage,
                count: summary?.totalFor(stage.code).count,
                filtering: selected != null,
                isSelected: stage.code == selected,
                onTap: () =>
                    onSelected(stage.code == selected ? null : stage.code),
              ),
            ),
        ],
      ),
    );
  }
}

class _StageTile extends StatelessWidget {
  const _StageTile({
    required this.stage,
    required this.count,
    required this.filtering,
    required this.isSelected,
    required this.onTap,
  });

  final PipelineStageDef stage;
  final int? count;
  final bool filtering;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motion = OmniMotion.enabled(context);
    final duration = motion ? const Duration(milliseconds: 250) : Duration.zero;
    final dimmed = filtering && !isSelected;

    return Semantics(
      button: true,
      selected: isSelected,
      label: '${stage.label}, ${count ?? 0} cơ hội',
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: AnimatedOpacity(
          opacity: dimmed ? 0.45 : 1,
          duration: duration,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${count ?? 0}',
                  style: OmniType.money.copyWith(color: scheme.onSurface),
                ),
                Text(
                  stage.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OmniType.micro.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                TweenAnimationBuilder<double>(
                  tween: Tween(end: dimmed ? 0.35 : 1),
                  duration: duration,
                  builder: (context, scaleX, child) => Transform(
                    alignment: Alignment.centerLeft,
                    transform: Matrix4.diagonal3Values(scaleX, 1, 1),
                    child: child,
                  ),
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: stageColorOf(stage, scheme),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Phần trăm hiển thị trên vòng của một cơ hội: giai đoạn thắng = 100; còn lại
/// xác suất đặt trên cơ hội, rồi mặc định của giai đoạn, rồi 0.
int opportunityPercent(Opportunity opportunity, PipelineStageDef? stage) {
  if (opportunity.isWon) return 100;
  return opportunity.probability ?? stage?.probability ?? 0;
}
