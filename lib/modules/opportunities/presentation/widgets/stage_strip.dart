import 'package:flutter/material.dart';

import '../../../../design/components/components.dart';
import '../../../../design/tokens/contrast.dart';
import '../../domain/opportunity.dart';
import '../../domain/pipeline_catalog.dart';

/// Màu giai đoạn do web cấu hình (`#rrggbb`); thiếu hoặc sai → màu chính.
Color stageColorOf(PipelineStageDef? stage, ColorScheme scheme) {
  final hex = stage?.color?.trim().replaceFirst('#', '');
  if (hex == null || hex.length != 6) return scheme.primary;
  final value = int.tryParse(hex, radix: 16);
  return value == null ? scheme.primary : Color(value).withAlpha(255);
}

/// [color] pha dần về đen (nền sáng) hoặc trắng (nền tối) cho tới khi đạt
/// [minRatio] so với [surface]: 4.5 cho chữ, 3 cho cung vòng và vạch đáy
/// (WCAG 1.4.3 / 1.4.11). Màu đã đủ tương phản thì giữ nguyên — màu web cấu
/// hình như vàng #FACC15 sẽ không đọc được trên nền trắng nếu dùng thô.
Color readableStageColor(Color color, Color surface, {double minRatio = 4.5}) {
  if (contrastRatio(color, surface) >= minRatio) return color;
  final toward = surface.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  for (var t = 0.05; t <= 1.0001; t += 0.05) {
    final mixed = Color.lerp(color, toward, t)!;
    if (contrastRatio(mixed, surface) >= minRatio) return mixed;
  }
  return toward;
}

/// Dải chip kính lọc theo giai đoạn (rà soát 12/11): "Tất cả n" rồi mỗi giai
/// đoạn một chip "tên n". Chạm chip để lọc, chạm lại chip đang chọn (hoặc
/// "Tất cả") để bỏ lọc. Nhiều giai đoạn thì dải cuộn ngang.
class StageStrip extends StatelessWidget {
  const StageStrip({
    super.key,
    required this.stages,
    required this.summary,
    required this.selected,
    required this.onSelected,
    this.showAll = true,
    this.allCount,
  });

  /// Các giai đoạn hiện trên dải (mở, hoặc đóng khi xem "Đã đóng").
  final List<PipelineStageDef> stages;
  final PipelineSummary? summary;

  /// Mã giai đoạn đang lọc; null = không lọc.
  final String? selected;

  /// Gọi với mã vừa chạm, hoặc null khi chạm lại chip đang chọn / "Tất cả".
  final ValueChanged<String?> onSelected;

  /// Có chip "Tất cả" ở đầu dải.
  final bool showAll;

  /// Số trên chip "Tất cả"; null thì chỉ hiện chữ.
  final int? allCount;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          if (showAll)
            _StageChip(
              label: 'Tất cả',
              count: allCount,
              semanticsLabel: 'Tất cả, ${allCount ?? 0} cơ hội',
              selected: selected == null,
              // Rung nhẹ đã có trong OmniFilterPill.
              onTap: () => onSelected(null),
            ),
          for (final stage in stages)
            _StageChip(
              label: stage.label,
              count: summary?.totalFor(stage.code).count ?? 0,
              semanticsLabel:
                  '${stage.label}, ${summary?.totalFor(stage.code).count ?? 0} cơ hội',
              selected: stage.code == selected,
              onTap: () =>
                  onSelected(stage.code == selected ? null : stage.code),
            ),
        ],
      ),
    );
  }
}

/// Chip lọc giai đoạn = [OmniFilterPill] (viên mực đặc khi chọn — D12),
/// giữ nhãn trợ năng "tên, n cơ hội".
class _StageChip extends StatelessWidget {
  const _StageChip({
    required this.label,
    required this.count,
    required this.semanticsLabel,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int? count;
  final String semanticsLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        selected: selected,
        label: semanticsLabel,
        onTap: onTap,
        excludeSemantics: true,
        child: OmniFilterPill(
          label: label,
          count: count,
          selected: selected,
          onTap: onTap,
        ),
      ),
    );
  }
}
