import '../../../security/permissions/access_policy.dart';

/// Slug quyền của module kênh, khớp `modules/Channels/Interfaces/routes.php`.
///
/// `read` là toàn tenant, `readOwn` chỉ những tài khoản chính người này ghép
/// nối (`owner_user_id = me`). Server tự cắt danh sách theo slug người dùng
/// giữ, nên client không lọc lại — nó chỉ cần biết ai được *mở màn hình*.
abstract final class ChannelPermissions {
  static const read = 'channels.read';
  static const readOwn = 'channels.read.own';
  static const write = 'channels.write';

  static const anyRead = [read, readOwn];

  static const all = [read, readOwn, write];

  /// Đọc kênh toàn tenant (cùng nghĩa [read]); API chấp nhận cả hai.
  static const readAll = 'channels.read.all';

  /// Được kết nối kênh CÔNG TY (Facebook Page, Zalo OA… qua OAuth).
  ///
  /// Quyết định 2026-10-04 #3: Page/OA chỉ admin kết nối. API chặn
  /// `oauth/redirect` bằng quyền đọc kênh toàn tenant cộng [write]; sale
  /// (`read.own` + `write`) chỉ tự ghép nối tài khoản cá nhân. Kiểm ĐÚNG
  /// slug, không suy `read` từ `write`. Không có slug `*`: API so khớp
  /// chính xác (`*` chỉ là scope của JWT), và chủ workspace nhận đủ slug thật.
  static bool canConnectCompany(AccessPolicy access) =>
      (access.can(read) || access.can(readAll)) && access.can(write);
}
