import 'package:flutter/material.dart';

/// Palette, straight from the Sleek design system for this app
/// (`design/html/*.html`, `:root` block). Values here and there must stay equal —
/// when the design changes, change this file, not individual widgets.
abstract final class OmniColors {
  // ---- Brand -------------------------------------------------------------
  /// Indigo-700. Reserved for primary actions, the login hero and active nav.
  static const primary = Color(0xFF5B5CE2);
  static const primaryForeground = Color(0xFFFFFFFF);

  /// The brand gradient's far end — used only inside [OmniGradients].
  static const primaryGlow = Color(0xFF8789F5);

  /// Very light indigo wash behind selected/quiet-emphasis surfaces.
  static const accent = Color(0xFFF0F0FF);
  static const accentForeground = Color(0xFF4B4CC9);

  // ---- Surfaces ----------------------------------------------------------
  static const background = Color(0xFFF8F8FC);
  static const card = Color(0xFFFFFFFF);
  static const muted = Color(0xFFF1F1F7);
  static const secondary = Color(0xFFE7E7F0);
  static const border = Color(0xFFE7E7F0);

  // ---- Text --------------------------------------------------------------
  static const foreground = Color(0xFF20212B);
  static const secondaryForeground = Color(0xFF353643);
  static const mutedForeground = Color(0xFF777889);

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
  static const darkPrimary = Color(0xFFA5A6FF);

  // ---- Chat ---------------------------------------------------------------
  /// Messaging surfaces follow Zalo's visual language rather than the CRM
  /// palette above.
  ///
  /// Reps live in this screen all day beside the real Zalo app, and every
  /// difference reads as a defect: the indigo card list looked like a database
  /// table, not a chat. So the inbox and the thread borrow Zalo's blue, its flat
  /// white rows and its pale blue-grey thread canvas. The CRM palette still owns
  /// every other module — this is a deliberate, contained exception.
  static const chatPrimary = Color(0xFF0068FF);

  /// Thread canvas. Bubbles must read as raised against it, which they cannot do
  /// on white — the reason the old thread felt flat.
  static const chatCanvas = Color(0xFFE7EBF0);

  /// Outgoing bubble: pale blue with DARK text. Zalo does not invert to white
  /// text, and dark-on-pale keeps long messages comfortable to read.
  static const chatOutbound = Color(0xFFCFE9FF);

  /// Incoming bubble.
  static const chatInbound = Color(0xFFFFFFFF);

  /// Timestamps and delivery ticks inside a bubble.
  static const chatMeta = Color(0xFF7589A3);

  /// Hairline between list rows, indented past the avatar.
  static const chatDivider = Color(0xFFF0F1F4);

  /// Unread count pill.
  static const chatUnread = Color(0xFFFF3B30);

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
