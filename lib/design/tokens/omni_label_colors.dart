import 'package:flutter/painting.dart';

/// Màu chấm phân loại nhãn ở mép trái dòng hội thoại/khách (bản thiết kế
/// GĐ3). Nhãn không có trong bảng ra xám — màu không bao giờ mang nghĩa một
/// mình, chấm luôn có `Semantics(label: 'Nhãn: …')`.
abstract final class OmniLabelColors {
  static const fallback = Color(0xFF8A95A8);

  static const _known = <String, Color>{
    'Đặt lịch': Color(0xFF0A7D76),
    'Báo giá': Color(0xFFE8890C),
    'Hợp đồng': Color(0xFF2563EB),
    'Khiếu nại': Color(0xFFDC2626),
  };

  static Color of(String? label) => _known[label?.trim()] ?? fallback;
}
