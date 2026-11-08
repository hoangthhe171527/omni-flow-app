import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../platform/omni_motion_scope.dart';
import '../tokens/tokens.dart';
import 'omni_glass.dart';

/// Bộ chọn đoạn kính (viomni-apple-uiux.html `.seg.glass`): viên kính dạng
/// viên thuốc, thấu kính trắng mờ ([OmniGlassLens]) trượt tới đoạn đang chọn,
/// chữ đoạn chọn màu chủ đạo w600.
///
/// Cao tổng 44: mỗi đoạn có vùng chạm cao đủ 44, thấu kính cao 36 ở giữa.
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
    final motion = OmniMotion.enabled(context);

    void pick(int i) {
      if (i != sel) HapticFeedback.selectionClick();
      onChanged(i);
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: OmniGlass(
        radius: 22,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SizedBox(
            height: 44,
            child: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedAlign(
                    alignment: Alignment(align, 0),
                    duration: motion
                        ? const Duration(milliseconds: 420)
                        : Duration.zero,
                    // Cùng đường cong "nảy" của thấu kính thanh tab.
                    curve: const Cubic(0.34, 1.36, 0.64, 1),
                    child: FractionallySizedBox(
                      widthFactor: 1 / n,
                      heightFactor: 36 / 44,
                      child: const OmniGlassLens(),
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
                          onTap: () => pick(i),
                          excludeSemantics: true,
                          // Không gợn sóng: kính đổi chọn bằng thấu kính trượt.
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => pick(i),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: AnimatedDefaultTextStyle(
                                  duration: motion
                                      ? OmniDuration.base
                                      : Duration.zero,
                                  style: (text.labelLarge ?? const TextStyle())
                                      .copyWith(
                                        color: i == sel
                                            ? scheme.primary
                                            : scheme.onSurfaceVariant,
                                        fontWeight: i == sel
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                      ),
                                  child: Text(
                                    labels[i],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
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
