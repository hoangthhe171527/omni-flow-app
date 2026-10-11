import 'package:flutter/material.dart';

import '../../../../design/components/components.dart';
import '../../../../design/platform/omni_motion_scope.dart';
import '../../../../design/tokens/tokens.dart';
import '../../domain/plan.dart';
import 'plan_tile.dart';

/// Một kế hoạch yêu thích kèm tên team của nó ("Team · N việc").
typedef FavoritePlan = ({Plan plan, String teamName});

/// Mục "Yêu thích" đầu tab Việc (`Main.dc.html`, Nhóm 2): khung `.grp`, đầu
/// nhóm 48 với sao 20 màu `star`, "Yêu thích", số, mũi tên xoay 180° khi mở;
/// mỗi dòng như dòng kế hoạch nhưng dòng phụ là "Team · N việc" và cuối dòng
/// là › (bỏ sao ở dòng của team).
///
/// Chỉ dựng khi có ít nhất một kế hoạch yêu thích — API cũ không có
/// `is_favorite` nên không bao giờ tới đây.
class FavoritesGroup extends StatelessWidget {
  const FavoritesGroup({
    super.key,
    required this.favorites,
    required this.open,
    required this.onToggle,
    required this.onOpenPlan,
    this.rise = true,
  });

  final List<FavoritePlan> favorites;
  final bool open;
  final VoidCallback onToggle;
  final ValueChanged<Plan> onOpenPlan;

  /// Như [TeamGroup.rise]: chỉ khung đầu của màn.
  final bool rise;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tones = OmniTaskTones.of(context);
    final motion = OmniMotion.enabled(context);

    return OmniRise(
      animate: rise,
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              button: true,
              expanded: open,
              child: OmniPressScale(
                child: InkWell(
                  key: const Key('favorites-header'),
                  onTap: onToggle,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.fromLTRB(12, 0, 6, 0),
                    child: Row(
                      children: [
                        Icon(Icons.star_rounded, size: 20, color: tones.star),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Yêu thích',
                            style: OmniType.bodyStrong.copyWith(
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                        Text(
                          '${favorites.length}',
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
            if (open)
              for (final f in favorites)
                PlanTile(
                  key: ValueKey('favorite-${f.plan.id}'),
                  plan: f.plan,
                  subtitle:
                      '${f.teamName} · '
                      '${(f.plan.taskCount - f.plan.doneCount).clamp(0, 1 << 30)}'
                      ' việc',
                  onTap: () => onOpenPlan(f.plan),
                ),
          ],
        ),
      ),
    );
  }
}
