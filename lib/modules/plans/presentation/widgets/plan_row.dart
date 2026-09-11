import 'package:flutter/material.dart';

import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../domain/plan.dart';

/// Một dự án trong danh sách của team.
///
/// Khối đầu thẻ là nền dự án ôm lấy tên — đúng cái người tạo đã thấy ở ô xem
/// trước lúc chọn nền. Bên dưới, ba con số theo đúng thứ tự người quản đốc
/// hỏi: đi được bao xa, còn bao nhiêu, có gì đang trễ. Trễ là thứ duy nhất
/// được tô màu — nếu tô cả ba thì không cái nào nổi.
class PlanRow extends StatelessWidget {
  const PlanRow({super.key, required this.plan, this.onTap});

  final Plan plan;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final counts = [
      if (plan.taskCount == 0)
        'Chưa có việc nào'
      else
        'Xong ${plan.doneCount}/${plan.taskCount}',
      if (plan.sections.isNotEmpty) '${plan.sections.length} nhóm việc',
    ].join(' · ');

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Nền dự án LÀ đầu thẻ, và tên nằm trong nó. Bản đầu vẽ nền
              // thành một vạch 6dp ngay trên thanh tiến độ — cùng bề dày,
              // cùng bo góc — và nó đọc như một thanh tiến độ thứ hai.
              //
              // Chữ trắng: mọi nền trong `OmniCovers` đều đạt 4,5:1 với
              // trắng, `omni_covers_test.dart` giữ điều đó. `plan.cover` null
              // với mọi dự án tạo trước tính năng — `gradientOf` tự rơi về
              // nền mặc định, nên danh sách không có hai kiểu thẻ lẫn nhau.
              Container(
                constraints: const BoxConstraints(minHeight: 56),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(
                  horizontal: OmniSpacing.lg,
                  vertical: OmniSpacing.md,
                ),
                decoration: BoxDecoration(
                  gradient: OmniCovers.gradientOf(plan.cover),
                ),
                child: Text(
                  plan.name,
                  style: text.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(OmniSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                        Expanded(
                          child: Text(
                            counts,
                            style: text.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontFeatures: OmniType.tabular,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (plan.overdueCount > 0) ...[
                          const SizedBox(width: OmniSpacing.sm),
                          OmniStatusChip(
                            icon: Icons.error_outline_rounded,
                            label: 'Trễ ${plan.overdueCount}',
                            tone: OmniTone.danger,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
