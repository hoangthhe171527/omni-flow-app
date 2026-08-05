import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/domain/channel.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/json.dart';
import '../domain/channel_connection.dart';
import '../domain/pairing.dart';

/// Chỗ duy nhất trong app viết đường dẫn `/channels/...`.
///
/// Đường dẫn tương đối với `/api/v1` — [ApiClient] tự thêm tiền tố, nên không
/// nơi nào lặp lại phiên bản API.
class ChannelsApi {
  ChannelsApi(this._client);

  final ApiClient _client;

  Future<List<ChannelConnection>> list() async {
    final response = await _client.get(
      '/channels',
      query: {'per_page': AppConfig.maxPerPage},
    );
    return response.list.map(ChannelConnection.fromJson).toList();
  }

  Future<void> disconnect(String id) => _client.delete('/channels/$id');

  /// URL trang đồng ý của nền tảng. Mở bằng trình duyệt ngoài — Facebook và
  /// Google chặn webview nhúng cho đăng nhập.
  Future<String> oauthUrl(Channel channel) async {
    final response = await _client.get('/channels/${channel.slug}/oauth/redirect');
    return response.object.strOr('authorization_url', '');
  }

  /// Mở một phiên ghép nối mới.
  ///
  /// [forceRelogin] bảo agent vứt phiên đăng nhập nó đang giữ cho kênh này và
  /// hiện QR mới. Không có cờ này thì lần ghép nối thứ hai chỉ nối lại đúng tài
  /// khoản cũ — đúng cho việc nối lại, sai khi người dùng muốn đổi tài khoản.
  Future<PairingStart> pairStart(
    Channel channel, {
    bool forceRelogin = false,
    required String deviceId,
  }) async {
    final response = await _client.post(
      '/channels/pair/start',
      body: {
        'channel_id': channel.slug,
        'force_relogin': forceRelogin,
        'device_id': deviceId,
      },
    );
    return PairingStart.fromJson(response.object);
  }

  Future<List<AgentDevice>> devices() async {
    final response = await _client.get('/agent/devices');
    return response.list.map(AgentDevice.fromJson).toList();
  }

  Future<PairingStatus> pairStatus(String connectionId) async {
    final response = await _client.get('/channels/pair/$connectionId/status');
    return PairingStatus.fromJson(response.object);
  }
}

final channelsApiProvider =
    Provider<ChannelsApi>((ref) => ChannelsApi(ref.watch(apiClientProvider)));

class AgentDevice {
  const AgentDevice({required this.id, required this.name, this.lastSeenAt});

  factory AgentDevice.fromJson(Map<String, dynamic> json) => AgentDevice(
        id: json.strOr('id', ''),
        name: json.strOr('name', 'Omni Agent'),
        lastSeenAt: json.str('last_seen_at'),
      );

  final String id;
  final String name;
  final String? lastSeenAt;
}
