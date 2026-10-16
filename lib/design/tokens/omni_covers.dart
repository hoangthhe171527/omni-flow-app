import 'package:flutter/material.dart';

/// Hợp đồng nền của dự án.
///
/// Các token gradient cũ. API cũng có thể trả URL ảnh trong `cover`; phần nhận
/// diện URL và fallback màu hệ thống nằm ở `ProjectCoverSurface`.
///
/// [colorOf] và [gradientOf] được giữ tạm để các bản app cũ / phần đang chuyển
/// đổi vẫn biên dịch. UI mới không được dùng chúng để dựng nền dự án.
abstract final class OmniCovers {
  /// Token cũ từng được dùng làm mặc định.
  static const fallback = 'teal-1';

  /// Kính tối của header bảng kế hoạch (`Board.dc.html .bar`):
  /// `rgba(20,44,58,.55)` phủ trên nền cover, cộng [glassBlur].
  static const glass = Color.fromRGBO(20, 44, 58, .55);

  /// Độ nhoè (sigma) của lớp kính tối.
  static const double glassBlur = 20;

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

  /// Danh sách token cũ, chỉ dùng để phân biệt với URL ảnh.
  static List<String> get names => _table.keys.toList(growable: false);

  static bool isLegacyName(String? value) =>
      value != null && _table.containsKey(value.trim());

  /// Có vẻ là một tham chiếu ảnh hợp lệ để tầng dữ liệu chuẩn hoá thành URL.
  ///
  /// Không coi chuỗi bất kỳ là ảnh: token cũ và scheme ngoài HTTP(S) phải rơi
  /// về nền hệ thống thay vì đi vào một `NetworkImage` không an toàn.
  static bool isImageReference(String? value) {
    final source = value?.trim() ?? '';
    if (source.isEmpty || isLegacyName(source)) return false;
    final uri = Uri.tryParse(source);
    if (uri == null) return false;
    if (!uri.hasScheme) return source.startsWith('/');
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  /// API tương thích tạm cho phần UI cũ chưa được chuyển trong lane khác.
  @Deprecated('Dùng ảnh cover hoặc màu surface của theme.')
  static Color colorOf(String? name) =>
      (_table[name] ?? _table[fallback]!).first;

  @Deprecated('Dùng ảnh cover hoặc màu surface của theme.')
  static LinearGradient gradientOf(String? name) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: _table[name] ?? _table[fallback]!,
  );
}
