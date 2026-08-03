import 'package:flutter/material.dart';

/// Palette, straight from the Sleek design system for this app
/// (`design/html/*.html`, `:root` block). Values here and there must stay equal —
/// when the design changes, change this file, not individual widgets.
abstract final class OmniColors {
  // ---- Brand -------------------------------------------------------------
  /// Indigo-700. Reserved for primary actions, the login hero and active nav.
  static const primary = Color(0xFF4338CA);
  static const primaryForeground = Color(0xFFFFFFFF);

  /// The brand gradient's far end — used only inside [OmniGradients].
  static const primaryGlow = Color(0xFF6366F1);

  /// Very light indigo wash behind selected/quiet-emphasis surfaces.
  static const accent = Color(0xFFEEF2FF);
  static const accentForeground = Color(0xFF4338CA);

  // ---- Surfaces ----------------------------------------------------------
  static const background = Color(0xFFF8F9FB);
  static const card = Color(0xFFFFFFFF);
  static const muted = Color(0xFFF1F5F9);
  static const secondary = Color(0xFFE2E8F0);
  static const border = Color(0xFFE2E8F0);

  // ---- Text --------------------------------------------------------------
  static const foreground = Color(0xFF0F172A);
  static const secondaryForeground = Color(0xFF1E293B);
  static const mutedForeground = Color(0xFF64748B);

  // ---- Semantic ----------------------------------------------------------
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const destructive = Color(0xFFEF4444);
  static const info = Color(0xFF0EA5E9);

  // ---- Dark theme --------------------------------------------------------
  static const darkBackground = Color(0xFF0B1120);
  static const darkCard = Color(0xFF111827);
  static const darkMuted = Color(0xFF1E293B);
  static const darkBorder = Color(0xFF1F2937);
  static const darkForeground = Color(0xFFF1F5F9);
  static const darkMutedForeground = Color(0xFF94A3B8);
  static const darkPrimary = Color(0xFF818CF8);

  /// Deterministic avatar tint from a name, so the same person keeps the same
  /// colour on every screen.
  static const avatarPalette = <Color>[
    Color(0xFF4338CA),
    Color(0xFF0EA5E9),
    Color(0xFF10B981),
    Color(0xFFEC4899),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
    Color(0xFF14B8A6),
  ];

  static Color avatarFor(String seed) {
    if (seed.isEmpty) return avatarPalette.first;
    final hash = seed.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    return avatarPalette[hash % avatarPalette.length];
  }
}
