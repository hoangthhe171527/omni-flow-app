import 'package:flutter/material.dart';

import 'omni_colors.dart';

abstract final class OmniType {
  static const String family = 'Inter';

  /// Counts and money use tabular figures so numbers never jitter as they
  /// update in place (unread badges, pipeline totals, message timestamps).
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  static const TextStyle displayLg = TextStyle(
    fontFamily: family,
    fontSize: 30,
    fontWeight: FontWeight.w700,
    height: 1.15,
    letterSpacing: -0.6,
  );

  static const TextStyle title = TextStyle(
    fontFamily: family,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.4,
  );

  static const TextStyle section = TextStyle(
    fontFamily: family,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.25,
    letterSpacing: -0.2,
  );

  /// Small all-caps label above a group of fields or a list section.
  static const TextStyle overline = TextStyle(
    fontFamily: family,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.8,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontFamily: family,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: -0.1,
  );

  static const TextStyle body = TextStyle(
    fontFamily: family,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: family,
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    height: 1.35,
  );

  static const TextStyle micro = TextStyle(
    fontFamily: family,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  static const TextStyle money = TextStyle(
    fontFamily: family,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.3,
    fontFeatures: tabular,
  );

  static const TextStyle moneyHero = TextStyle(
    fontFamily: family,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.1,
    letterSpacing: -0.6,
    fontFeatures: tabular,
  );

  static TextTheme textTheme(Color onSurface, Color onSurfaceMuted) {
    return TextTheme(
      displayLarge: displayLg.copyWith(color: onSurface),
      titleLarge: title.copyWith(color: onSurface),
      titleMedium: section.copyWith(color: onSurface),
      titleSmall: bodyStrong.copyWith(color: onSurface),
      bodyLarge: body.copyWith(color: onSurface),
      bodyMedium: body.copyWith(color: onSurfaceMuted),
      bodySmall: caption.copyWith(color: onSurfaceMuted),
      labelLarge: bodyStrong.copyWith(color: onSurface),
      labelMedium: caption.copyWith(color: onSurfaceMuted),
      labelSmall: micro.copyWith(color: onSurfaceMuted),
    );
  }
}

abstract final class OmniGradients {
  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [OmniColors.primary, OmniColors.primaryGlow],
  );
}
