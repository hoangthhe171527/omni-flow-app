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
}
