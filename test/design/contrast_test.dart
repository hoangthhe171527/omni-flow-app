import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/tokens/contrast.dart';
import 'package:omni_app/design/tokens/omni_colors.dart';

/// Một cặp màu phải đạt một ngưỡng.
typedef _Pair = ({String what, Color fg, Color bg, double min});

/// Bảng màu đọc được, đo bằng công thức chứ không bằng mắt.
///
/// Đây là chỗ duy nhất trong app khẳng định "màu này đọc được". Mọi widget
/// lấy màu từ [OmniColors], nên nếu bảng này xanh thì không màn hình nào có
/// thể có chữ không đọc được — trừ khi ai đó ghi cứng một mã màu, và
/// `hardcoded_colour_test.dart` chặn việc đó.
void main() {
  // 4.5 = AA cho chữ thường. 3.0 = AA cho ranh giới thành phần (WCAG 1.4.11).
  const t = 4.5;
  const ui = 3.0;

  final pairs = <_Pair>[
    // ---- Sáng: chữ trên các bề mặt ----
    (
      what: 'chữ chính / nền',
      fg: OmniColors.foreground,
      bg: OmniColors.background,
      min: t,
    ),
    (
      what: 'chữ chính / thẻ',
      fg: OmniColors.foreground,
      bg: OmniColors.card,
      min: t,
    ),
    (
      what: 'chữ cấp 2 / nền',
      fg: OmniColors.secondaryForeground,
      bg: OmniColors.background,
      min: t,
    ),
    (
      what: 'chữ phụ / nền',
      fg: OmniColors.mutedForeground,
      bg: OmniColors.background,
      min: t,
    ),
    (
      what: 'chữ phụ / thẻ',
      fg: OmniColors.mutedForeground,
      bg: OmniColors.card,
      min: t,
    ),
    (
      what: 'chữ phụ / bề mặt mờ',
      fg: OmniColors.mutedForeground,
      bg: OmniColors.muted,
      min: t,
    ),

    // ---- Sáng: màu chính ----
    (
      what: 'chữ trên nút chính',
      fg: OmniColors.primaryForeground,
      bg: OmniColors.primary,
      min: t,
    ),
    (
      what: 'màu chính / nền',
      fg: OmniColors.primary,
      bg: OmniColors.background,
      min: t,
    ),
    (
      what: 'màu chính / thẻ',
      fg: OmniColors.primary,
      bg: OmniColors.card,
      min: t,
    ),
    (
      what: 'chữ nhấn / nền nhấn',
      fg: OmniColors.accentForeground,
      bg: OmniColors.accent,
      min: t,
    ),

    // ---- Sáng: ranh giới ----
    (
      what: 'viền tương tác / thẻ',
      fg: OmniColors.borderInteractive,
      bg: OmniColors.card,
      min: ui,
    ),
    (
      what: 'viền tương tác / nền',
      fg: OmniColors.borderInteractive,
      bg: OmniColors.background,
      min: ui,
    ),

    // ---- Sáng: trạng thái ----
    (
      what: 'chữ cảnh báo / thẻ',
      fg: OmniColors.warningText,
      bg: OmniColors.card,
      min: t,
    ),
    (
      what: 'chữ nguy hiểm / thẻ',
      fg: OmniColors.dangerText,
      bg: OmniColors.card,
      min: t,
    ),
    (
      what: 'chữ trắng / nền nguy hiểm',
      fg: OmniColors.card,
      bg: OmniColors.dangerText,
      min: t,
    ),

    // ---- Tối ----
    (
      what: 'tối: chữ chính / nền',
      fg: OmniColors.darkForeground,
      bg: OmniColors.darkBackground,
      min: t,
    ),
    (
      what: 'tối: chữ chính / thẻ',
      fg: OmniColors.darkForeground,
      bg: OmniColors.darkCard,
      min: t,
    ),
    (
      what: 'tối: chữ phụ / nền',
      fg: OmniColors.darkMutedForeground,
      bg: OmniColors.darkBackground,
      min: t,
    ),
    (
      what: 'tối: chữ phụ / thẻ',
      fg: OmniColors.darkMutedForeground,
      bg: OmniColors.darkCard,
      min: t,
    ),
    (
      what: 'tối: màu chính / thẻ',
      fg: OmniColors.darkPrimary,
      bg: OmniColors.darkCard,
      min: t,
    ),
    (
      what: 'tối: chữ trên nút chính',
      fg: OmniColors.darkPrimaryForeground,
      bg: OmniColors.darkPrimary,
      min: t,
    ),
    (
      what: 'tối: viền tương tác / thẻ',
      fg: OmniColors.darkBorderInteractive,
      bg: OmniColors.darkCard,
      min: ui,
    ),
    (
      what: 'tối: chữ cảnh báo / thẻ',
      fg: OmniColors.warningTextDark,
      bg: OmniColors.darkCard,
      min: t,
    ),
    (
      what: 'tối: chữ nguy hiểm / thẻ',
      fg: OmniColors.dangerTextDark,
      bg: OmniColors.darkCard,
      min: t,
    ),
  ];

  for (final p in pairs) {
    test('${p.what} đạt ${p.min}:1', () {
      final r = contrastRatio(p.fg, p.bg);

      expect(
        r,
        greaterThanOrEqualTo(p.min),
        reason:
            '${p.what} chỉ đạt ${r.toStringAsFixed(2)}:1. '
            'Đây là ngưỡng WCAG AA, không phải sở thích — hãy đổi giá trị '
            'token, đừng hạ ngưỡng.',
      );
    });
  }

  // Nếu công thức sai thì 24 test trên kia đều vô nghĩa mà vẫn xanh. Hai mốc
  // này do W3C định nghĩa, không phải do app này chọn.
  group('công thức khớp mốc W3C', () {
    test('đen trên trắng = 21:1', () {
      expect(
        contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
        closeTo(21, 0.01),
      );
    });

    test('một màu với chính nó = 1:1', () {
      expect(
        contrastRatio(OmniColors.primary, OmniColors.primary),
        closeTo(1, 0.001),
      );
    });

    test('thứ tự hai màu không đổi kết quả', () {
      expect(
        contrastRatio(OmniColors.foreground, OmniColors.background),
        closeTo(
          contrastRatio(OmniColors.background, OmniColors.foreground),
          0.001,
        ),
      );
    });
  });

  // "Đã xong" KHÔNG được có màu xanh lá riêng — nó dùng chính màu chính cộng
  // dấu tick. Test này ghi lại LÝ DO, để lần sau ai đó muốn thêm lại
  // `successText` thì thấy con số trước khi thêm.
  test('không màu xanh lá nào tách được khỏi màu chính bằng độ sáng', () {
    const candidates = [
      Color(0xFF067A55),
      Color(0xFF157A33),
      Color(0xFF1B7F33),
      Color(0xFF2E7D32),
    ];

    for (final green in candidates) {
      expect(
        contrastRatio(green, OmniColors.primary),
        lessThan(1.5),
        reason:
            'Nếu một ứng viên xanh lá bỗng tách khỏi màu chính thì màu chính '
            'đã đổi, và quyết định bỏ successText cần xem lại.',
      );
    }
  });
}
