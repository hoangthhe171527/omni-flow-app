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
  /// The design system's `--radius` is 1rem; the rest of the scale derives.
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 14;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double pill = 999;

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
