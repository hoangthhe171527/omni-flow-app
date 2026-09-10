import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/json.dart';

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

  /// Người dùng có muốn RUNG máy khi ai đó tick xong một công đoạn không.
  ///
  /// Mặc định BẬT khi server chưa từng lưu gì: một người chưa mở màn Cài đặt
  /// phải nhận được thông báo. Mặc định tắt là một tính năng chỉ tồn tại với
  /// những ai tình cờ đi tìm nó.
  Future<bool> taskProgressPush() async {
    final response = await _client.get('/auth/me');
    final prefs = response.object.child('user')['notification_prefs'];

    // `!= false` chứ không `== true`: khoá chưa từng được lưu, hoặc server cũ
    // không gửi cụm này, đều phải hiểu là BẬT.
    return prefs is! Map || prefs['task_progress_push'] != false;
  }

  /// Đường TỰ PHỤC VỤ — cạnh `/auth/locale`, cố ý không đi qua
  /// `/identity/users/{id}` vì đường đó cần quyền `membership.members.update`
  /// mà vai `worker` không có. Người thợ phải tắt được thông báo của chính
  /// mình mà không phải nhờ quản đốc.
  Future<void> setTaskProgressPush(bool enabled) => _client.put(
    '/auth/notification-prefs',
    body: {'task_progress_push': enabled},
  );
}

final pushApiProvider = Provider<PushApi>(
  (ref) => PushApi(ref.watch(apiClientProvider)),
);
