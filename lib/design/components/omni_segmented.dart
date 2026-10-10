import 'package:flutter/material.dart';

import '../platform/omni_motion_scope.dart';
import '../tokens/tokens.dart';

/// Thanh chọn đoạn: 2–N nhãn, một con trượt nền sáng chạy tới đoạn đang chọn.
///
/// Cao tổng 44: đoạn vẽ cao 30, vùng chạm nới thêm 4 mỗi phía (+3 đệm ngoài).
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
    final align = n == 1 ? 0.0 : -1 + 2 * index / (n - 1);

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: SizedBox(
            height: 38,
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
                      heightFactor: 30 / 38,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1F0B1A33),
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
                          selected: i == index,
                          label: labels[i],
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
                                  color: i == index
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
