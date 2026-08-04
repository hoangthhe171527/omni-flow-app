import '../../../core/domain/channel.dart';
import '../../../core/utils/json.dart';

/// Trạng thái của một *kết nối*, khác với [Channel] là *nền tảng*.
///
/// `pending` là một ghép nối đã bắt đầu mà chưa xong — nó KHÁC `disconnected`:
/// gộp hai cái làm một thì một phiên đang chờ người dùng quét QR sẽ hiện y hệt
/// một kênh đã chết, và nút bấm đúng cho hai tình huống đó không giống nhau.
enum ChannelStatus {
  connected,
  error,
  disconnected,
  pending;

  /// Giá trị lạ đọc thành [disconnected]. API là Mongo schema-less và trạng
  /// thái mới có thể xuất hiện trước khi app biết tới — một chuỗi không nhận ra
  /// phải làm màn hình hiện "chưa kết nối", không phải làm nó nổ.
  static ChannelStatus parse(String? raw) =>
      switch (raw?.trim().toLowerCase()) {
        'connected' => ChannelStatus.connected,
        'error' => ChannelStatus.error,
        'pending' => ChannelStatus.pending,
        _ => ChannelStatus.disconnected,
      };
}

/// Một tài khoản đã nối vào hộp thư.
class ChannelConnection {
  const ChannelConnection({
    required this.id,
    required this.channel,
    required this.name,
    required this.status,
    required this.today,
    this.ownerName,
    this.displayLabel,
    this.externalAccountId,
  });

  factory ChannelConnection.fromJson(Map<String, dynamic> json) {
    return ChannelConnection(
      id: json.strOr('id', ''),
      channel: Channel.parse(json.str('channel_id')),
      name: json.strOr('name', ''),
      status: ChannelStatus.parse(json.str('status')),
      today: json.intOr('today'),
      ownerName: json.str('owner_name'),
      displayLabel: json.str('display_label'),
      externalAccountId: json.str('external_account_id'),
    );
  }

  final String id;
  final Channel channel;
  final String name;
  final ChannelStatus status;
  final int today;

  /// Tên nhân viên sở hữu tài khoản cá nhân này.
  final String? ownerName;

  /// Nhãn server dựng sẵn ("Zalo cá nhân · Kiệt").
  final String? displayLabel;

  final String? externalAccountId;

  /// Nhãn để hiển thị. Ưu tiên nhãn server dựng — nó đã gắn tên chủ tài khoản,
  /// thứ duy nhất phân biệt được hai tài khoản Zalo cá nhân trong cùng workspace.
  String get label {
    final fromServer = displayLabel;
    if (fromServer != null && fromServer.isNotEmpty) return fromServer;
    if (name.isNotEmpty) return name;
    return channel.meta.name;
  }

  bool get isPersonal => channel.meta.kind == ChannelKind.personal;
}
