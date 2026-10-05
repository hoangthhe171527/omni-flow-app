import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/active_tenant.dart';
import 'package:omni_app/core/network/dio_provider.dart';
import 'package:omni_app/core/network/feature_disabled.dart';
import 'package:omni_app/core/storage/token_store.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

/// Đợt 7 P5 (MS-I33): gặp 403 `FEATURE_DISABLED` thì đọc lại cờ từ
/// `/auth/context` để menu ẩn module vừa bị tắt — gộp các lượt đang chạy và
/// nghỉ 30 giây giữa hai lượt (màn poll 5 giây cứ nhận 403 thì không được
/// biến thành một cơn bão `/auth/context`).
void main() {
  group('FeatureFlagRefresher', () {
    test('gộp lượt đang chạy; nghỉ 30 giây giữa hai lượt', () async {
      var now = DateTime.utc(2026, 10, 5, 8);
      var calls = 0;
      final gate = Completer<void>();
      final refresher = FeatureFlagRefresher(() {
        calls++;
        return gate.future;
      }, now: () => now);

      final a = refresher.request();
      final b = refresher.request();
      gate.complete();
      await Future.wait([a, b]);
      expect(calls, 1);

      now = now.add(const Duration(seconds: 10));
      await refresher.request();
      expect(calls, 1, reason: 'Trong 30 giây thì không gọi lại.');

      now = now.add(const Duration(seconds: 21));
      await refresher.request();
      expect(calls, 2);
    });

    test('lỗi khi đọc lại cờ không lọt ra ngoài', () async {
      final refresher = FeatureFlagRefresher(
        () async => throw StateError('mất mạng'),
      );

      await expectLater(refresher.request(), completes);
    });
  });

  group('interceptor', () {
    late _Adapter adapter;
    late _CountingSession sessions;
    late Dio dio;

    setUp(() {
      adapter = _Adapter();
      sessions = _CountingSession();
      final container = ProviderContainer(
        overrides: [
          tokenStoreProvider.overrideWithValue(_MemoryTokenStore()),
          sessionControllerProvider.overrideWith(() => sessions),
        ],
      );
      addTearDown(container.dispose);
      container.read(activeTenantIdProvider.notifier).state = 't1';
      dio = container.read(dioProvider)..httpClientAdapter = adapter;
    });

    Future<int?> statusOf(String path) async {
      try {
        await dio.get<Object>(path);
        return 200;
      } on DioException catch (error) {
        return error.response?.statusCode;
      }
    }

    test('hai request cùng nhận FEATURE_DISABLED → refreshContext đúng 1 lần, '
        'lượt thứ ba trong 30 giây không gọi', () async {
      final statuses = await Future.wait([
        statusOf('/api/v1/inbox/conversations'),
        statusOf('/api/v1/inbox/changes'),
      ]);
      await pumpEventQueue();

      // Lỗi vẫn đi tiếp tới màn (màn hiện câu của API).
      expect(statuses, [403, 403]);
      expect(sessions.refreshes, 1);

      await statusOf('/api/v1/inbox/conversations');
      await pumpEventQueue();
      expect(sessions.refreshes, 1);
    });

    test('403 thiếu quyền thường thì không đọc lại cờ', () async {
      expect(await statusOf('/api/v1/forbidden'), 403);
      await pumpEventQueue();

      expect(sessions.refreshes, 0);
    });
  });
}

class _CountingSession extends SessionController {
  int refreshes = 0;

  @override
  Session build() => const Session(status: SessionStatus.authenticated);

  @override
  Future<void> refreshContext() async => refreshes++;
}

class _MemoryTokenStore extends TokenStore {
  _MemoryTokenStore() : super(const FlutterSecureStorage());

  @override
  Future<String?> readAccessToken() async => 'tok';

  @override
  Future<String?> readRefreshToken() async => 'r1';

  @override
  Future<void> save({
    required String accessToken,
    String? refreshToken,
  }) async {}

  @override
  Future<void> clear() async {}
}

class _Adapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    const json = {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    };
    if (options.path.contains('/forbidden')) {
      return ResponseBody.fromString(
        '{"success":false,"message":"Bạn không có quyền.",'
        '"required_permissions":["inbox.read"]}',
        403,
        headers: json,
      );
    }
    return ResponseBody.fromString(
      '{"success":false,"message":"Tính năng này đang tắt ở workspace của '
      'bạn.","code":"FEATURE_DISABLED","error_code":"FEATURE_DISABLED",'
      '"feature":"inbox"}',
      403,
      headers: json,
    );
  }

  @override
  void close({bool force = false}) {}
}
