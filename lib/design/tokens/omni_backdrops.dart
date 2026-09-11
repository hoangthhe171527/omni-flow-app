import 'package:flutter/material.dart';

/// Hoạ tiết phủ lên gradient. Alpha cố định ở [OmniBackdrops.patternAlpha].
enum OmniBackdropPattern { none, dots, diagonal, grain }

/// Một nền: gradient trên → dưới + hoạ tiết.
class OmniBackdropSpec {
  const OmniBackdropSpec({
    required this.top,
    required this.bottom,
    required this.pattern,
  });

  final Color top;
  final Color bottom;
  final OmniBackdropPattern pattern;
}

/// Tám nền cho cả app, chọn ở menu tài khoản, lưu trên tài khoản.
///
/// Là TÊN: server lưu `walnut`, app và web mỗi bên dịch tên ra gradient của
/// mình (web: `src/lib/backdrops.ts`). Cái phải đồng bộ là tên —
/// `backdrop_names_match_web_test.dart` giữ.
///
/// Mọi màu đủ nhạt (sáng) / đủ đậm (tối) để chữ phụ vẽ thẳng lên nền đọc
/// được; `omni_backdrops_test.dart` đo bằng WCAG. Thêm nền mà bài kiểm đỏ
/// thì pha thêm trắng/đen vào màu, đừng nới ngưỡng.
abstract final class OmniBackdrops {
  static const double patternAlpha = 0.06;

  static const _labels = <String, String>{
    'mist': 'Sương sớm',
    'ivory': 'Ngà phím',
    'walnut': 'Gỗ óc chó',
    'felt': 'Nỉ búa',
    'brass': 'Dây đồng',
    'graphite': 'Than chì',
    'sea': 'Biển',
    'dawn': 'Rạng đông',
  };

  static const _light = <String, OmniBackdropSpec>{
    'mist': OmniBackdropSpec(
      top: Color(0xFFEEF6F4),
      bottom: Color(0xFFE7F2EE),
      pattern: OmniBackdropPattern.dots,
    ),
    'ivory': OmniBackdropSpec(
      top: Color(0xFFF9F6EE),
      bottom: Color(0xFFF4EFE4),
      pattern: OmniBackdropPattern.diagonal,
    ),
    'walnut': OmniBackdropSpec(
      top: Color(0xFFF5ECE4),
      bottom: Color(0xFFF3E7DC),
      pattern: OmniBackdropPattern.grain,
    ),
    'felt': OmniBackdropSpec(
      top: Color(0xFFF8EDED),
      bottom: Color(0xFFF4E6E6),
      pattern: OmniBackdropPattern.dots,
    ),
    'brass': OmniBackdropSpec(
      top: Color(0xFFF7F2E6),
      bottom: Color(0xFFF2EBDA),
      pattern: OmniBackdropPattern.diagonal,
    ),
    'graphite': OmniBackdropSpec(
      top: Color(0xFFF0F2F4),
      bottom: Color(0xFFE9EDF1),
      pattern: OmniBackdropPattern.dots,
    ),
    'sea': OmniBackdropSpec(
      top: Color(0xFFEBF3F8),
      bottom: Color(0xFFE4EEF4),
      pattern: OmniBackdropPattern.grain,
    ),
    'dawn': OmniBackdropSpec(
      top: Color(0xFFFAF1EB),
      bottom: Color(0xFFF0E7F0),
      pattern: OmniBackdropPattern.none,
    ),
  };

  static const _dark = <String, OmniBackdropSpec>{
    'mist': OmniBackdropSpec(
      top: Color(0xFF15211F),
      bottom: Color(0xFF0F1817),
      pattern: OmniBackdropPattern.dots,
    ),
    'ivory': OmniBackdropSpec(
      top: Color(0xFF232019),
      bottom: Color(0xFF191712),
      pattern: OmniBackdropPattern.diagonal,
    ),
    'walnut': OmniBackdropSpec(
      top: Color(0xFF2A1F18),
      bottom: Color(0xFF1C1511),
      pattern: OmniBackdropPattern.grain,
    ),
    'felt': OmniBackdropSpec(
      top: Color(0xFF2B1A1C),
      bottom: Color(0xFF1E1214),
      pattern: OmniBackdropPattern.dots,
    ),
    'brass': OmniBackdropSpec(
      top: Color(0xFF2A2416),
      bottom: Color(0xFF1B1810),
      pattern: OmniBackdropPattern.diagonal,
    ),
    'graphite': OmniBackdropSpec(
      top: Color(0xFF1B1F24),
      bottom: Color(0xFF11141A),
      pattern: OmniBackdropPattern.dots,
    ),
    'sea': OmniBackdropSpec(
      top: Color(0xFF14222B),
      bottom: Color(0xFF0E181F),
      pattern: OmniBackdropPattern.grain,
    ),
    'dawn': OmniBackdropSpec(
      top: Color(0xFF2A1E24),
      bottom: Color(0xFF1A141C),
      pattern: OmniBackdropPattern.none,
    ),
  };

  /// Thứ tự ỔN ĐỊNH — lưới chọn không được nhảy chỗ giữa hai lần mở.
  static List<String> get names => _labels.keys.toList(growable: false);

  static String? labelOf(String? name) => _labels[name];

  /// null hoặc tên lạ → null, KHÔNG ném lỗi: một tuỳ chọn trang trí không
  /// được làm sập màn chat.
  static OmniBackdropSpec? specOf(String? name, Brightness brightness) =>
      name == null
      ? null
      : (brightness == Brightness.dark ? _dark : _light)[name];
}
