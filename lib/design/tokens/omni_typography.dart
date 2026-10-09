import 'package:flutter/material.dart';

abstract final class OmniType {
  /// Be Vietnam Pro — font giao diện của mọi màn (giao diện mới GĐ1), thiết kế
  /// cho tiếng Việt nên dấu xếp gọn ở mọi cỡ chữ.
  ///
  /// Đóng gói các độ đậm 400/500/600/700/800 trong `assets/fonts`. Khối Inter
  /// vẫn còn trong pubspec cho golden cũ; xoá ở GĐ6 khi không còn ai dùng.
  static const String family = 'Be Vietnam Pro';

  /// Be Vietnam Pro chỉ còn cho chữ "Viomni" cạnh logo ở màn mở app — nhận
  /// diện thương hiệu đã duyệt, không phải chữ để đọc. Chỉ đóng gói bản 800.
  static const String brandFamily = 'Be Vietnam Pro';

  /// Counts and money use tabular figures so numbers never jitter as they
  /// update in place (unread badges, pipeline totals, message timestamps).
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  // Mọi `height` dưới đây ≥ 1,4: tiếng Việt xếp dấu cả trên lẫn dưới thân
  // chữ (ế, ộ, ữ, ặ), dòng khít hơn thì dấu của dòng dưới chạm chân dòng
  // trên. `type_scale_test.dart` giữ sàn này.

  /// Tiêu đề màn đăng nhập (30, SemiBold).
  static const TextStyle displayLg = TextStyle(
    fontFamily: family,
    fontSize: 30,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: -0.45,
  );

  /// Tiêu đề LỚN của màn gốc mỗi tab ("Việc của tôi", "Tất cả") và của màn
  /// chọn không gian làm việc: 24/600, chữ khít −0,015em.
  static const TextStyle largeTitle = TextStyle(
    fontFamily: family,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: -0.36,
  );

  /// Tiêu đề thanh trên của màn ĐẨY VÀO (có nút quay lại): 17/24, SemiBold.
  static const TextStyle navTitle = TextStyle(
    fontFamily: family,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 24 / 17,
  );

  /// Chữ "Viomni" cạnh logo. Cỡ do chỗ đặt quyết định (22 ở thanh bên, 34 ở
  /// màn mở app) qua `copyWith(fontSize:)` bên trong `lib/design`.
  static const TextStyle wordmark = TextStyle(
    fontFamily: brandFamily,
    fontSize: 22,
    fontWeight: FontWeight.w800,
    height: 1.4,
    letterSpacing: -0.44,
  );

  /// Tên ở đầu màn chi tiết (khách hàng, cơ hội): 20/28.
  static const TextStyle title = TextStyle(
    fontFamily: family,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: -0.2,
  );

  /// Mục, tên thẻ, tên team: 16/22.
  static const TextStyle section = TextStyle(
    fontFamily: family,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  /// Nhãn trên một nhóm trường hoặc một khối: 13/600 chữ phụ, viết thường.
  /// Bản cũ là 12/700 IN HOA giãn chữ — kiểu "tài liệu", không phải "ứng dụng".
  static const TextStyle overline = TextStyle(
    fontFamily: family,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontFamily: family,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 22 / 15,
  );

  /// Thân: 15/22.
  static const TextStyle body = TextStyle(
    fontFamily: family,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 22 / 15,
  );

  /// Phụ, mô tả: 13/18.
  static const TextStyle caption = TextStyle(
    fontFamily: family,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// Cỡ nhỏ nhất của app, và 12 là SÀN, không phải điểm xuất phát để bớt.
  ///
  /// Từng là 11. Đây là style của `labelSmall` — dòng phụ của mọi dòng việc,
  /// giờ trên thẻ, nhãn điều hướng — và tiếng Việt xếp dấu cả trên lẫn dưới
  /// thân chữ: ở 11px, "Hằng" và "Hắng" đọc như nhau ở khoảng cách một cánh
  /// tay ngoài xưởng. `type_scale_test.dart` giữ sàn này.
  static const TextStyle micro = TextStyle(
    fontFamily: family,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  /// Chữ trong chip lọc và nút phân đoạn: 14, độ đậm đổi theo trạng thái chọn
  /// qua copyWith.
  static const TextStyle chip = TextStyle(
    fontFamily: family,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  /// Ô nhập liệu và ô tìm kiếm. 16 là ngưỡng iOS Safari/WebView không tự
  /// phóng to khi focus, và là cỡ tay gõ đọc lại được thứ mình vừa gõ.
  static const TextStyle input = TextStyle(
    fontFamily: family,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// Dòng chính của một hàng danh sách (tên hội thoại, tên khách hàng): 16,
  /// to hơn thân một bậc để mắt quét cột tên trước, nhưng không phải tiêu đề.
  /// Trạng thái đọc/chưa đọc đổi độ đậm qua copyWith.
  static const TextStyle listTitle = TextStyle(
    fontFamily: family,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  static const TextStyle money = TextStyle(
    fontFamily: family,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 24 / 17,
    fontFeatures: tabular,
  );

  static const TextStyle moneyHero = TextStyle(
    fontFamily: family,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: -0.42,
    fontFeatures: tabular,
  );

  static TextTheme textTheme(Color onSurface, Color onSurfaceMuted) {
    return TextTheme(
      displayLarge: displayLg.copyWith(color: onSurface),
      titleLarge: title.copyWith(color: onSurface),
      titleMedium: section.copyWith(color: onSurface),
      titleSmall: bodyStrong.copyWith(color: onSurface),
      bodyLarge: body.copyWith(color: onSurface),
      bodyMedium: body.copyWith(color: onSurfaceMuted),
      bodySmall: caption.copyWith(color: onSurfaceMuted),
      labelLarge: bodyStrong.copyWith(color: onSurface),
      labelMedium: caption.copyWith(color: onSurfaceMuted),
      labelSmall: micro.copyWith(color: onSurfaceMuted),
    );
  }
}

/// The messaging screens speak THREE type sizes and no more.
///
/// Before this the thread used four different sizes below 12 (10, 10, 10, 11)
/// for the same class of information, and `micro` — the style all of them went
/// through — is w600, so every scrap of metadata was tiny AND bold. Meta is
/// supposed to recede; small bold text reads as noise, not as hierarchy.
///
/// Sizes are deliberately a little larger than a Latin-only app would use, and
/// the line-height is at least 1.4 rather than the usual 1.3–1.35: Vietnamese
/// stacks diacritics both above and below the x-height (ế, ộ, ữ, ằ), and tighter
/// leading makes consecutive lines collide.
abstract final class OmniChatType {
  /// The message itself — the only thing on the screen meant to be read.
  static const TextStyle message = TextStyle(
    fontFamily: OmniType.family,
    fontSize: 15.5,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  /// The person you are talking to, in the app bar.
  static const TextStyle peer = TextStyle(
    fontFamily: OmniType.family,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  /// EVERY piece of metadata: timestamps, the day separator, the app bar
  /// subtitle, delivery state. One size, one weight, deliberately not bold.
  static const TextStyle meta = TextStyle(
    fontFamily: OmniType.family,
    fontSize: 11.5,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  /// Emoji trong lưới chọn của composer — một glyph để chạm, không phải chữ
  /// để đọc, nên nằm ngoài thang trên. Cỡ này vừa một ô của lưới 8 cột trên
  /// màn 360dp mà vẫn chạm được.
  static const TextStyle emoji = TextStyle(fontSize: 26, height: 1.2);
}
