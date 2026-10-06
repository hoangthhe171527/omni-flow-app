import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/active_tenant.dart';
import 'package:omni_app/core/network/dio_provider.dart';
import 'package:omni_app/core/storage/token_store.dart';

/// Đợt 7 P1 (APP-I7): `/auth/refresh` bị 429 (giới hạn tần suất) không phải là
/// phiên hỏng — chờ theo `Retry-After` rồi thử lại MỘT lần. Trước đây lỗi ngay,
/// và request nghiệp vụ đang chờ token mới thất bại theo.
void main() {
  test(
    'refresh 429 → chờ Retry-After, thử lại một lần, request đi tiếp',
    () async {
      final adapter = _ScriptedAdapter();
      final waits = <Duration>[];
      final container = ProviderContainer(
        overrides: [
          tokenStoreProvider.overrideWithValue(_MemoryTokenStore()),
          refreshBackoffProvider.overrideWithValue((d) async => waits.add(d)),
        ],
      );
      addTearDown(container.dispose);
      container.read(activeTenantIdProvider.notifier).state = 't1';

      final dio = container.read(dioProvider)..httpClientAdapter = adapter;

      final response = await dio.get<Map<String, dynamic>>('/api/v1/tasks');

      expect(response.statusCode, 200);
      expect(adapter.refreshCalls, 2);
      expect(waits, hasLength(1));
      expect(waits.single, greaterThanOrEqualTo(const Duration(seconds: 1)));
      expect(waits.single, lessThanOrEqualTo(const Duration(seconds: 3)));
    },
  );

  test('refresh 429 hai lần → ném lỗi 429, không thử lần ba', () async {
    final adapter = _ScriptedAdapter()..refreshAlways429 = true;
    final container = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(_MemoryTokenStore()),
        refreshBackoffProvider.overrideWithValue((_) async {}),
      ],
    );
    addTearDown(container.dispose);
    container.read(activeTenantIdProvider.notifier).state = 't1';

    final dio = container.read(dioProvider)..httpClientAdapter = adapter;

    await expectLater(
      dio.get<Map<String, dynamic>>('/api/v1/tasks'),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'status',
          429,
        ),
      ),
    );
    expect(adapter.refreshCalls, 2);
  });
}

class _MemoryTokenStore extends TokenStore {
  _MemoryTokenStore() : super(const FlutterSecureStorage());

  String? access = 'old';
  String? refresh = 'r1';

  @override
  Future<String?> readAccessToken() async => access;

  @override
  Future<String?> readRefreshToken() async => refresh;

  @override
  Future<void> save({required String accessToken, String? refreshToken}) async {
    access = accessToken;
    if (refreshToken != null) refresh = refreshToken;
  }

  @override
  Future<void> clear() async {
    access = null;
    refresh = null;
  }
}

class _ScriptedAdapter implements HttpClientAdapter {
  int refreshCalls = 0;
  bool refreshAlways429 = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    const json = {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    };
    if (options.path.endsWith('/auth/refresh')) {
      refreshCalls++;
      if (refreshAlways429 || refreshCalls == 1) {
        return ResponseBody.fromString(
          '{"message":"Too Many Attempts."}',
          429,
          headers: {
            ...json,
            'retry-after': ['1'],
          },
        );
      }
      return ResponseBody.fromString(
        '{"success":true,"data":{"access_token":"new","refresh_token":"r2"}}',
        200,
        headers: json,
      );
    }
    final auth = options.headers['Authorization'];
    if (auth != 'Bearer new') {
      return ResponseBody.fromString(
        '{"success":false,"message":"Unauthenticated."}',
        401,
        headers: json,
      );
    }
    return ResponseBody.fromString(
      '{"success":true,"data":[]}',
      200,
      headers: json,
    );
  }

  @override
  void close({bool force = false}) {}
}
