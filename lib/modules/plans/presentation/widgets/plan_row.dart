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
      borderRadius: _radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: _radius,
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Nền dự án LÀ đầu thẻ, và tên nằm trong nó (`MProjects.dc.html`
              // cao 64, một vòng quỹ đạo mảnh ở góc phải). Chữ trắng: mọi nền
              // trong `OmniCovers` đều đạt 4,5:1 với trắng.
              Container(
                constraints: const BoxConstraints(minHeight: 64),
                decoration: BoxDecoration(
                  gradient: OmniCovers.gradientOf(plan.cover),
                ),
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned(
                      right: -30,
                      top: -40,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.16),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: OmniSpacing.lg,
                        vertical: 18,
                      ),
                      child: Text(
                        plan.name,
                        style: OmniType.section.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: OmniRadius.pillAll,
                      child: LinearProgressIndicator(
                        value: plan.progress,
                        minHeight: 6,
                        backgroundColor: scheme.surfaceContainerHighest,
                        // Màu đồ hoạ của bộ Orbit.
                        valueColor: AlwaysStoppedAnimation(
                          dark ? scheme.primary : OmniColors.orbit,
                        ),
                      ),
                    ),
                    const SizedBox(height: OmniSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            counts,
                            style: OmniType.caption.copyWith(
                              fontWeight: FontWeight.w400,
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
            ],
          ),
        ),
      ),
    );
  }
}

const _radius = BorderRadius.all(Radius.circular(18));
