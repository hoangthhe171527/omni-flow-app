import 'package:flutter/painting.dart';

import 'contrast.dart';

/// Màu chấm phân loại nhãn ở mép trái dòng hội thoại/khách (bản thiết kế
/// GĐ3). Nhãn không có trong bảng ra xám — màu không bao giờ mang nghĩa một
/// mình, chấm luôn có `Semantics(label: 'Nhãn: …')`.
///
/// Cũng là chỗ đọc màu nhãn VIỆC (`TASK_LABEL.color`, chuỗi hex do server
/// trả): [parseHex] và [textOn].
abstract final class OmniLabelColors {
  static const fallback = Color(0xFF8A95A8);

  /// Chữ trên dải nhãn: trắng theo bản mẫu, mực khi nền quá sáng.
  static const lightText = Color(0xFFFFFFFF);
  static const darkText = Color(0xFF0B1A33);

  static const _known = <String, Color>{
    'Đặt lịch': Color(0xFF0A7D76),
    'Báo giá': Color(0xFFE8890C),
    'Hợp đồng': Color(0xFF2563EB),
    'Khiếu nại': Color(0xFFDC2626),
  };

  static Color of(String? label) => _known[label?.trim()] ?? fallback;

  static final _hex = RegExp(r'^#?([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$');

  /// Màu từ chuỗi hex `#RRGGBB` / `RRGGBB` / `#RGB` (luôn đục).
  ///
  /// Rỗng, null hay sai dạng đều ra [fallback] chứ không ném: màu do người
  /// dùng nhập ở web, và một chuỗi gõ nhầm không được làm vỡ cả thẻ việc.
  static Color parseHex(String? raw) {
    final match = _hex.firstMatch(raw?.trim() ?? '');
    if (match == null) return fallback;

    var digits = match.group(1)!;
    if (digits.length == 3) {
      digits = digits.split('').map((c) => '$c$c').join();
    }

    return Color(0xFF000000 | int.parse(digits, radix: 16));
  }

  /// Chữ đọc được trên nền nhãn [background].
  ///
  /// Trắng khi đạt 4.5 (chữ thường, WCAG 1.4.3) — đúng bản mẫu. Không đạt thì
  /// lấy màu nào tương phản CAO HƠN giữa trắng và mực: màu server mặc định
  /// như `#f59e0b` quá sáng cho chữ trắng.
  static Color textOn(Color background) {
    final bg = background.withValues(alpha: 1);
    final light = contrastRatio(lightText, bg);
    if (light >= 4.5) return lightText;

    return contrastRatio(darkText, bg) > light ? darkText : lightText;
  }
}
