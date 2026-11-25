import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

/// Kiểu nút cho mọi nút nằm trên BỀ MẶT TRẮNG (thẻ, sheet, form).
///
/// Theo spec phong cách iOS 25/11/2026 §3.2 (thay phương án B 08/11):
///
/// - nút chính (`FilledButton`): nền ĐẶC màu chính, chữ onPrimary — mỗi màn
///   hoặc sheet tối đa một nút như vậy;
/// - nút nhẹ (`OutlinedButton`): nền mực 6% pha sẵn trên mặt, chữ mực, không
///   viền (kiểu nút xám của iOS).
///
/// Nền pha sẵn thành màu đặc nên không chìm theo bề mặt. Tương phản cao: nền
/// bề mặt + viền màu chữ.
class OmniTintedButtons extends StatelessWidget {
  const OmniTintedButtons({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Theme(
      data: theme.copyWith(
        filledButtonTheme: FilledButtonThemeData(
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size.fromHeight(48)),
            textStyle: const WidgetStatePropertyAll(OmniType.bodyStrong),
            shape: const WidgetStatePropertyAll(StadiumBorder()),
            elevation: const WidgetStatePropertyAll(0),
            surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
            backgroundColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.disabled)
                  ? scheme.onSurface.withValues(alpha: .10)
                  : scheme.primary,
            ),
            foregroundColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.disabled)
                  ? scheme.onSurface.withValues(alpha: .38)
                  : scheme.onPrimary,
            ),
            overlayColor: WidgetStatePropertyAll(
              scheme.onPrimary.withValues(alpha: .12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: tintedStyle(
            context,
            foreground: scheme.onSurface,
            tint: scheme.onSurface,
            amount: theme.brightness == Brightness.dark ? .10 : .06,
          ),
        ),
      ),
      child: child,
    );
  }

  /// Kiểu nút nhuộm tông: nền [tint] với tỉ lệ [amount] pha trên nền bề mặt.
  static ButtonStyle tintedStyle(
    BuildContext context, {
    required Color foreground,
    required Color tint,
    required double amount,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final contrast = MediaQuery.highContrastOf(context);
    final fill = Color.alphaBlend(
      tint.withValues(alpha: amount),
      scheme.surface,
    );
    final disabledFill = Color.alphaBlend(
      scheme.onSurface.withValues(alpha: .04),
      scheme.surface,
    );

    return ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(48)),
      textStyle: const WidgetStatePropertyAll(OmniType.bodyStrong),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
      elevation: const WidgetStatePropertyAll(0),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      backgroundColor: WidgetStateProperty.resolveWith(
        (s) => contrast
            ? scheme.surface
            : s.contains(WidgetState.disabled)
            ? disabledFill
            : fill,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled)
            ? scheme.onSurface.withValues(alpha: .38)
            : foreground,
      ),
      overlayColor: WidgetStatePropertyAll(foreground.withValues(alpha: .10)),
      side: WidgetStatePropertyAll(
        contrast ? BorderSide(color: foreground) : BorderSide.none,
      ),
    );
  }
}
