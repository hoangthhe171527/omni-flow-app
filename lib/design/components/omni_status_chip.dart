import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

/// Sắc thái của một chip trạng thái.
enum OmniTone { neutral, info, success, warning, danger }

/// Một chip trạng thái: icon + chữ trên một nền nhạt.
///
/// `icon` và `label` đều BẮT BUỘC. `icon` từng là tuỳ chọn, và đó là lỗi.
///
/// Chênh ĐỘ SÁNG giữa các màu trạng thái trong bảng màu app là 1.04–1.20 lần
/// (mòng két–đỏ 1.04, mòng két–cam 1.20, cam–đỏ 1.15). Không cặp nào tới 3.0.
/// Nghĩa là dưới nắng — điều kiện thật của người thợ đứng ở cửa xưởng — hoặc
/// với người mù màu lục-đỏ, MÀU KHÔNG PHÂN BIỆT ĐƯỢC hai trạng thái với nhau.
/// Hình dạng thì phân biệt được. WCAG 1.4.1 đòi đúng điều này.
///
/// Bản cũ còn một lỗi thứ hai: nó tô chữ bằng `tone.color` — tức bằng
/// [OmniColors.success], [OmniColors.warning], [OmniColors.destructive]. Ba
/// màu đó là màu ĐỒ HOẠ, đạt lần lượt 2.54:1, 2.15:1 và 3.76:1 trên nền
/// trắng. Bảng dưới đây dùng bản dành cho chữ, và mọi cặp đều được
/// `status_chip_test.dart` đo lại trên chính widget này ở cả hai chế độ.
class OmniStatusChip extends StatelessWidget {
  const OmniStatusChip({
    super.key,
    required this.icon,
    required this.label,
    this.tone = OmniTone.neutral,
  });

  final IconData icon;
  final String label;
  final OmniTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final (foreground, background) = _palette(theme.colorScheme, dark: dark);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: OmniRadius.chipAll,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: OmniSpacing.sm,
          vertical: OmniSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: OmniIconSize.sm, color: foreground),
            const SizedBox(width: OmniSpacing.xs),
            // Flexible chứ không Expanded: chip co theo chữ khi còn chỗ, và
            // chỉ xuống dòng khi hết chỗ. Expanded làm chip luôn chiếm hết
            // hàng, kể cả khi nhãn chỉ có hai chữ.
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// (chữ, nền) cho sắc thái này ở chế độ đang bật.
  ///
  /// Mọi cặp đạt tối thiểu 4.63:1, và mọi nền tách khỏi mặt thẻ ít nhất 1.08
  /// lần — đủ để thấy viên chip, chưa đủ để nó trông như một cái nút.
  (Color, Color) _palette(ColorScheme scheme, {required bool dark}) =>
      tone.resolve(scheme, dark: dark);
}

/// Cặp (chữ, nền) của mỗi giọng — nguồn chung cho chip trạng thái, huy hiệu
/// nhãn và ô icon theo khu. Bảng Orbit: nền nhạt, chữ đậm cùng họ màu; chế độ
/// tối đảo lại thành nền tối, chữ sáng. Mọi cặp có trong `contrast_test`.
extension OmniToneColors on OmniTone {
  (Color foreground, Color background) resolve(
    ColorScheme scheme, {
    required bool dark,
  }) => switch (this) {
    OmniTone.neutral =>
      dark
          ? (OmniColors.darkMutedForeground, OmniColors.darkMuted)
          : (OmniColors.secondaryForeground, OmniColors.muted),

    OmniTone.info =>
      dark
          ? (OmniColors.darkInfoText, OmniColors.darkInfoSoft)
          : (OmniColors.infoText, OmniColors.infoSoft),

    // "Đã xong" mang chính màu chính, không có xanh lá riêng: mọi ứng viên
    // xanh lá chỉ chênh màu chính rất ít về độ sáng. Xem ghi chú Semantic
    // trong omni_colors.dart.
    OmniTone.success => (scheme.onPrimaryContainer, scheme.primaryContainer),

    OmniTone.warning =>
      dark
          ? (OmniColors.warningTextDark, OmniColors.darkWarningSoft)
          : (OmniColors.warningText, OmniColors.warningSoft),

    OmniTone.danger =>
      dark
          ? (OmniColors.dangerTextDark, const Color(0xFF33211F))
          : (OmniColors.dangerText, OmniColors.dangerSoft),
  };

  (Color foreground, Color background) of(BuildContext context) {
    final theme = Theme.of(context);
    return resolve(
      theme.colorScheme,
      dark: theme.brightness == Brightness.dark,
    );
  }
}

/// Huy hiệu nhãn ngắn trên một dòng danh sách: "VIP", "Mới", "Ngưng"
/// (`MCustomers.dc.html`). Viên bo tròn cao 22, chữ đậm.
class OmniBadge extends StatelessWidget {
  const OmniBadge({
    super.key,
    required this.label,
    this.tone = OmniTone.neutral,
    this.icon,
    this.large = false,
  });

  final String label;
  final OmniTone tone;
  final IconData? icon;

  /// Cỡ 26 cho phần đầu màn chi tiết.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final (foreground, background) = tone.of(context);

    return Container(
      constraints: BoxConstraints(minHeight: large ? 26 : 22),
      padding: EdgeInsets.symmetric(horizontal: large ? 10 : 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: OmniRadius.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: OmniIconSize.xs, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: OmniType.micro.copyWith(
              color: foreground,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
