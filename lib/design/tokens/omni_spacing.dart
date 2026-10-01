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
  /// Thang bo góc của đề xuất "Chuẩn hoá phong cách" (`SPrinciples.dc.html`).
  ///
  /// App: chip trạng thái 4, chip lọc 6, nút và ô nhập 8, thẻ 10, nút nổi 12,
  /// sheet 16. Bo tròn hẳn ([pill]) chỉ cho avatar, chấm và số đếm.
  static const double xs = 4;
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 8;
  static const double xl = 10;
  static const double xxl = 16;

  /// Nút nổi ("Tạo mới", "Thêm khách").
  static const double fab = 12;

  /// Chỉ còn cho avatar, chấm đếm và nút tròn.
  static const double pill = 999;

  /// Chip LỌC và chip chọn trong biểu mẫu.
  ///
  /// KHÔNG dùng [pill] cho chip. Một viên bo tròn hoàn toàn đọc như thẻ tag —
  /// thứ để gắn vào — chứ không như bộ lọc, thứ để bật và tắt. Chip TRẠNG THÁI
  /// (chỉ để đọc) dùng [xs].
  static const double chip = 6;

  static const BorderRadius chipAll = BorderRadius.all(Radius.circular(chip));

  static const BorderRadius xsAll = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius xxlAll = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius fabAll = BorderRadius.all(Radius.circular(fab));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));

  static const BorderRadius sheet = BorderRadius.only(
    topLeft: Radius.circular(xxl),
    topRight: Radius.circular(xxl),
  );
}

/// Viền thay bóng: thẻ, bảng, cột chỉ có viền #E3E8EF. Bóng chỉ dành cho thứ
/// đang NỔI trên màn — menu, popover, sheet, hộp thoại, nút nổi.
abstract final class OmniShadows {
  /// Thẻ không có bóng. Giữ tên để chỗ gọi cũ không phải đoán.
  static const List<BoxShadow> card = [];

  /// Thứ đang nổi: menu, popover, ô QR nổi trên nền mực. Màu trung tính —
  /// không bao giờ là bóng màu thương hiệu.
  static const List<BoxShadow> raised = [
    BoxShadow(color: Color(0x1F0B1A33), blurRadius: 16, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> sheet = [
    BoxShadow(color: Color(0x1F0B1A33), blurRadius: 32, offset: Offset(0, -8)),
  ];
}
