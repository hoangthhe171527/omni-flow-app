/// Thời lượng chuyển động và cỡ icon.
///
/// App có 12 thời lượng và 14 cỡ icon rời rạc trước khi có file này. 220ms và
/// 16/20/24 đã là chuẩn trên thực tế; đặt tên cho chúng để cái lệch chuẩn hoặc
/// được biện minh, hoặc bị sửa.
library;

abstract final class OmniDuration {
  /// Phản hồi chạm, đổi màu, hiện/ẩn tại chỗ.
  static const fast = Duration(milliseconds: 140);

  /// Mặc định. Dùng khi không có lý do để nhanh hơn hay chậm hơn.
  static const base = Duration(milliseconds: 220);

  /// Sheet trượt lên, chuyển màn bên trong một màn.
  static const slow = Duration(milliseconds: 350);
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
