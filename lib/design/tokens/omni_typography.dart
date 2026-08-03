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

/// The messaging screens speak THREE type sizes and no more.
///
/// Before this the thread used four different sizes below 12 (10, 10, 10, 11)
/// for the same class of information, and `micro` — the style all of them went
/// through — is w600, so every scrap of metadata was tiny AND bold. Meta is
/// supposed to recede; small bold text reads as noise, not as hierarchy.
///
/// Sizes are deliberately a little larger than a Latin-only app would use, and
/// the body line-height is 1.45 rather than the usual 1.3–1.35: Vietnamese
/// stacks diacritics both above and below the x-height (ế, ộ, ữ, ằ), and tighter
/// leading makes consecutive lines collide.
abstract final class OmniChatType {
  /// The message itself — the only thing on the screen meant to be read.
  static const TextStyle message = TextStyle(
    fontFamily: OmniType.family,
    fontSize: 15.5,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  /// The person you are talking to, in the app bar.
  static const TextStyle peer = TextStyle(
    fontFamily: OmniType.family,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.25,
  );

  /// EVERY piece of metadata: timestamps, the day separator, the app bar
  /// subtitle, delivery state. One size, one weight, deliberately not bold.
  static const TextStyle meta = TextStyle(
    fontFamily: OmniType.family,
    fontSize: 11.5,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );
}

abstract final class OmniGradients {
  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [OmniColors.primary, OmniColors.primaryGlow],
  );
}
