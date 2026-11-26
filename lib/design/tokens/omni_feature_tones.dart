import 'package:flutter/material.dart';

import 'omni_task_tones.dart';

/// Sắc của ô icon (lưới Tất cả, dòng Thông báo) — `All.dc.html` T/B/O/V/N.
enum OmniHue { teal, blue, orange, violet, red, sky, neutral }

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
    OmniHue.sky => const OmniTaskTone(
      background: Color(0xFFE0F2FE),
      foreground: Color(0xFF075985),
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
      OmniHue.sky => const Color(0xFF7DD3FC),
      OmniHue.neutral => const Color(0xFFE6EAF0),
    };
    return OmniTaskTone(
      background: Color.alphaBlend(fg.withValues(alpha: 0.18), surface),
      foreground: fg,
    );
  }

  /// Ô icon ĐẶC kiểu màn hình chính iOS (màn Ứng dụng, mẫu "Lưới iOS" duyệt
  /// 26/11/2026): dải màu trên → dưới, icon trắng. Giống nhau ở sáng và tối
  /// như icon ứng dụng của iOS.
  static (Color, Color) solid(OmniHue hue) => switch (hue) {
    OmniHue.blue => (const Color(0xFF2F6BEB), const Color(0xFF1D4FD1)),
    OmniHue.red => (const Color(0xFFEF5A5F), const Color(0xFFD63A40)),
    OmniHue.orange => (const Color(0xFFF5893A), const Color(0xFFE06A1B)),
    OmniHue.violet => (const Color(0xFF8B5CF6), const Color(0xFF6D3FE0)),
    OmniHue.teal => (const Color(0xFF14A394), const Color(0xFF0B8477)),
    OmniHue.sky => (const Color(0xFF0EA5E9), const Color(0xFF0284C7)),
    OmniHue.neutral => (const Color(0xFF7A8599), const Color(0xFF5F6B7E)),
  };

  static OmniTaskTone of(BuildContext context, OmniHue hue) {
    final theme = Theme.of(context);
    return theme.brightness == Brightness.dark
        ? dark(hue, theme.colorScheme.surface)
        : light(hue);
  }
}
