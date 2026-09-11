import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/tokens/contrast.dart';
import 'package:omni_app/design/tokens/tokens.dart';

/// Bộ nền phải đủ nhạt (sáng) / đủ đậm (tối) để chữ vẽ thẳng lên nền còn
/// đọc được, và không được ném lỗi vì một cái tên lạ từ server.
void main() {
  test('có đúng tám nền, không trùng, ASCII thường', () {
    expect(OmniBackdrops.names, hasLength(8));
    expect(OmniBackdrops.names.toSet(), hasLength(8));
    for (final n in OmniBackdrops.names) {
      expect(RegExp(r'^[a-z]+$').hasMatch(n), isTrue, reason: n);
    }
  });

  test('tên nào cũng có nhãn tiếng Việt và spec cho cả hai chế độ', () {
    for (final n in OmniBackdrops.names) {
      expect(OmniBackdrops.labelOf(n), isNotEmpty);
      expect(OmniBackdrops.specOf(n, Brightness.light), isNotNull);
      expect(OmniBackdrops.specOf(n, Brightness.dark), isNotNull);
    }
  });

  test('null và tên lạ → null, KHÔNG ném lỗi', () {
    // Server có thể trả một tên app này chưa biết. Màn chat không được sập
    // vì một tuỳ chọn trang trí.
    expect(OmniBackdrops.specOf(null, Brightness.light), isNull);
    expect(OmniBackdrops.specOf('go-oc-cho', Brightness.dark), isNull);
    expect(OmniBackdrops.labelOf('go-oc-cho'), isNull);
  });

  test('chữ phụ đọc được trên MỌI điểm của MỌI nền, sáng lẫn tối', () {
    // Giờ và vạch ngày trong chat vẽ thẳng lên nền. 4,5:1 là WCAG AA.
    // Bài này đỏ thì CHỈNH MÀU (pha thêm trắng/đen), đừng nới ngưỡng.
    for (final n in OmniBackdrops.names) {
      final light = OmniBackdrops.specOf(n, Brightness.light)!;
      final dark = OmniBackdrops.specOf(n, Brightness.dark)!;
      for (final c in [light.top, light.bottom]) {
        final r = contrastRatio(OmniColors.mutedForeground, c);
        expect(
          r,
          greaterThanOrEqualTo(4.5),
          reason: '$n sáng: ${r.toStringAsFixed(2)}',
        );
      }
      for (final c in [dark.top, dark.bottom]) {
        final r = contrastRatio(OmniColors.darkMutedForeground, c);
        expect(
          r,
          greaterThanOrEqualTo(4.5),
          reason: '$n tối: ${r.toStringAsFixed(2)}',
        );
      }
    }
  });

  test('hoạ tiết mờ, không rối', () {
    expect(OmniBackdrops.patternAlpha, lessThanOrEqualTo(0.06));
  });
}
