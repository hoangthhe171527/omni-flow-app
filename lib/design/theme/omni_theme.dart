import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../platform/omni_platform.dart';
import '../tokens/tokens.dart';

abstract final class OmniTheme {
  /// Nền tảng là tham số có mặc định, không phải bắt buộc: mọi chỗ gọi sẵn có
  /// không phải sửa, mà test vẫn ép được nền tảng khi cần.
  static ThemeData light([TargetPlatform? platform]) => _build(
    brightness: Brightness.light,
    platform: platform ?? defaultTargetPlatform,
    background: OmniColors.background,
    surface: OmniColors.card,
    surfaceMuted: OmniColors.muted,
    border: OmniColors.border,
    borderInteractive: OmniColors.borderInteractive,
    onSurface: OmniColors.foreground,
    onSurfaceMuted: OmniColors.mutedForeground,
    primary: OmniColors.primary,
    onPrimary: OmniColors.primaryForeground,
    accent: OmniColors.accent,
    onAccent: OmniColors.accentForeground,
  );

  static ThemeData dark([TargetPlatform? platform]) => _build(
    brightness: Brightness.dark,
    platform: platform ?? defaultTargetPlatform,
    background: OmniColors.darkBackground,
    surface: OmniColors.darkCard,
    surfaceMuted: OmniColors.darkMuted,
    border: OmniColors.darkBorder,
    borderInteractive: OmniColors.darkBorderInteractive,
    onSurface: OmniColors.darkForeground,
    onSurfaceMuted: OmniColors.darkMutedForeground,
    primary: OmniColors.darkPrimary,
    // Chữ TỐI trên nút chính. Nền tối buộc [primary] phải sáng, và trắng trên
    // #4FBFAE chỉ đạt 2.18:1 — đây là chỗ hai chế độ buộc phải khác nhau.
    onPrimary: OmniColors.darkPrimaryForeground,
    accent: OmniColors.darkAccent,
    onAccent: OmniColors.darkAccentForeground,
  );

  static ThemeData _build({
    required Brightness brightness,
    required TargetPlatform platform,
    required Color background,
    required Color surface,
    required Color surfaceMuted,
    required Color border,
    required Color borderInteractive,
    required Color onSurface,
    required Color onSurfaceMuted,
    required Color primary,
    required Color onPrimary,
    required Color accent,
    required Color onAccent,
  }) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: accent,
      onPrimaryContainer: onAccent,
      // Khe `secondary` và `error` là NỀN mang chữ trắng, nên phải dùng bản
      // đậm. OmniColors.info và .destructive là màu ĐỒ HOẠ — trắng trên chúng
      // chỉ đạt 2.77:1 và 3.76:1.
      secondary: OmniColors.infoSurface,
      onSecondary: Colors.white,
      // Bỏ trống hai khe này là để Flutter điền màu mặc định của nó vào.
      // Widget nào không được app tạo kiểu riêng sẽ với tới đây —
      // SegmentedButton trên màn "Tất cả" là một, và nó đang hiện xanh tím
      // giữa một app mòng két. Trỏ về cùng nền nhấn với primaryContainer.
      secondaryContainer: accent,
      onSecondaryContainer: onAccent,
      error: OmniColors.dangerSurface,
      onError: Colors.white,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: surfaceMuted,
      onSurfaceVariant: onSurfaceMuted,
      // Hai vai khác nhau: `outline` vẽ ranh giới thành phần TƯƠNG TÁC (ô
      // nhập, nút viền) và phải đạt 3:1 theo WCAG 1.4.11; `outlineVariant` vẽ
      // vạch ngăn TRANG TRÍ và được phép nhạt. Trước đây cả hai cùng một màu,
      // tức là vai thứ nhất đang sai.
      outline: borderInteractive,
      outlineVariant: border,
    );

    final textTheme = OmniType.textTheme(onSurface, onSurfaceMuted);

    final apple = isApplePlatform(platform);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      // Widget con đọc nền tảng qua isApple(context), tức qua đây. Quên đặt là
      // chúng rơi về defaultTargetPlatform và test hết ép được.
      platform: platform,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: OmniType.family,
      textTheme: textTheme,
      // iOS không có gợn sóng, nó làm mờ. NoSplash chứ không phải một ripple
      // nhạt hơn: phản hồi chạm vẫn còn nguyên qua highlightColor của InkWell.
      splashFactory: apple ? NoSplash.splashFactory : InkSparkle.splashFactory,
      // pageTransitionsTheme CỐ Ý không đặt. Mặc định của Flutter đã dùng
      // CupertinoPageTransitionsBuilder cho iOS — trượt ngang KÈM cử chỉ
      // vuốt-quay-lại. Đặt vào đây là làm hỏng thứ đang đúng.
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: apple,
        titleTextStyle: OmniType.title.copyWith(color: onSurface),
        systemOverlayStyle: brightness == Brightness.light
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: OmniRadius.xlAll,
          side: BorderSide(color: border),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: const Size.fromHeight(52),
          textStyle: OmniType.bodyStrong,
          shape: const RoundedRectangleBorder(borderRadius: OmniRadius.mdAll),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: borderInteractive),
          textStyle: OmniType.bodyStrong,
          shape: const RoundedRectangleBorder(borderRadius: OmniRadius.mdAll),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: OmniType.bodyStrong,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 2,
        shape: const RoundedRectangleBorder(borderRadius: OmniRadius.xlAll),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.light
            ? OmniColors.background
            : surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: OmniSpacing.lg,
          vertical: OmniSpacing.lg,
        ),
        hintStyle: OmniType.body.copyWith(color: onSurfaceMuted),
        labelStyle: OmniType.caption.copyWith(color: onSurfaceMuted),
        border: OutlineInputBorder(
          borderRadius: OmniRadius.mdAll,
          borderSide: BorderSide(color: borderInteractive),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: OmniRadius.mdAll,
          borderSide: BorderSide(color: borderInteractive),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: OmniRadius.mdAll,
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: OmniRadius.mdAll,
          borderSide: BorderSide(color: OmniColors.destructive),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: OmniRadius.mdAll,
          borderSide: BorderSide(color: OmniColors.destructive, width: 1.5),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        // showDragHandle do showOmniSheet quyết theo nền tảng, không đặt ở đây:
        // theme thắng thì mọi sheet đều có thanh kéo kể cả trên Android.
        showDragHandle: apple,
        dragHandleColor: border,
        shape: const RoundedRectangleBorder(borderRadius: OmniRadius.sheet),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: primary.withValues(alpha: 0.11),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => OmniType.micro.copyWith(
            color: states.contains(WidgetState.selected)
                ? primary
                : onSurfaceMuted,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        side: BorderSide(color: borderInteractive),
        labelStyle: OmniType.caption.copyWith(color: onSurface),
        shape: const RoundedRectangleBorder(borderRadius: OmniRadius.chipAll),
        padding: const EdgeInsets.symmetric(horizontal: OmniSpacing.md),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: OmniColors.foreground,
        contentTextStyle: OmniType.body.copyWith(color: Colors.white),
        shape: const RoundedRectangleBorder(borderRadius: OmniRadius.mdAll),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearMinHeight: 4,
      ),
    );
  }
}
