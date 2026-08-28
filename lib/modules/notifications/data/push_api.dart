import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// Registers this app installation with the API; the FCM token is not trusted
/// until it is bound to the authenticated user and active tenant server-side.
class PushApi {
  PushApi(this._client);

  final ApiClient _client;

  Future<void> register(String token, String platform, {String? deviceName}) {
    final normalizedDeviceName = deviceName?.trim();
    return _client.post(
      '/devices/push-tokens',
      body: {
        'token': token,
        'platform': platform,
        if (normalizedDeviceName != null && normalizedDeviceName.isNotEmpty)
          'device_name': normalizedDeviceName,
      },
    );
  }

  Future<void> unregister(String token) =>
      _client.delete('/devices/push-tokens', body: {'token': token});
}

final pushApiProvider = Provider<PushApi>(
  (ref) => PushApi(ref.watch(apiClientProvider)),
);
