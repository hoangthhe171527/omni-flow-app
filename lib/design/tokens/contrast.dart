import 'dart:math' as math;
import 'dart:ui';

/// Độ chói tương đối theo WCAG 2.1.
///
/// Flutter đã có `Color.computeLuminance()` với đúng công thức này. Viết lại
/// ở đây vì `contrast_test.dart` cần đối chiếu kết quả với hai mốc do W3C
/// định nghĩa — đen/trắng = 21:1, một màu với chính nó = 1:1. Nếu chỉ gọi
/// hàm của Flutter thì bài test đó chỉ chứng minh Flutter đúng, chứ không
/// chứng minh phép đo trong app này đúng.
double relativeLuminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// Tỉ lệ tương phản WCAG giữa hai màu ĐỤC. Thứ tự không quan trọng.
///
/// Ngưỡng cần nhớ: 4.5 cho chữ thường, 3.0 cho chữ lớn và cho ranh giới của
/// thành phần tương tác (WCAG 1.4.11).
///
/// Màu bán trong suốt cho ra số vô nghĩa — công thức không biết cái gì nằm
/// dưới. Hãy tự trộn với nền trước khi gọi.
double contrastRatio(Color a, Color b) {
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);

  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}
