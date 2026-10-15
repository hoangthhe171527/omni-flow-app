import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../design/components/components.dart';
import '../../../../design/platform/omni_motion_scope.dart';
import '../../../../design/tokens/tokens.dart';
import '../../application/plans_providers.dart';
import '../../domain/plan.dart';
import 'plan_tile.dart';

/// Một team gập/mở được: section phẳng, đầu nhóm 48 (biểu tượng team, tên,
/// "N kế hoạch", mũi tên xoay 180° khi mở), rồi
/// các dòng kế hoạch.
///
/// [plans] là danh sách ĐÃ LỌC theo ô tìm; "N kế hoạch" luôn đếm cả team.
/// Hiện ra bằng `rise`, lệch 50ms theo [index].
class TeamGroup extends StatelessWidget {
  const TeamGroup({
    super.key,
    required this.group,
    required this.plans,
    required this.open,
    required this.onToggle,
    required this.onOpenPlan,
    this.closed = const [],
    this.closedOpen = false,
    this.onToggleClosed,
    this.onLongPress,
    this.onLongPressPlan,
    this.canLongPressPlan,
    this.index = 0,
    this.rise = true,
    this.favoriteOf,
    this.onToggleFavorite,
  });

  final TeamWithPlans group;
  final List<Plan> plans;
  final bool open;
  final VoidCallback onToggle;
  final ValueChanged<Plan> onOpenPlan;

  /// Kế hoạch đã đóng / lưu trữ ĐÃ LỌC theo ô tìm, hiện dưới dòng
  /// "Đã đóng (N)" (N đếm cả team) khi [closedOpen].
  final List<Plan> closed;
  final bool closedOpen;
  final VoidCallback? onToggleClosed;

  /// Bấm giữ đầu nhóm: "Tuỳ chọn team" (Xoá team). Null thì không có.
  final VoidCallback? onLongPress;

  /// Bấm giữ một kế hoạch: mở thẳng thao tác của chính kế hoạch đó.
  final ValueChanged<Plan>? onLongPressPlan;

  /// Quyền long-press có thể khác nhau theo từng kế hoạch trong cùng team.
  final bool Function(Plan plan)? canLongPressPlan;
  final int index;

  /// false = hiện ngay. Tab Việc chỉ cho nhóm "rise" ở lần dựng ĐẦU của màn;
  /// danh sách lười dựng lại nhóm khi cuộn về, và phát lại lúc đó đọc như giật.
  final bool rise;

  /// Sao đang hiện của một kế hoạch (đã áp lượt bấm lạc quan); null = theo
  /// `Plan.isFavorite`.
  final bool? Function(Plan plan)? favoriteOf;

  /// Bấm sao (Nhóm 2). null = không có sao (API cũ hoặc không bấm được).
  final ValueChanged<Plan>? onToggleFavorite;

  Widget _tile(Plan plan) {
    final canOpenActions =
        onLongPressPlan != null && (canLongPressPlan?.call(plan) ?? true);
    return PlanTile(
      plan: plan,
      nested: true,
      onTap: () => onOpenPlan(plan),
      favorite: favoriteOf?.call(plan),
      onLongPress: canOpenActions ? () => onLongPressPlan!(plan) : null,
      onToggleFavorite: onToggleFavorite == null
          ? null
          : () => onToggleFavorite!(plan),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motion = OmniMotion.enabled(context);
    return OmniRise(
      // Trần 6 bước: nhóm thứ 20 không phải chờ cả giây mới hiện.
      delay: OmniRise.step * math.min(index, 6),
      animate: rise,
      child: Material(
        color: scheme.surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              button: true,
              expanded: open,
              onLongPressHint: onLongPress == null ? null : 'Tuỳ chọn team',
              child: OmniPressScale(
                child: InkWell(
                  onTap: onToggle,
                  onLongPress: onLongPress,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.fromLTRB(16, 0, 10, 0),
                    color: scheme.surfaceContainerLow.withValues(alpha: .55),
                    child: Row(
                      children: [
                        ExcludeSemantics(
                          child: Icon(
                            Icons.groups_2_outlined,
                            key: const Key('team-group-icon'),
                            size: OmniIconSize.md,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            group.team.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: OmniType.bodyStrong.copyWith(
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${group.plans.length} kế hoạch',
                          style: OmniType.micro.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox.square(
                          dimension: 44,
                          child: AnimatedRotation(
                            turns: open ? 0.5 : 0,
                            duration: motion
                                ? const Duration(milliseconds: 300)
                                : Duration.zero,
                            curve: OmniCurves.standard,
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: OmniIconSize.md,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (open) ...[
              for (final plan in plans) _tile(plan),
              if (group.closedPlans.isNotEmpty)
                _ClosedToggle(
                  count: group.closedPlans.length,
                  open: closedOpen,
                  onTap: onToggleClosed,
                ),
              if (closedOpen)
                for (final plan in closed) _tile(plan),
              if (group.plans.isEmpty && group.closedPlans.isEmpty)
                // Nói rõ là rỗng: một đầu nhóm không có gì bên dưới đọc như
                // lỗi tải. Cũng là chỗ duy nhất team rỗng còn hiện để xoá.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(40, 14, 16, 14),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: scheme.surfaceContainerHighest),
                    ),
                  ),
                  child: Text(
                    'Team này chưa có kế hoạch nào.',
                    textAlign: TextAlign.center,
                    style: OmniType.caption.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Dòng "Đã đóng (N)" cuối khối team: gập mặc định, chạm để mở các kế hoạch
/// đã đóng / lưu trữ. Mờ hơn dòng kế hoạch: đây là kho, không phải việc đang
/// chạy.
class _ClosedToggle extends StatelessWidget {
  const _ClosedToggle({required this.count, required this.open, this.onTap});

  final int count;
  final bool open;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motion = OmniMotion.enabled(context);

    return Semantics(
      button: true,
      expanded: open,
      child: InkWell(
        onTap: onTap,
        child: Container(
          key: const Key('team-closed-toggle'),
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.fromLTRB(40, 0, 6, 0),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: scheme.surfaceContainerHighest),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: OmniIconSize.sm,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Đã đóng ($count)',
                  style: OmniType.caption.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              SizedBox.square(
                dimension: 44,
                child: AnimatedRotation(
                  turns: open ? 0.5 : 0,
                  duration: motion
                      ? const Duration(milliseconds: 300)
                      : Duration.zero,
                  curve: OmniCurves.standard,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: OmniIconSize.md,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
