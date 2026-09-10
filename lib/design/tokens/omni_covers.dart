import 'package:flutter/material.dart';

/// Tám nền cho thẻ dự án.
///
/// Là TÊN, không phải ảnh: `cover` trên dự án lưu `teal-1`, và app lẫn web mỗi
/// bên dịch tên đó thành gradient của riêng mình. Không endpoint upload, không
/// dung lượng, và — quan trọng nhất — không có bài toán CHỮ ĐÈ LÊN ẢNH: tên dự
/// án viết bằng chữ trắng trên một tấm ảnh sáng hoặc rối thì không đọc được,
/// và người tạo không biết trước điều đó lúc bấm chọn.
///
/// Mọi màu ở đây đủ tối cho chữ trắng; `omni_covers_test.dart` giữ điều đó
/// bằng một ngưỡng độ sáng. Thêm nền mới mà bài kiểm đỏ thì **chỉnh màu, đừng
/// nới ngưỡng** — ngưỡng đó chính là thứ tính năng này hứa.
abstract final class OmniCovers {
  /// Nền của dự án chưa chọn gì — và của MỌI dự án tạo trước tính năng này.
  static const fallback = 'teal-1';

  static const _table = <String, List<Color>>{
    'teal-1': [Color(0xFF0F6E63), Color(0xFF0A4F47)],
    'teal-2': [Color(0xFF12776A), Color(0xFF124E6B)],
    'indigo-1': [Color(0xFF3B3F8F), Color(0xFF24265C)],
    'plum-1': [Color(0xFF6B3070), Color(0xFF3E1C46)],
    'clay-1': [Color(0xFF8A4B2A), Color(0xFF572D19)],
    'amber-2': [Color(0xFF8A6A1F), Color(0xFF553F10)],
    'moss-1': [Color(0xFF3F6B34), Color(0xFF26401F)],
    'slate-1': [Color(0xFF3A4654), Color(0xFF222A33)],
  };

  /// Thứ tự ỔN ĐỊNH — dải chọn nền không được nhảy chỗ giữa hai lần mở.
  static List<String> get names => _table.keys.toList(growable: false);

  /// Tên lạ hoặc null đều rơi về [fallback] chứ KHÔNG ném lỗi.
  ///
  /// Web và app giữ hai bảng riêng (một bên Flutter, một bên CSS); cái phải
  /// đồng bộ là TÊN, không phải màu. Lệch một tên không được làm sập một màn
  /// danh sách ở bên kia.
  static LinearGradient gradientOf(String? name) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: _table[name] ?? _table[fallback]!,
  );
}
