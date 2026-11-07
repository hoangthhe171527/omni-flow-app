import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// Đổi mật khẩu của CHÍNH người đang đăng nhập (`PUT /auth/password`).
///
/// [current] bắt buộc khi tài khoản đã có mật khẩu; tài khoản chỉ vào bằng
/// Google (chưa từng đặt mật khẩu) để trống — server quyết, không phải app.
class PasswordApi {
  PasswordApi(this._client);

  final ApiClient _client;

  Future<void> change({required String current, required String next}) =>
      _client.put(
        '/auth/password',
        body: {
          if (current.isNotEmpty) 'current_password': current,
          'password': next,
        },
      );
}

final passwordApiProvider = Provider<PasswordApi>(
  (ref) => PasswordApi(ref.watch(apiClientProvider)),
);
