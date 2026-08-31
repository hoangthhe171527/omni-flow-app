import 'package:flutter/foundation.dart';

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
  // Personal-channel pairing relies on an external agent. It is unavailable in
  // the App Store build; iOS exposes only official OAuth/API integrations.
  // Android keeps Zalo pairing for existing enterprise deployments.
  static List<Channel> get pair => pairFor(defaultTargetPlatform);

  static List<Channel> pairFor(TargetPlatform platform) =>
      platform == TargetPlatform.iOS ? const [] : const [Channel.zaloPersonal];

  // Facebook Personal previously copied the user's Facebook session cookies
  // to the backend so an agent could remain signed in. Keep it unavailable on
  // every platform until an official OAuth/API integration replaces it.
  static ConnectMethod methodFor(Channel channel, {TargetPlatform? platform}) {
    if (oauth.contains(channel)) return ConnectMethod.oauth;
    if (pairFor(platform ?? defaultTargetPlatform).contains(channel)) {
      return ConnectMethod.pair;
    }
    return ConnectMethod.none;
  }
}
