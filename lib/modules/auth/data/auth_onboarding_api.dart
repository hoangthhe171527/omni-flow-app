import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// Hai lời gọi của người CHƯA có phiên: đăng ký workspace và xin liên kết đặt
/// lại mật khẩu. Lỗi 422 đi qua [ApiClient] thành `ValidationException` có
/// `errors` theo trường — cùng đường với đăng nhập.
class AuthOnboardingApi {
  AuthOnboardingApi(this._client);

  final ApiClient _client;

  /// `POST /auth/register` → 201 `{data:{access_token,…,tenant_id}}`. App không
  /// dùng token ấy: sau khi tạo xong nó đăng nhập bằng đúng email + mật khẩu
  /// qua đường đăng nhập thường, để phiên đi qua một cửa duy nhất.
  Future<void> register({
    required String fullName,
    required String email,
    required String companyName,
    required String password,
  }) async {
    await _client.post(
      '/auth/register',
      body: {
        'full_name': fullName,
        'email': email,
        'company_name': companyName,
        'password': password,
      },
    );
  }

  /// `POST /auth/forgot-password` → 204 dù email có tồn tại hay không.
  Future<void> forgotPassword(String email) async {
    await _client.post('/auth/forgot-password', body: {'email': email});
  }
}

final authOnboardingApiProvider = Provider<AuthOnboardingApi>((ref) {
  return AuthOnboardingApi(ref.watch(apiClientProvider));
});
