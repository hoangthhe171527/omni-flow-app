/// Thời lượng chuyển động và cỡ icon.
///
/// App có 12 thời lượng và 14 cỡ icon rời rạc trước khi có file này. Đặt tên
/// cho chúng để cái lệch chuẩn hoặc được biện minh, hoặc bị sửa.
library;

import 'package:flutter/animation.dart';

/// Thang thời lượng của bộ giao diện Orbit (`Main.dc.html`, mục "Chuyển động").
abstract final class OmniDuration {
  /// Phản hồi chạm, đổi màu, hiện/ẩn tại chỗ.
  static const fast = Duration(milliseconds: 120);

  /// Đổi trạng thái, mở menu. Mặc định khi không có lý do để nhanh hay chậm.
  static const base = Duration(milliseconds: 200);

  /// Sheet trượt lên, chuyển màn.
  static const slow = Duration(milliseconds: 320);

  /// Hiệu ứng mở app — chạy MỘT lần mỗi lần khởi động (xem `OmniSplash`).
  static const splash = Duration(milliseconds: 1400);
}

/// Đường cong của thang trên: ra nhanh, vào êm — cubic-bezier(.2,.8,.2,1).
abstract final class OmniCurves {
  static const standard = Cubic(0.2, 0.8, 0.2, 1);

  /// Nảy nhẹ khi một chấm "bật" ra — cubic-bezier(.3,1.6,.5,1).
  static const pop = Cubic(0.3, 1.6, 0.5, 1);
}

/// Thang này mô tả app đang làm gì, không phải áp một thang lý thuyết lên nó.
///
/// Đếm thực tế trước khi đặt tên: 18 dùng 13 lần, 20 dùng 11 lần, 16 dùng 9
/// lần. Một thang mà giá trị phổ biến nhất không thuộc về nó thì không ai theo,
/// và đổi 13 chỗ từ 18 sang 20 là đổi diện mạo mà không được gì.
abstract final class OmniIconSize {
  /// Icon tí hon đi kèm chữ micro — chấm trạng thái, nhãn kênh.
  static const double xs = 13;

  /// Icon nhỏ đi kèm chữ caption.
  static const double sm = 16;

  /// Mặc định — icon đi kèm chữ trong danh sách và nút.
  static const double md = 18;

  /// Icon được nhấn mạnh.
  static const double lg = 20;

  /// Icon đứng một mình: thanh điều hướng, nút chỉ có icon.
  static const double xl = 24;

  /// Icon là nội dung chính của màn: trạng thái rỗng, màn báo thành công/lỗi.
  /// Ở cỡ này nó không còn là ký hiệu cạnh chữ nữa mà là hình minh hoạ.
  static const double hero = 44;
}
