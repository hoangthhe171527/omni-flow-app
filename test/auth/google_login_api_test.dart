import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/modules/auth/data/auth_api.dart';

void main() {
  test('Google ID token is sent to the mobile SSO endpoint', () async {
    final adapter = _RecordingAdapter();
    final api = AuthApi(ApiClient(Dio()..httpClientAdapter = adapter));

    final tokens = await api.loginWithGoogle('signed-google-id-token');

    expect(adapter.request.method, 'POST');
    expect(adapter.request.uri.path, '/api/v1/auth/sso/google');
    expect(adapter.request.data, {
      'credential': 'signed-google-id-token',
      'client_type': 'mobile',
    });
    expect(tokens.accessToken, 'access');
    expect(tokens.refreshToken, 'refresh');
    expect(tokens.expiresIn, 3600);
  });
}

class _RecordingAdapter implements HttpClientAdapter {
  late RequestOptions request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      '{"success":true,"data":{"access_token":"access",'
      '"refresh_token":"refresh","expires_in":3600}}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
