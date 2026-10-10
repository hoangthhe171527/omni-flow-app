/// Tên và đường dẫn route của hộp thư.
///
/// Tách khỏi `inbox_module.dart` để phá vòng import: module import các trang,
/// nên trang không được import ngược module chỉ để lấy một cái tên route.
abstract final class InboxRoutes {
  static const list = 'inbox.list';
  static const thread = 'inbox.thread';
  static const threadInfo = 'inbox.threadInfo';

  static const listPath = '/inbox';
  static const threadPath = '/inbox/:id';
  static const threadInfoPath = '/inbox/:id/info';
}
