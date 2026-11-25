import 'package:flutter/material.dart';

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
  static const double bottomSafe = 112;
}

abstract final class OmniRadius {
  /// Thang bo góc phong cách iOS (spec 2026-11-25 §3.5): nhãn 6 · ô nhập 10 ·
  /// nhóm/thẻ 16 · sheet 32 · nút tròn hẳn. Không dùng số khác.
  static const double xs = 6;
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 10;
  static const double xl = 16;
  static const double xxl = 32;

  /// Nút nổi ("Tạo mới", "Thêm khách"): viên thuốc như mọi nút.
  static const double fab = pill;

  /// Chỉ còn cho avatar, chấm đếm và nút tròn.
  static const double pill = 999;

  /// Chip LỌC và chip chọn trong biểu mẫu: ô bo 10 (spec §3.4 "Chip chọn").
  ///
  /// KHÔNG dùng [pill] cho chip. Một viên bo tròn hoàn toàn đọc như thẻ tag —
  /// thứ để gắn vào — chứ không như bộ lọc, thứ để bật và tắt. Chip TRẠNG THÁI
  /// (chỉ để đọc) dùng [xs].
  static const double chip = 10;

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

/// Bóng theo Chuẩn Mobile UI: thẻ nhóm / khối tổng có `shadow-card` rất nhẹ
/// (lớp premium 25/11); thẻ viền thường vẫn chỉ viền #E3E8EF. Bóng đậm chỉ
/// dành cho thứ đang NỔI — menu, popover, sheet, hộp thoại, nút nổi.
abstract final class OmniShadows {
  /// Thẻ viền thường không có bóng. Giữ tên để chỗ gọi cũ không phải đoán.
  static const List<BoxShadow> card = [];

  /// `shadow-card` sáng: vòng 0.5 + bóng gần 1/2 + bóng xa 8/24 (−12).
  static const List<BoxShadow> groupLight = [
    BoxShadow(color: Color(0x120B1A33), spreadRadius: 0.5),
    BoxShadow(color: Color(0x0A0B1A33), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(
      color: Color(0x1A0B1A33),
      blurRadius: 24,
      spreadRadius: -12,
      offset: Offset(0, 8),
    ),
  ];

  /// `shadow-card` tối: chỉ vòng sáng 0.5 — bóng đen không thấy trên nền tối.
  static const List<BoxShadow> groupDark = [
    BoxShadow(color: Color(0x12FFFFFF), spreadRadius: 0.5),
  ];

  /// Bóng của thẻ nhóm (`OmniGroupSection`, `OmniTotalCard`) theo chế độ.
  /// Tương phản cao: không bóng — thẻ đã có viền rõ từ theme.
  static List<BoxShadow> groupOf(BuildContext context) {
    if (MediaQuery.highContrastOf(context)) return const [];
    return Theme.of(context).brightness == Brightness.dark
        ? groupDark
        : groupLight;
  }

  /// Thứ đang nổi: menu, popover, ô QR nổi trên nền mực. Màu trung tính —
  /// không bao giờ là bóng màu thương hiệu.
  static const List<BoxShadow> raised = [
    BoxShadow(color: Color(0x1F0B1A33), blurRadius: 16, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> sheet = [
    BoxShadow(color: Color(0x1F0B1A33), blurRadius: 32, offset: Offset(0, -8)),
  ];

  /// Thẻ việc đang nhấc khỏi bảng kế hoạch (`AppBoard.dc.html`):
  /// `0 18 40 rgba(11,26,51,.35)`.
  static const List<BoxShadow> lifted = [
    BoxShadow(color: Color(0x590B1A33), blurRadius: 40, offset: Offset(0, 18)),
  ];

  /// Dòng đang được kéo ở trang sắp xếp nhóm việc (`AppSections.dc.html`):
  /// `0 10 26 rgba(11,26,51,.18)`.
  static const List<BoxShadow> dragging = [
    BoxShadow(color: Color(0x2E0B1A33), blurRadius: 26, offset: Offset(0, 10)),
  ];
}
