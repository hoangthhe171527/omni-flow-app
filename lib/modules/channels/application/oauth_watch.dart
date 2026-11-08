import '../domain/channel_connection.dart';

/// Thời gian tối đa chờ người dùng hoàn tất OAuth trong trình duyệt — chỉ tính
/// thời gian app ở TIỀN CẢNH (lúc người dùng đang ở trình duyệt, app không
/// poll và đồng hồ không chạy).
const oauthWatchTimeout = Duration(minutes: 3);

/// Nhịp kiểm tra danh sách kênh trong khi chờ OAuth.
const oauthWatchInterval = Duration(seconds: 3);

/// Nhịp của lượt kiểm tra thứ [attempt] (0, 1, 2…): 3 → 5 → 8 giây rồi giữ 8.
Duration oauthWatchDelay(int attempt) => switch (attempt) {
  <= 0 => oauthWatchInterval,
  1 => const Duration(seconds: 5),
  _ => const Duration(seconds: 8),
};

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
