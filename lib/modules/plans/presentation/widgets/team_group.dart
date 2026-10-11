import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../design/components/components.dart';
import '../../../../design/platform/omni_motion_scope.dart';
import '../../../../design/tokens/tokens.dart';
import '../../application/plans_providers.dart';
import '../../domain/plan.dart';
import 'plan_tile.dart';

/// Một team gập/mở được (`Main.dc.html .grp`): khung surface viền bo 8, đầu
/// nhóm 48 (ô 28 màu team, tên, "N kế hoạch", mũi tên xoay 180° khi mở), rồi
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
    this.onLongPress,
    this.index = 0,
    this.rise = true,
  });

  final TeamWithPlans group;
  final List<Plan> plans;
  final bool open;
  final VoidCallback onToggle;
  final ValueChanged<Plan> onOpenPlan;

  /// Bấm giữ đầu nhóm: "Tuỳ chọn team" (Xoá team). Null thì không có.
  final VoidCallback? onLongPress;
  final int index;

  /// false = hiện ngay. Tab Việc chỉ cho nhóm "rise" ở lần dựng ĐẦU của màn;
  /// danh sách lười dựng lại nhóm khi cuộn về, và phát lại lúc đó đọc như giật.
  final bool rise;

  /// Màu ô của team: `color` do server lưu, thiếu hay sai thì xám phụ.
  static Color colorOf(String? raw) {
    return OmniLabelColors.tryParseHex(raw) ?? OmniColors.mutedForeground;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motion = OmniMotion.enabled(context);
    const radius = BorderRadius.all(Radius.circular(8));

    return OmniRise(
      // Trần 6 bước: nhóm thứ 20 không phải chờ cả giây mới hiện.
      delay: OmniRise.step * math.min(index, 6),
      animate: rise,
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
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
                    padding: const EdgeInsets.fromLTRB(12, 0, 6, 0),
                    child: Row(
                      children: [
                        InitialTile(
                          tileKey: const Key('team-group-swatch'),
                          name: group.team.name,
                          color: colorOf(group.team.color),
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
                              size: 18,
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
              for (final plan in plans)
                PlanTile(plan: plan, onTap: () => onOpenPlan(plan)),
              if (group.plans.isEmpty)
                // Nói rõ là rỗng: một đầu nhóm không có gì bên dưới đọc như
                // lỗi tải. Cũng là chỗ duy nhất team rỗng còn hiện để xoá.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
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
