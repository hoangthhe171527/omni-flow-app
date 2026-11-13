import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

/// Nút "kính nhuộm tông" cho mọi nút nằm trên BỀ MẶT TRẮNG (phương án B,
/// duyệt 08/11/2026).
///
/// Nút kính trắng mờ của theme chỉ nổi trên nền xám / ảnh; đặt lên thẻ trắng,
/// sheet, form trắng thì nền nút trùng nền, chỉ còn bóng nhạt nên trông chìm.
/// Bọc bề mặt trắng bằng widget này để các `FilledButton` / `OutlinedButton`
/// bên trong đổi sang:
///
/// - nút chính (`FilledButton`): nền màu chính 12% pha sẵn trên nền bề mặt,
///   chữ màu chính;
/// - nút phụ (`OutlinedButton`): nền mực 6%, chữ mực.
///
/// Không tô đặc, không viền màu (gu đã chốt). Nền pha sẵn thành màu đặc nên
/// không chìm theo bề mặt. Tương phản cao: nền bề mặt + viền màu chữ.
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
