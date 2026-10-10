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
    required this.chevron,
    required List<Color> sectionColors,
  }) : _sectionColors = sectionColors;

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

  /// Mũi tên chỉ dẫn ở cuối dòng (Điều phối, Tài khoản).
  final Color chevron;

  final List<Color> _sectionColors;

  /// Ô vuông màu của nhóm việc thứ [index] trong bảng chọn "Chuyển nhóm việc"
  /// (`TaskDetail.dc.html`): năm màu, lặp vòng theo thứ tự nhóm.
  Color sectionColor(int index) =>
      _sectionColors[index % _sectionColors.length];

  static const _dueSoonBar = Color(0xFFD97706);

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
      foreground: Color(0xFF5B6678),
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
    chevron: Color(0xFFC9D2DE),
    sectionColors: [
      Color(0xFF8A95A8),
      Color(0xFF2563EB),
      Color(0xFFE8890C),
      Color(0xFF7C3AED),
      Color(0xFF0A7D76),
    ],
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
      chevron: const Color(0xFF5B6678),
      sectionColors: const [
        Color(0xFF9AA8BD),
        Color(0xFF60A5FA),
        Color(0xFFF0A23C),
        Color(0xFFA78BFA),
        Color(0xFF2DD4BF),
      ],
    );
  }
}
