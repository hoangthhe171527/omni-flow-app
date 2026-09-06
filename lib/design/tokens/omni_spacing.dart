import 'package:flutter/widgets.dart';

abstract final class OmniSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double section = 32;

  /// Standard screen gutter. Every full-width screen uses this and nothing else.
  static const EdgeInsets screen = EdgeInsets.symmetric(horizontal: lg);

  /// Padding inside a card.
  static const EdgeInsets card = EdgeInsets.all(lg);

  /// Bottom padding that clears the tab bar + FAB on scrollable screens.
  static const double bottomSafe = 96;
}

abstract final class OmniRadius {
  /// Thang bo góc.
  ///
  /// Đã hạ từ 16/12 xuống 14/10. Bo quá tròn làm thẻ trông mềm và ăn chỗ — mà
  /// màn hình chính của app là một danh sách dài, nơi mỗi dp chiều cao đều
  /// phải trả giá bằng một dòng chữ ít đi.
  static const double xs = 8;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 14;
  static const double xl = 18;
  static const double xxl = 24;

  /// Chỉ còn cho avatar, chấm đếm và nút tròn.
  static const double pill = 999;

  /// Chip: bộ lọc, trạng thái, thẻ nhãn.
  ///
  /// KHÔNG dùng [pill] cho chip. Một viên bo tròn hoàn toàn đọc như thẻ tag —
  /// thứ để gắn vào — chứ không như bộ lọc, thứ để bật và tắt.
  static const double chip = 8;

  static const BorderRadius chipAll = BorderRadius.all(Radius.circular(chip));

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));

  static const BorderRadius sheet = BorderRadius.only(
    topLeft: Radius.circular(xxl),
    topRight: Radius.circular(xxl),
  );
}

abstract final class OmniShadows {
  /// Depth in this design comes from spacing, not elevation — shadows stay
  /// barely perceptible on purpose.
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0A0F172A), blurRadius: 16, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> raised = [
    BoxShadow(color: Color(0x140F172A), blurRadius: 24, offset: Offset(0, 8)),
  ];

  static const List<BoxShadow> sheet = [
    BoxShadow(color: Color(0x1F0F172A), blurRadius: 32, offset: Offset(0, -8)),
  ];
}
