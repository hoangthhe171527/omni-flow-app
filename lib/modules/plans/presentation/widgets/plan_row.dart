import 'package:flutter/material.dart';

import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../domain/plan.dart';

/// Một dự án trong thẻ của team (`Tasks.dc.html`, nửa `isPlans`).
///
/// Định danh là ô màu nền dự án 34px bo 8. Bên cạnh: tên, meta "N nhóm việc ·
/// M việc", và một thanh 4px ba đoạn dựng từ số THẬT của API — xong (màu
/// chính), trễ (cam), còn lại (xám). API chỉ có `stats.total/done/overdue`
/// chứ không đếm theo nhóm việc, nên thanh không chia theo nhóm: chia theo
/// nhóm là bịa số. Trễ là thứ duy nhất có chip riêng — tô cả ba thì không cái
/// nào nổi.
class PlanRow extends StatelessWidget {
  const PlanRow({super.key, required this.plan, this.onTap});

  final Plan plan;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final meta =
        '${plan.sections.length} nhóm việc · '
        '${plan.taskCount == 0 ? 'Chưa có việc' : '${plan.taskCount} việc'}';
    // Phần còn lại không âm: dữ liệu lệch (xong + trễ > tổng) không được làm
    // `Expanded(flex: âm)` ném lỗi dựng.
    final open = (plan.taskCount - plan.doneCount - plan.overdueCount).clamp(
      0,
      1 << 30,
    );

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                key: const Key('plan-row-swatch'),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: OmniCovers.colorOf(plan.cover),
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(2)),
                      child: SizedBox(
                        key: const Key('plan-row-bar'),
                        height: 4,
                        child: plan.taskCount == 0
                            ? ColoredBox(color: OmniColors.trackOf(context))
                            : Row(
                                children: [
                                  if (plan.doneCount > 0)
                                    Expanded(
                                      flex: plan.doneCount,
                                      child: ColoredBox(color: scheme.primary),
                                    ),
                                  if (plan.overdueCount > 0) ...[
                                    if (plan.doneCount > 0)
                                      const SizedBox(width: 2),
                                    Expanded(
                                      flex: plan.overdueCount,
                                      child: ColoredBox(
                                        color: OmniTaskTones.of(
                                          context,
                                        ).dueSoonBar,
                                      ),
                                    ),
                                  ],
                                  if (open > 0) ...[
                                    if (plan.doneCount > 0 ||
                                        plan.overdueCount > 0)
                                      const SizedBox(width: 2),
                                    Expanded(
                                      flex: open,
                                      child: ColoredBox(
                                        color: OmniColors.mutedBarOf(context),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              if (plan.overdueCount > 0) ...[
                const SizedBox(width: 8),
                OmniTaskChip.late('Trễ ${plan.overdueCount}'),
              ],
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: OmniTaskTones.of(context).none.foreground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
