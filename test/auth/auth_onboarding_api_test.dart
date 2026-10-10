import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/modules/auth/data/auth_onboarding_api.dart';

void main() {
  test('đăng ký gửi body snake_case tới /auth/register', () async {
    final adapter = _Adapter(
      201,
      '{"success":true,"data":{"access_token":"a","tenant_id":"t"}}',
    );
    final api = AuthOnboardingApi(
      ApiClient(Dio()..httpClientAdapter = adapter),
    );

    await api.register(
      fullName: 'Lan Anh',
      email: 'lan@acme.vn',
      companyName: 'Acme',
      password: 'Abcdef1!',
    );

    expect(adapter.request.method, 'POST');
    expect(adapter.request.uri.path, '/api/v1/auth/register');
    expect(adapter.request.data, {
      'full_name': 'Lan Anh',
      'email': 'lan@acme.vn',
      'company_name': 'Acme',
      'password': 'Abcdef1!',
    });
  });

  test('422 theo trường ném ValidationException có firstFor(email)', () async {
    final adapter = _Adapter(
      422,
      '{"success":false,"message":"Dữ liệu chưa hợp lệ.",'
      '"errors":{"email":["Email đã được dùng."]}}',
    );
    final api = AuthOnboardingApi(
      ApiClient(Dio()..httpClientAdapter = adapter),
    );

    await expectLater(
      api.register(
        fullName: 'A',
        email: 'a@b.vn',
        companyName: 'C',
        password: 'x',
      ),
      throwsA(
        isA<ValidationException>().having(
          (e) => e.firstFor('email'),
          'email',
          'Email đã được dùng.',
        ),
      ),
    );
  });

  test('quên mật khẩu gửi {email} và chấp nhận 204 không thân', () async {
    final adapter = _Adapter(204, '');
    final api = AuthOnboardingApi(
      ApiClient(Dio()..httpClientAdapter = adapter),
    );

    await api.forgotPassword('lan@acme.vn');

    expect(adapter.request.uri.path, '/api/v1/auth/forgot-password');
    expect(adapter.request.data, {'email': 'lan@acme.vn'});
  });
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, this.body);

  final int status;
  final String body;
  late RequestOptions request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
