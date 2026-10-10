import 'package:flutter/material.dart';

import '../platform/omni_motion_scope.dart';
import '../tokens/tokens.dart';

/// Thanh chọn đoạn: 2–N nhãn, một con trượt nền sáng chạy tới đoạn đang chọn.
///
/// Cao tổng 44: mỗi đoạn có vùng chạm cao đủ 44, con trượt vẽ cao 30 ở giữa.
class OmniSegmented extends StatelessWidget {
  const OmniSegmented({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final n = labels.length;
    if (n == 0) return const SizedBox.shrink();
    final sel = index.clamp(0, n - 1);
    final align = n == 1 ? 0.0 : -1 + 2 * sel / (n - 1);

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: SizedBox(
            height: 44,
            child: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedAlign(
                    alignment: Alignment(align, 0),
                    duration: OmniMotion.enabled(context)
                        ? const Duration(milliseconds: 350)
                        : Duration.zero,
                    curve: OmniCurves.standard,
                    child: FractionallySizedBox(
                      widthFactor: 1 / n,
                      heightFactor: 30 / 44,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: scheme.shadow.withValues(alpha: 0.12),
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < n; i++)
                      Expanded(
                        child: Semantics(
                          button: true,
                          selected: i == sel,
                          label: labels[i],
                          onTap: () => onChanged(i),
                          excludeSemantics: true,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(4),
                            onTap: () => onChanged(i),
                            child: Center(
                              child: Text(
                                labels[i],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.labelLarge?.copyWith(
                                  color: i == sel
                                      ? scheme.onSurface
                                      : scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
