import 'package:flutter/material.dart';

import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../domain/plan.dart';

/// Một dự án trong danh sách của team.
///
/// Ba con số, theo đúng thứ tự người quản đốc hỏi: đi được bao xa, còn bao
/// nhiêu, có gì đang trễ. Trễ là thứ duy nhất được tô màu — nếu tô cả ba thì
/// không cái nào nổi.
class PlanRow extends StatelessWidget {
  const PlanRow({super.key, required this.plan, this.onTap});

  final Plan plan;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Material(
      color: scheme.surface,
      borderRadius: OmniRadius.lgAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: OmniRadius.lgAll,
            border: Border.all(color: scheme.outlineVariant),
          ),
          padding: const EdgeInsets.all(OmniSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      plan.name,
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (plan.sections.isNotEmpty) ...[
                    const SizedBox(width: OmniSpacing.sm),
                    Text(
                      '${plan.sections.length} nhóm việc',
                      style: text.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: OmniSpacing.md),
              // Thanh tiến độ là ĐỒ HOẠ, nên nó được dùng màu success gốc —
              // đứng một mình, không cạnh chữ nào cùng tông.
              ClipRRect(
                borderRadius: BorderRadius.circular(OmniRadius.chip / 2),
                child: LinearProgressIndicator(
                  value: plan.progress,
                  minHeight: 6,
                  backgroundColor: scheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(scheme.primary),
                ),
              ),
              const SizedBox(height: OmniSpacing.sm),
              Row(
                children: [
                  Text(
                    plan.taskCount == 0
                        ? 'Chưa có việc nào'
                        : 'Xong ${plan.doneCount}/${plan.taskCount}',
                    style: text.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontFeatures: OmniType.tabular,
                    ),
                  ),
                  const Spacer(),
                  if (plan.overdueCount > 0)
                    OmniStatusChip(
                      icon: Icons.error_outline_rounded,
                      label: 'Trễ ${plan.overdueCount}',
                      tone: OmniTone.danger,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
