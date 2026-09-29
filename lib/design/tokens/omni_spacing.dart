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
  /// Thang bo góc của bộ giao diện Orbit.
  ///
  /// Nút và ô nhập 12, ô icon 14, thẻ 16, thẻ lớn và sheet 20 — đúng như các
  /// màn trong artifact đã duyệt đang dùng.
  static const double xs = 8;
  static const double sm = 10;
  static const double md = 12;
  static const double lg = 14;
  static const double xl = 16;
  static const double xxl = 20;

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
  static const BorderRadius xxlAll = BorderRadius.all(Radius.circular(xxl));
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
    BoxShadow(color: Color(0x0A0B1A33), blurRadius: 16, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> raised = [
    BoxShadow(color: Color(0x0F0B1A33), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x140B1A33), blurRadius: 24, offset: Offset(0, 8)),
  ];

  static const List<BoxShadow> sheet = [
    BoxShadow(color: Color(0x1F0B1A33), blurRadius: 32, offset: Offset(0, -8)),
  ];
}
