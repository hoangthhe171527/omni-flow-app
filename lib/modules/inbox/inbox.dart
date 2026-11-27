/// Mặt tiền công khai của module hộp thư.
///
/// Màn Tổng quan (module dashboard) vẽ dòng hội thoại ở thẻ "Chờ phản hồi" —
/// nó lấy widget ở đây, không với vào `presentation/` của inbox.
library;

// Lớp dữ liệu Tổng quan được mượn (đếm hội thoại chờ phản hồi).
export 'data/inbox_api.dart' show InboxApi, inboxApiProvider;
export 'presentation/widgets/conversation_row.dart';
