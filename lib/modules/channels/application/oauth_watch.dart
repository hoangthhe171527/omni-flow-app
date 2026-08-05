import '../domain/channel_connection.dart';

/// Thời gian tối đa chờ người dùng hoàn tất OAuth trong trình duyệt.
const oauthWatchTimeout = Duration(minutes: 3);

/// Nhịp kiểm tra danh sách kênh trong khi chờ OAuth.
const oauthWatchInterval = Duration(seconds: 3);

/// Id kết nối xuất hiện sau khi bắt đầu OAuth, hoặc null nếu chưa có gì mới.
///
/// So theo tập id thay vì tổng số kênh: một kênh khác có thể bị ngắt trong
/// lúc chờ, khiến tổng không đổi dù kết nối mới đã xuất hiện.
String? firstNewId(Set<String> before, List<ChannelConnection> now) {
  for (final connection in now) {
    if (!before.contains(connection.id)) return connection.id;
  }
  return null;
}
