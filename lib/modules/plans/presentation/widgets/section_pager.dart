import 'package:flutter/material.dart';

import '../../../../design/platform/omni_motion_scope.dart';
import '../../../../design/tokens/tokens.dart';
import '../../domain/plan.dart';

/// Dải chấm trang: đang ở nhóm việc nào, và nhảy thẳng tới nhóm khác.
///
/// Vuốt bốn lần để tới cột cuối là bốn lần quá nhiều. Dải này chạm được, nên
/// khoảng cách giữa hai công đoạn bất kỳ luôn là một cú chạm.
class SectionIndicator extends StatelessWidget {
  const SectionIndicator({
    super.key,
    required this.sections,
    required this.current,
    required this.onSelected,
    this.countOf,
  });

  final List<PlanSection> sections;
  final int current;
  final ValueChanged<int> onSelected;

  /// Số việc trong một nhóm, để hiện cạnh tên nhóm đang mở.
  final int Function(int index)? countOf;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final count = countOf?.call(current);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: OmniSpacing.lg),
            itemCount: sections.length,
            separatorBuilder: (_, _) => const SizedBox(width: OmniSpacing.xs),
            itemBuilder: (context, index) {
              final selected = index == current;

              return Center(
                child: Semantics(
                  button: true,
                  selected: selected,
                  label: sections[index].name,
                  child: InkWell(
                    onTap: () => onSelected(index),
                    borderRadius: OmniRadius.pillAll,
                    // Vùng chạm 44dp cho một cái chấm 8dp: cái cần lớn là chỗ
                    // ngón tay chạm, không phải cái chấm trên màn hình.
                    child: SizedBox(
                      width: 28,
                      height: 44,
                      child: Center(
                        child: AnimatedContainer(
                          duration: OmniMotion.of(context).fast,
                          width: selected ? 22 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: selected
                                ? scheme.primary
                                : scheme.outlineVariant,
                            borderRadius: OmniRadius.pillAll,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            OmniSpacing.lg,
            0,
            OmniSpacing.lg,
            OmniSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  sections.isEmpty ? '' : sections[current].name,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (count != null)
                Text(
                  '$count việc',
                  style: text.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontFeatures: OmniType.tabular,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
