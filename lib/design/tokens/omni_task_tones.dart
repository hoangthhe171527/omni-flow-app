import 'package:flutter/material.dart';

/// Cặp nền / chữ của một chip công việc.
class OmniTaskTone {
  const OmniTaskTone({required this.background, required this.foreground});

  final Color background;
  final Color foreground;
}

/// Bảng màu ngữ nghĩa của màn Việc (`Tasks.dc.html`): ô hạn, "Ưu tiên cao",
/// chấm ưu tiên, đoạn "trễ" của thanh tiến độ.
///
/// Chế độ tối: nền là màu chữ sáng giảm alpha 0.18 đặt trên `surface`, chữ
/// sáng hơn — không giữ nguyên khối nhạt của chế độ sáng.
class OmniTaskTones {
  const OmniTaskTones._({
    required this.today,
    required this.late,
    required this.upcoming,
    required this.none,
    required this.highPriority,
    required this.violet,
    required this.priorityHigh,
    required this.priorityNormal,
    required this.priorityLow,
    required this.dueSoonBar,
  });

  /// Hạn hôm nay.
  final OmniTaskTone today;

  /// Quá hạn.
  final OmniTaskTone late;

  /// Hạn sắp tới.
  final OmniTaskTone upcoming;

  /// Chưa đặt hạn.
  final OmniTaskTone none;

  /// Ô "Tạo team" trong sheet Tạo mới.
  final OmniTaskTone violet;

  /// Chip "Ưu tiên cao".
  final OmniTaskTone highPriority;

  final Color priorityHigh;
  final Color priorityNormal;
  final Color priorityLow;

  /// Đoạn "trễ" của thanh tiến độ dự án.
  final Color dueSoonBar;

  static const _dueSoonBar = Color(0xFFE8890C);

  static const _light = OmniTaskTones._(
    today: OmniTaskTone(
      background: Color(0xFFE6F3F2),
      foreground: Color(0xFF075E59),
    ),
    late: OmniTaskTone(
      background: Color(0xFFFDECE3),
      foreground: Color(0xFF9A3412),
    ),
    upcoming: OmniTaskTone(
      background: Color(0xFFEEF1F5),
      foreground: Color(0xFF3D4A60),
    ),
    none: OmniTaskTone(
      background: Color(0xFFEEF1F5),
      foreground: Color(0xFF8A95A8),
    ),
    highPriority: OmniTaskTone(
      background: Color(0xFFFDE8E8),
      foreground: Color(0xFFB42318),
    ),
    violet: OmniTaskTone(
      background: Color(0xFFEFE7FD),
      foreground: Color(0xFF5B21B6),
    ),
    priorityHigh: Color(0xFFDC2626),
    priorityNormal: _dueSoonBar,
    priorityLow: Color(0xFF8A95A8),
    dueSoonBar: _dueSoonBar,
  );

  static OmniTaskTone _dark(Color foreground, Color surface) => OmniTaskTone(
    background: Color.alphaBlend(foreground.withValues(alpha: 0.18), surface),
    foreground: foreground,
  );

  static OmniTaskTones of(BuildContext context) {
    final theme = Theme.of(context);
    if (theme.brightness != Brightness.dark) return _light;

    final surface = theme.colorScheme.surface;

    return OmniTaskTones._(
      today: _dark(const Color(0xFF7FE3DA), surface),
      late: _dark(const Color(0xFFFDBA8C), surface),
      upcoming: _dark(const Color(0xFFB9C4D6), surface),
      none: _dark(const Color(0xFF9AA8BD), surface),
      highPriority: _dark(const Color(0xFFFCA5A5), surface),
      violet: _dark(const Color(0xFFC4B5FD), surface),
      priorityHigh: const Color(0xFFF87171),
      priorityNormal: const Color(0xFFF0A23C),
      priorityLow: const Color(0xFF9AA8BD),
      dueSoonBar: const Color(0xFFF0A23C),
    );
  }
}
