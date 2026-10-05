import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/modules/auth/data/auth_api.dart';
import 'package:omni_app/security/session/session.dart';

/// Đợt 7 P5 (MS-I33): `/auth/context` trả `features: {khoá: bool}` từ 6b B3.
/// Khoá THIẾU nghĩa là bật — API cũ không có khoá này thì mọi module vẫn hiện.
void main() {
  test('loadContext đọc features; khoá thiếu là bật', () async {
    final api = AuthApi(
      ApiClient(
        Dio()
          ..httpClientAdapter = _RoutedAdapter({
            '/auth/me':
                '{"success":true,"data":{"user":{"id":"u1",'
                '"full_name":"Lan","email":"l@x"}}}',
            '/auth/context':
                '{"success":true,"data":{"tenant":{"id":"t1",'
                '"name":"Xưởng"},"membership":{"id":"m1"},"roles":[],'
                '"permissions":["inbox.read"],'
                '"features":{"inbox":false,"tasks":true,"orders":"x"}}}',
          }),
      ),
    );

    final session = await api.loadContext();

    expect(session.featureEnabled('inbox'), isFalse);
    expect(session.featureEnabled('tasks'), isTrue);
    expect(session.featureEnabled('customers'), isTrue);
    expect(session.featureEnabled(null), isTrue);
    // Giá trị không phải bool thì bỏ qua (coi như thiếu → bật).
    expect(session.featureEnabled('orders'), isTrue);
  });

  test('API cũ không có features → mọi khoá bật', () async {
    final api = AuthApi(
      ApiClient(
        Dio()
          ..httpClientAdapter = _RoutedAdapter({
            '/auth/me':
                '{"success":true,"data":{"user":{"id":"u1",'
                '"full_name":"Lan","email":"l@x"}}}',
            '/auth/context':
                '{"success":true,"data":{"tenant":{"id":"t1",'
                '"name":"Xưởng"},"permissions":[]}}',
          }),
      ),
    );

    final session = await api.loadContext();

    expect(session.features, isEmpty);
    expect(session.featureEnabled('inbox'), isTrue);
  });

  test('copyWith giữ features', () {
    const session = Session(
      status: SessionStatus.authenticated,
      features: {'inbox': false},
    );

    expect(session.copyWith().featureEnabled('inbox'), isFalse);
    expect(
      session.copyWith(features: const {}).featureEnabled('inbox'),
      isTrue,
    );
  });
}

class _RoutedAdapter implements HttpClientAdapter {
  _RoutedAdapter(this.routes);

  final Map<String, String> routes;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final key = routes.keys.firstWhere(
      (path) => options.uri.path.endsWith(path),
      orElse: () => throw StateError('Không có route ${options.uri.path}'),
    );
    return ResponseBody.fromString(
      routes[key]!,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
