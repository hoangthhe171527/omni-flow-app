import 'package:flutter/material.dart';

import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../domain/plan.dart';
import 'project_cover.dart';

/// Một kế hoạch trong nhóm team (`Main.dc.html .pl`): dòng 48, vạch trên, dấu
/// cover nhỏ (không giả làm avatar), tên w500, "N việc đang mở", "N trễ" đỏ.
///
/// Ô 44 bên phải là sao Yêu thích (Nhóm 2) khi API gửi `is_favorite` và có
/// [onToggleFavorite]: sao 19, tô `star` khi bật, viền `faint` khi tắt.
/// Thiếu một trong hai thì ô là mũi tên › mờ, như dòng ở mục Yêu thích.
class PlanTile extends StatelessWidget {
  const PlanTile({
    super.key,
    required this.plan,
    this.onTap,
    this.favorite,
    this.onToggleFavorite,
    this.subtitle,
  });

  final Plan plan;
  final VoidCallback? onTap;

  /// Trạng thái sao đang hiện (đã áp lượt bấm lạc quan); null = theo [plan].
  final bool? favorite;
  final VoidCallback? onToggleFavorite;

  /// Thay dòng "N việc đang mở" (mục Yêu thích: "Team · N việc").
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tones = OmniTaskTones.of(context);
    final open = (plan.taskCount - plan.doneCount).clamp(0, 1 << 30);
    final fav = favorite ?? plan.isFavorite;
    // Đã đóng / lưu trữ: mờ đi và mang nhãn trạng thái thay cho số trễ.
    final closedLabel = switch (plan.planStatus) {
      PlanStatus.active => null,
      PlanStatus.done => 'Đã đóng',
      PlanStatus.archived => 'Lưu trữ',
    };

    final tile = OmniPressScale(
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: scheme.surfaceContainerHighest),
            ),
          ),
          child: Row(
            children: [
              ProjectCoverMarker(
                markerKey: const Key('plan-tile-swatch'),
                cover: plan.cover,
                color: plan.color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: OmniType.bodySm.copyWith(
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurface,
                      ),
                    ),
                    Text(
                      subtitle ?? '$open việc đang mở',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: OmniType.micro.copyWith(
                        fontWeight: FontWeight.w400,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (closedLabel != null) ...[
                const SizedBox(width: 10),
                Text(
                  closedLabel,
                  style: OmniType.micro.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ] else if (plan.overdueCount > 0) ...[
                const SizedBox(width: 10),
                Text(
                  '${plan.overdueCount} trễ',
                  style: OmniType.micro.copyWith(
                    fontWeight: FontWeight.w600,
                    color: tones.highPriority.foreground,
                  ),
                ),
              ],
              const SizedBox(width: 10),
              if (fav != null && onToggleFavorite != null)
                Semantics(
                  // Nút riêng trong dòng: không gộp vào nhãn của cả dòng.
                  container: true,
                  button: true,
                  toggled: fav,
                  label: fav ? 'Bỏ khỏi yêu thích' : 'Thêm vào yêu thích',
                  excludeSemantics: true,
                  child: InkWell(
                    key: Key('plan-favorite-${plan.id}'),
                    onTap: onToggleFavorite,
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox.square(
                      dimension: 44,
                      child: Icon(
                        fav ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 19,
                        color: fav ? tones.star : tones.faint,
                      ),
                    ),
                  ),
                )
              else
                SizedBox.square(
                  dimension: 44,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: tones.faint,
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (closedLabel == null) return tile;

    return Opacity(
      key: const Key('plan-tile-closed'),
      opacity: 0.6,
      child: tile,
    );
  }
}
