import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/tokens/tokens.dart';

/// Tương phản là thứ không ai nhìn ra bằng mắt và ai cũng tưởng mình đã kiểm.
///
/// Lỗi thật đã xảy ra trong repo này: chữ phụ đạt 4.35:1 ở chế độ sáng và
/// 6.92:1 ở chế độ tối, nên người kiểm tra chế độ tối kết luận là đạt. Test này
/// tính ra con số, cho cả hai theme, nên cả loại lỗi đó bị chặn chứ không chỉ
/// một token.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;

  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  // Ngưỡng WCAG AA cho chữ cỡ thường.
  const body = 4.5;

  group('chế độ sáng', () {
    test('chữ chính trên thẻ và trên nền trang', () {
      expect(
        contrast(OmniColors.foreground, OmniColors.card),
        greaterThanOrEqualTo(body),
      );
      expect(
        contrast(OmniColors.foreground, OmniColors.background),
        greaterThanOrEqualTo(body),
      );
    });

    test('chữ phụ trên thẻ và trên nền trang', () {
      // Nền trang là chỗ khó nhất, và cũng là chỗ chữ phụ nằm nhiều nhất.
      expect(
        contrast(OmniColors.mutedForeground, OmniColors.card),
        greaterThanOrEqualTo(body),
      );
      expect(
        contrast(OmniColors.mutedForeground, OmniColors.background),
        greaterThanOrEqualTo(body),
      );
    });

    test('màu ngữ nghĩa dùng làm chữ', () {
      // success/warning/destructive là màu TÔ tốt và màu CHỮ tồi. Ba biến thể
      // này tồn tại để chỗ nào cần chữ thì có cái để dùng.
      expect(
        contrast(OmniColors.successText, OmniColors.card),
        greaterThanOrEqualTo(body),
      );
      expect(
        contrast(OmniColors.warningText, OmniColors.card),
        greaterThanOrEqualTo(body),
      );
      expect(
        contrast(OmniColors.dangerText, OmniColors.card),
        greaterThanOrEqualTo(body),
      );
    });
  });

  group('chế độ tối', () {
    test('chữ chính và chữ phụ trên thẻ tối', () {
      expect(
        contrast(OmniColors.darkForeground, OmniColors.darkCard),
        greaterThanOrEqualTo(body),
      );
      expect(
        contrast(OmniColors.darkMutedForeground, OmniColors.darkCard),
        greaterThanOrEqualTo(body),
      );
    });

    test('chữ phụ trên nền tối', () {
      expect(
        contrast(OmniColors.darkMutedForeground, OmniColors.darkBackground),
        greaterThanOrEqualTo(body),
      );
    });
  });
}
