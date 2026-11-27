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
    // Nền nút ĐẶC: ở Tối `scheme.primary` là xanh CHỮ (#5E9BFF, chữ đen trên
    // nó) — nút đặc phải dùng `accent-fill` + chữ trắng như nút ngoài sheet.
    final fill = OmniColors.byBrightness(
      context,
      scheme.primary,
      OmniColors.primaryFillOf(context),
    );
    const onFill = OmniColors.primaryForeground;
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
                  : fill,
            ),
            foregroundColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.disabled)
                  ? scheme.onSurface.withValues(alpha: .38)
                  : onFill,
            ),
            overlayColor: WidgetStatePropertyAll(onFill.withValues(alpha: .12)),
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

  /// Chiều cao nút ĐÁY (khay đáy màn, chân sheet): lõi 50–56, thân giữ 48.
  static const dockHeight = 52.0;

  /// Nâng mọi nút trong [child] lên [dockHeight], giữ nguyên màu của theme.
  static Widget dock(BuildContext context, Widget child) {
    const size = WidgetStatePropertyAll(Size.fromHeight(dockHeight));
    final filled = FilledButtonTheme.of(context).style ?? const ButtonStyle();
    final outlined =
        OutlinedButtonTheme.of(context).style ?? const ButtonStyle();
    return FilledButtonTheme(
      data: FilledButtonThemeData(style: filled.copyWith(minimumSize: size)),
      child: OutlinedButtonTheme(
        data: OutlinedButtonThemeData(
          style: outlined.copyWith(minimumSize: size),
        ),
        child: child,
      ),
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
