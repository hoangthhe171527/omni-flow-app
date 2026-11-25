import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../platform/omni_motion_scope.dart';
import '../tokens/tokens.dart';

/// Bộ chọn đoạn kiểu iOS (spec phong cách iOS 25/11/2026 §3.4): rãnh xám nhạt
/// bo 10, núm trắng đặc bo 8 bóng mảnh trượt tới đoạn đang chọn, chữ mực —
/// đoạn chọn đậm 600. Không kính, không thấu kính trắng mờ.
///
/// Khung cao 44 (36 khi [compact]) và vùng chạm phủ hết khung; rãnh nhìn thấy
/// cao 34 (30) nằm giữa — gọn như iOS mà ngón tay vẫn đủ chỗ.
class OmniSegmented extends StatelessWidget {
  const OmniSegmented({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
    this.compact = false,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final bool compact;

  /// Núm ở chế độ tối: sáng hơn mặt thẻ một bậc để vẫn thấy "nổi".
  static const Color _darkThumb = Color(0xFF2E3F5C);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final contrast = MediaQuery.highContrastOf(context);
    final n = labels.length;
    if (n == 0) return const SizedBox.shrink();
    final sel = index.clamp(0, n - 1);
    final align = n == 1 ? 0.0 : -1 + 2 * sel / (n - 1);
    final motion = OmniMotion.enabled(context);
    final double height = compact ? 36 : 44;
    final double track = compact ? 30 : 34;

    final trackColor = scheme.onSurface.withValues(alpha: dark ? .12 : .07);
    final thumbColor = dark ? _darkThumb : scheme.surface;
    final labelStyle = theme.textTheme.labelLarge ?? const TextStyle();

    void pick(int i) {
      if (i != sel) HapticFeedback.selectionClick();
      onChanged(i);
    }

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          // Rãnh + núm (chỉ để nhìn).
          Center(
            child: Container(
              height: track,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: trackColor,
                borderRadius: BorderRadius.circular(10),
                border: contrast ? Border.all(color: scheme.outline) : null,
              ),
              child: AnimatedAlign(
                alignment: Alignment(align, 0),
                duration: motion
                    ? const Duration(milliseconds: 260)
                    : Duration.zero,
                curve: Curves.easeOutCubic,
                child: FractionallySizedBox(
                  widthFactor: 1 / n,
                  heightFactor: 1,
                  child: DecoratedBox(
                    key: const Key('omni-segmented-thumb'),
                    decoration: BoxDecoration(
                      color: thumbColor,
                      borderRadius: BorderRadius.circular(8),
                      border: contrast
                          ? Border.all(color: scheme.onSurface)
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: dark ? .30 : .12,
                          ),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Chữ + vùng chạm cao đủ khung.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              children: [
                for (var i = 0; i < n; i++)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: i == sel,
                      label: labels[i],
                      onTap: () => pick(i),
                      excludeSemantics: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => pick(i),
                        child: SizedBox(
                          height: height,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: AnimatedDefaultTextStyle(
                                duration: motion
                                    ? OmniDuration.base
                                    : Duration.zero,
                                style: labelStyle.copyWith(
                                  color: i == sel
                                      ? scheme.onSurface
                                      : scheme.onSurface.withValues(alpha: .78),
                                  fontWeight: i == sel
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                                child: Text(
                                  labels[i],
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
