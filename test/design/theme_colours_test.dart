import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/design/tokens/contrast.dart';
import 'package:omni_app/design/tokens/omni_colors.dart';

/// Theme phải LẤY màu từ token, và phải lấy đúng bản cho chế độ đang bật.
///
/// `contrast_test.dart` chứng minh bảng token đọc được. Bài này chứng minh
/// theme thật sự dùng bảng đó — hai việc khác nhau, và chỗ hở nằm đúng giữa
/// chúng: một token đạt chuẩn vẫn có thể bị gán vào sai khe của [ColorScheme].
void main() {
  group('chế độ sáng', () {
    final theme = OmniTheme.light(TargetPlatform.iOS);

    test('màu chính và nền lấy từ token', () {
      expect(theme.colorScheme.primary, OmniColors.primary);
      expect(theme.colorScheme.surface, OmniColors.card);
      expect(theme.scaffoldBackgroundColor, OmniColors.background);
    });

    test('chữ trên nút chính là trắng', () {
      expect(theme.colorScheme.onPrimary, OmniColors.primaryForeground);
    });
  });

  group('chế độ tối', () {
    final theme = OmniTheme.dark(TargetPlatform.android);

    test('màu chính và nền lấy bản tối', () {
      expect(theme.colorScheme.primary, OmniColors.darkPrimary);
      expect(theme.colorScheme.surface, OmniColors.darkCard);
      expect(theme.scaffoldBackgroundColor, OmniColors.darkBackground);
    });

    test('chữ trên nút chính là chữ TỐI, không phải trắng', () {
      expect(
        theme.colorScheme.onPrimary,
        OmniColors.darkPrimaryForeground,
        reason:
            'Nền tối buộc màu chính phải sáng, và chữ trắng trên #4FBFAE chỉ '
            'đạt 2.18:1. Đây là chỗ hai chế độ buộc phải khác nhau chứ không '
            'phải chỗ đảo màu là xong.',
      );
    });

    test('nền nhấn không phải bản sáng', () {
      expect(
        theme.colorScheme.primaryContainer,
        isNot(OmniColors.accent),
        reason:
            'accent #E4F1EF là một khối sáng chói giữa màn hình tối. Chế độ '
            'tối phải có bản riêng.',
      );
    });
  });

  // outline và outlineVariant là hai vai khác nhau trong Material: outline
  // vẽ ranh giới thành phần TƯƠNG TÁC (ô nhập, nút viền), outlineVariant vẽ
  // vạch ngăn TRANG TRÍ. Gán cùng một màu cho cả hai nghĩa là một trong hai
  // vai đang sai — và vai sai ở đây là vai phải đạt 3:1.
  group('hai loại đường kẻ', () {
    test('sáng: outline là viền tương tác, outlineVariant là viền trang trí', () {
      final s = OmniTheme.light(TargetPlatform.android).colorScheme;

      expect(s.outline, OmniColors.borderInteractive);
      expect(s.outlineVariant, OmniColors.border);
    });

    test('tối: cùng cách chia', () {
      final s = OmniTheme.dark(TargetPlatform.android).colorScheme;

      expect(s.outline, OmniColors.darkBorderInteractive);
      expect(s.outlineVariant, OmniColors.darkBorder);
    });
  });

  // ColorScheme đúng vẫn có thể bị một *ButtonThemeData ghi đè. Đây là chỗ
  // đúng-ở-tầng-dưới-sai-ở-tầng-trên: nút chính lấy màu chữ từ
  // FilledButtonThemeData chứ không từ scheme.onPrimary.
  group('theme của từng thành phần không ghi đè bằng hằng số', () {
    for (final (name, theme) in [
      ('sáng', OmniTheme.light(TargetPlatform.android)),
      ('tối', OmniTheme.dark(TargetPlatform.android)),
    ]) {
      test('$name: chữ trên nút chính đọc được', () {
        final style = theme.filledButtonTheme.style!;
        final fg = style.foregroundColor!.resolve({})!;
        final bg = style.backgroundColor!.resolve({})!;
        final r = contrastRatio(fg, bg);

        expect(
          r,
          greaterThanOrEqualTo(4.5),
          reason:
              'FilledButton ở chế độ $name chỉ đạt ${r.toStringAsFixed(2)}:1. '
              'Trước đây foregroundColor ghim cứng màu trắng, nên ở chế độ '
              'tối nó là trắng trên teal sáng.',
        );
      });

      test('$name: viền ô nhập đạt 3:1', () {
        final border =
            theme.inputDecorationTheme.enabledBorder! as OutlineInputBorder;
        final r = contrastRatio(
          border.borderSide.color,
          theme.inputDecorationTheme.fillColor!,
        );

        expect(
          r,
          greaterThanOrEqualTo(3),
          reason:
              'Viền ô nhập ở chế độ $name chỉ đạt ${r.toStringAsFixed(2)}:1 '
              'so với nền của chính nó — WCAG 1.4.11.',
        );
      });

      test('$name: viền nút viền đạt 3:1', () {
        final side = theme.outlinedButtonTheme.style!.side!.resolve({})!;
        final r = contrastRatio(side.color, theme.scaffoldBackgroundColor);

        expect(r, greaterThanOrEqualTo(3));
      });
    }
  });

  // Bài đo cuối: đi thẳng qua ColorScheme của cả hai chế độ và bắt mọi cặp
  // (chữ, nền) mà Material đã ghép sẵn phải đạt ngưỡng. Nếu ai đó thêm một
  // khe mới vào scheme và gán sai bản sáng/tối, bài này thấy.
  for (final (name, theme) in [
    ('sáng', OmniTheme.light(TargetPlatform.iOS)),
    ('tối', OmniTheme.dark(TargetPlatform.iOS)),
  ]) {
    group('$name: mọi cặp chữ/nền của ColorScheme', () {
      final s = theme.colorScheme;
      final pairs = <(String, Color, Color)>[
        ('onSurface / surface', s.onSurface, s.surface),
        ('onSurfaceVariant / surface', s.onSurfaceVariant, s.surface),
        (
          'onSurfaceVariant / surfaceContainerHighest',
          s.onSurfaceVariant,
          s.surfaceContainerHighest,
        ),
        ('onPrimary / primary', s.onPrimary, s.primary),
        (
          'onPrimaryContainer / primaryContainer',
          s.onPrimaryContainer,
          s.primaryContainer,
        ),
        ('onSecondary / secondary', s.onSecondary, s.secondary),
        // Hai khe này ít ai đặt bằng tay, nên chúng là chỗ Flutter điền màu
        // mặc định của nó vào một app đã có bảng màu riêng.
        (
          'onSecondaryContainer / secondaryContainer',
          s.onSecondaryContainer,
          s.secondaryContainer,
        ),
        ('onError / error', s.onError, s.error),
        ('onSurface / nền trang', s.onSurface, theme.scaffoldBackgroundColor),
      ];

      for (final (what, fg, bg) in pairs) {
        test(what, () {
          final r = contrastRatio(fg, bg);

          expect(
            r,
            greaterThanOrEqualTo(4.5),
            reason: '$what ở chế độ $name chỉ đạt ${r.toStringAsFixed(2)}:1.',
          );
        });
      }

      test('outline / surface đạt 3:1', () {
        final r = contrastRatio(s.outline, s.surface);

        expect(
          r,
          greaterThanOrEqualTo(3),
          reason:
              'outline vẽ ranh giới thành phần tương tác — WCAG 1.4.11. '
              'Chỉ đạt ${r.toStringAsFixed(2)}:1.',
        );
      });
    });
  }
}
