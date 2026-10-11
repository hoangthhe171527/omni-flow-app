import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/tokens/contrast.dart';
import 'package:omni_app/design/tokens/omni_covers.dart';
import 'package:omni_app/design/tokens/omni_label_colors.dart';

/// Màu nhãn việc đến từ server (`TASK_LABEL.color`, chuỗi hex). App phải
/// đọc được mọi dạng hợp lệ, rơi về `fallback` khi rỗng hoặc sai, và chọn chữ
/// đọc được trên nền đó.
void main() {
  group('parseHex', () {
    test('#RRGGBB ra đúng màu', () {
      expect(OmniLabelColors.parseHex('#B42318'), const Color(0xFFB42318));
    });

    test('không có # và chữ thường vẫn đọc được', () {
      expect(OmniLabelColors.parseHex('ef4444'), const Color(0xFFEF4444));
      expect(OmniLabelColors.parseHex(' #0e7490 '), const Color(0xFF0E7490));
    });

    test('#RGB mở rộng thành #RRGGBB', () {
      expect(OmniLabelColors.parseHex('#f80'), const Color(0xFFFF8800));
    });

    test('sai hoặc rỗng → fallback', () {
      for (final raw in [
        null,
        '',
        'xx',
        '#12345',
        '#GGGGGG',
        'red',
        '#1234567',
      ]) {
        expect(
          OmniLabelColors.parseHex(raw),
          OmniLabelColors.fallback,
          reason: '$raw',
        );
      }
    });
  });

  group('chữ trên dải nhãn', () {
    test('nền tối (bản mẫu) giữ chữ trắng, đạt 4.5', () {
      for (final hex in [
        '#B42318',
        '#0E7490',
        '#6D28D9',
        '#B45309',
        '#56637A',
      ]) {
        final bg = OmniLabelColors.parseHex(hex);
        final fg = OmniLabelColors.textOn(bg);
        expect(fg, OmniLabelColors.lightText, reason: hex);
        expect(contrastRatio(fg, bg), greaterThanOrEqualTo(4.5), reason: hex);
      }
    });

    test('nền quá sáng đổi sang chữ mực #0B1A33', () {
      for (final hex in ['#f59e0b', '#22c55e', '#FFFFFF', '#E6F3F2']) {
        final bg = OmniLabelColors.parseHex(hex);
        expect(
          OmniLabelColors.textOn(bg),
          OmniLabelColors.darkText,
          reason: hex,
        );
        expect(OmniLabelColors.darkText, const Color(0xFF0B1A33));
      }
    });

    test('mọi màu mặc định của server: chữ chọn ra không kém chữ kia', () {
      // SystemOptionCatalog::TASK_LABEL
      for (final hex in [
        '#ef4444',
        '#f59e0b',
        '#3b82f6',
        '#22c55e',
        '#8b5cf6',
      ]) {
        final bg = OmniLabelColors.parseHex(hex);
        final fg = OmniLabelColors.textOn(bg);
        final other = fg == OmniLabelColors.lightText
            ? OmniLabelColors.darkText
            : OmniLabelColors.lightText;
        expect(
          contrastRatio(fg, bg),
          greaterThanOrEqualTo(contrastRatio(other, bg)),
          reason: hex,
        );
      }
    });
  });

  test('kính tối của header bảng: rgba(20,44,58,.55), blur 20', () {
    expect(OmniCovers.glass, const Color.fromRGBO(20, 44, 58, .55));
    expect(OmniCovers.glassBlur, 20);
  });
}
