import 'package:flutter/material.dart';

import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../domain/plan.dart';

/// Một dự án trong danh sách của team (`SMProjectsTasks.dc.html`, nửa "Đề
/// xuất").
///
/// Định danh của dự án là một Ô VUÔNG màu nền dự án cạnh tên — không còn đầu
/// thẻ tô gradient 64px với vòng quỹ đạo: trong màn làm việc đó là trang trí,
/// và một danh sách năm thẻ thành năm khối màu đậm. Bên dưới, ba con số theo
/// đúng thứ tự người quản đốc hỏi: đi được bao xa, còn bao nhiêu, có gì đang
/// trễ. Trễ là thứ duy nhất được tô màu — nếu tô cả ba thì không cái nào nổi.
class PlanRow extends StatelessWidget {
  const PlanRow({super.key, required this.plan, this.onTap});

  final Plan plan;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    final counts = [
      if (plan.taskCount == 0)
        'Chưa có việc nào'
      else
        'Xong ${plan.doneCount}/${plan.taskCount}',
      if (plan.sections.isNotEmpty) '${plan.sections.length} nhóm việc',
    ].join(' · ');

    return Material(
      color: scheme.surface,
      borderRadius: OmniRadius.xlAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: OmniRadius.xlAll,
            border: Border.all(color: scheme.outlineVariant),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  PlanSwatch(cover: plan.cover, size: 10),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      plan.name,
                      style: OmniType.section.copyWith(color: scheme.onSurface),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: OmniSpacing.sm),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: OmniIconSize.md,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              OmniProgressBar(value: plan.progress),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      counts,
                      style: OmniType.caption.copyWith(
                        color: dark
                            ? scheme.onSurfaceVariant
                            : OmniColors.secondaryForeground,
                        fontFeatures: OmniType.tabular,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (plan.overdueCount > 0) ...[
                    const SizedBox(width: OmniSpacing.sm),
                    OmniBadge(
                      label: 'Trễ ${plan.overdueCount}',
                      tone: OmniTone.danger,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ô vuông màu dự án — định danh duy nhất còn mang màu của dự án trong màn
/// làm việc. Màu lấy từ TÊN nền (`cover`), nên dự án tạo trước tính năng nền
/// vẫn có ô, màu mặc định.
class PlanSwatch extends StatelessWidget {
  const PlanSwatch({super.key, required this.cover, this.size = 8});

  final String? cover;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: OmniCovers.colorOf(cover),
        borderRadius: const BorderRadius.all(Radius.circular(2)),
      ),
    );
  }
}
