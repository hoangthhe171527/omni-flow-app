import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/tokens.dart';

abstract final class OmniTheme {
  static ThemeData get light => _build(
        brightness: Brightness.light,
        background: OmniColors.background,
        surface: OmniColors.card,
        surfaceMuted: OmniColors.muted,
        border: OmniColors.border,
        onSurface: OmniColors.foreground,
        onSurfaceMuted: OmniColors.mutedForeground,
        primary: OmniColors.primary,
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        background: OmniColors.darkBackground,
        surface: OmniColors.darkCard,
        surfaceMuted: OmniColors.darkMuted,
        border: OmniColors.darkBorder,
        onSurface: OmniColors.darkForeground,
        onSurfaceMuted: OmniColors.darkMutedForeground,
        primary: OmniColors.darkPrimary,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color surfaceMuted,
    required Color border,
    required Color onSurface,
    required Color onSurfaceMuted,
    required Color primary,
  }) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: OmniColors.primaryForeground,
      primaryContainer: OmniColors.accent,
      onPrimaryContainer: OmniColors.accentForeground,
      secondary: OmniColors.info,
      onSecondary: Colors.white,
      error: OmniColors.destructive,
      onError: Colors.white,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: surfaceMuted,
      onSurfaceVariant: onSurfaceMuted,
      outline: border,
      outlineVariant: border,
    );

    final textTheme = OmniType.textTheme(onSurface, onSurfaceMuted);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: OmniType.family,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
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
          borderRadius: OmniRadius.lgAll,
          side: BorderSide(color: border),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: OmniColors.primaryForeground,
          minimumSize: const Size.fromHeight(52),
          textStyle: OmniType.bodyStrong,
          shape: const RoundedRectangleBorder(borderRadius: OmniRadius.mdAll),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: border),
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
        foregroundColor: OmniColors.primaryForeground,
        elevation: 2,
        shape: const RoundedRectangleBorder(borderRadius: OmniRadius.lgAll),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.light ? OmniColors.background : surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: OmniSpacing.lg,
          vertical: OmniSpacing.lg,
        ),
        hintStyle: OmniType.body.copyWith(color: onSurfaceMuted),
        labelStyle: OmniType.caption.copyWith(color: onSurfaceMuted),
        border: OutlineInputBorder(
          borderRadius: OmniRadius.mdAll,
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: OmniRadius.mdAll,
          borderSide: BorderSide(color: border),
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
        showDragHandle: true,
        dragHandleColor: border,
        shape: const RoundedRectangleBorder(borderRadius: OmniRadius.sheet),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 64,
        indicatorColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => OmniType.micro.copyWith(
            color: states.contains(WidgetState.selected) ? primary : onSurfaceMuted,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        side: BorderSide(color: border),
        labelStyle: OmniType.caption.copyWith(color: onSurface),
        shape: const RoundedRectangleBorder(borderRadius: OmniRadius.pillAll),
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
