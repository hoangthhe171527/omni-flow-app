import '../../../core/domain/channel.dart';

/// Nối kênh này bằng cách nào.
enum ConnectMethod {
  /// Chuyển sang trình duyệt để nền tảng hỏi đồng ý.
  oauth,

  /// Ghép nối với omni-agent bằng QR đăng nhập.
  pair,

  /// Không nối được từ app (website chat, kênh app chưa biết tới).
  none,
}

/// Kênh nào nối được từ app, và bằng cách nào.
///
/// Mọi thứ khác về một kênh — tên, nhãn ngắn, màu, icon, official hay personal
/// — lấy từ [ChannelMeta] trong core. File này chỉ trả lời đúng một câu hỏi core
/// không trả lời được: nối nó ra sao.
abstract final class ConnectableChannels {
  /// Cùng bộ với `connectOptions` bên web client.
  static const oauth = [Channel.facebook, Channel.zalo, Channel.tiktok];

  /// Cùng bộ với `PERSONAL_CHANNELS` trong `ChannelPairingController`.
  static const pair = [Channel.zaloPersonal, Channel.facebookPersonal];

  static ConnectMethod methodFor(Channel channel) {
    if (oauth.contains(channel)) return ConnectMethod.oauth;
    if (pair.contains(channel)) return ConnectMethod.pair;
    return ConnectMethod.none;
  }
}
