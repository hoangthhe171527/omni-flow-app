import 'package:flutter/material.dart';

import 'omni_task_tones.dart';

/// Sắc của ô icon (lưới Tất cả, dòng Thông báo) — `All.dc.html` T/B/O/V/N.
enum OmniHue { teal, blue, orange, violet, red, neutral }

abstract final class OmniFeatureTones {
  static OmniTaskTone light(OmniHue hue) => switch (hue) {
    OmniHue.teal => const OmniTaskTone(
      background: Color(0xFFE6F3F2),
      foreground: Color(0xFF075E59),
    ),
    OmniHue.blue => const OmniTaskTone(
      background: Color(0xFFE3EAFD),
      foreground: Color(0xFF1D4ED8),
    ),
    OmniHue.orange => const OmniTaskTone(
      background: Color(0xFFFDECE3),
      foreground: Color(0xFF9A3412),
    ),
    OmniHue.violet => const OmniTaskTone(
      background: Color(0xFFEFE7FD),
      foreground: Color(0xFF5B21B6),
    ),
    OmniHue.red => const OmniTaskTone(
      background: Color(0xFFFDE8E8),
      foreground: Color(0xFFB42318),
    ),
    OmniHue.neutral => const OmniTaskTone(
      background: Color(0xFFEEF1F5),
      foreground: Color(0xFF0B1A33),
    ),
  };

  /// Tối: chữ sáng, nền = chữ alpha .18 trên `surface` (như `OmniTaskTones`).
  static OmniTaskTone dark(OmniHue hue, Color surface) {
    final fg = switch (hue) {
      OmniHue.teal => const Color(0xFF7FE3DA),
      OmniHue.blue => const Color(0xFF93C5FD),
      OmniHue.orange => const Color(0xFFFDBA8C),
      OmniHue.violet => const Color(0xFFC4B5FD),
      OmniHue.red => const Color(0xFFFCA5A5),
      OmniHue.neutral => const Color(0xFFE6EAF0),
    };
    return OmniTaskTone(
      background: Color.alphaBlend(fg.withValues(alpha: 0.18), surface),
      foreground: fg,
    );
  }

  static OmniTaskTone of(BuildContext context, OmniHue hue) {
    final theme = Theme.of(context);
    return theme.brightness == Brightness.dark
        ? dark(hue, theme.colorScheme.surface)
        : light(hue);
  }
}
