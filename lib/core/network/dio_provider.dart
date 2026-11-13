import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../storage/preferences_store.dart';
import '../storage/storage_keys.dart';
import '../storage/token_store.dart';
import 'active_tenant.dart';
import 'api_exception_mapper.dart' show parseRetryAfter;
import 'feature_disabled.dart';

/// Chờ trước lượt refresh thứ hai sau 429. Test override bằng hàm trả ngay.
final refreshBackoffProvider = Provider<Future<void> Function(Duration)>(
  (ref) => Future<void>.delayed,
);

final _jitter = Random();

/// Thay lớp mạng của Dio. null = mạng thật. Bản demo (`lib/demo/`) gắn một
/// máy chủ trong bộ nhớ vào đây từ `bootstrap.dart`; `core` không biết gì về nó.
final httpClientAdapterProvider = Provider<HttpClientAdapter?>((ref) => null);

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );
  final adapter = ref.watch(httpClientAdapterProvider);
  if (adapter != null) dio.httpClientAdapter = adapter;

  // Concurrent 401s share one refresh. Otherwise an inbox screen can rotate
  // the same refresh token multiple times and invalidate its own session.
  Future<void>? refreshInFlight;
  int? refreshInFlightGeneration;

  Future<void> refreshAccessToken() {
    final tokenStore = ref.read(tokenStoreProvider);
    // Thế hệ phiên lúc mở lượt refresh: đăng xuất chen vào lúc chờ 429 thì
    // kết quả của lượt này thuộc về phiên đã kết thúc, không được lưu — và
    // người đăng nhập sau không được nhập chung vào lượt ấy.
    final generation = tokenStore.generation;
    final active = refreshInFlight;
    if (active != null && refreshInFlightGeneration == generation) {
      return active;
    }

    final refresh = () async {
      final refreshToken = await tokenStore.readRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        throw DioException(
          requestOptions: RequestOptions(path: '/auth/refresh'),
          response: Response(
            requestOptions: RequestOptions(path: '/auth/refresh'),
            statusCode: 401,
          ),
          type: DioExceptionType.badResponse,
        );
      }

      Future<Response<Map<String, dynamic>>> post() =>
          dio.post<Map<String, dynamic>>(
            '${AppConfig.apiPrefix}/auth/refresh',
            data: {'refresh_token': refreshToken},
            options: Options(extra: const {'skipSessionRefresh': true}),
          );

      Response<Map<String, dynamic>> response;
      try {
        response = await post();
      } on DioException catch (error) {
        // 429 ở refresh là "chậm lại", không phải phiên hỏng (APP-I7): chờ
        // theo `Retry-After` (mặc định 5 giây, trần 30 giây, cộng 0–2 giây
        // ngẫu nhiên để các máy không cùng quay lại một lúc) rồi thử lại MỘT
        // lần. Lần hai lỗi thì ném như cũ.
        if (error.response?.statusCode != 429) rethrow;
        final hinted =
            parseRetryAfter(error.response?.headers.value('retry-after')) ??
            const Duration(seconds: 5);
        final capped = hinted > const Duration(seconds: 30)
            ? const Duration(seconds: 30)
            : hinted;
        final jitter = Duration(milliseconds: _jitter.nextInt(2001));
        await ref.read(refreshBackoffProvider)(capped + jitter);
        response = await post();
      }
      final payload = response.data?['data'];
      if (payload is! Map || payload['access_token'] is! String) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          error: 'Refresh response is missing an access token.',
        );
      }
      final saved = await tokenStore.saveIfCurrent(
        generation,
        accessToken: payload['access_token'] as String,
        refreshToken: payload['refresh_token'] as String?,
      );
      if (!saved) {
        // Không phải 401: phiên đã kết thúc ở máy rồi, và một 401 ở đây sẽ
        // làm hết hạn phiên của người đăng nhập SAU (nếu đã có).
        throw DioException(
          requestOptions: response.requestOptions,
          type: DioExceptionType.cancel,
          error: 'Phiên đã kết thúc trong lúc làm mới.',
        );
      }
    }();

    refreshInFlight = refresh;
    refreshInFlightGeneration = generation;
    return refresh.whenComplete(() {
      if (identical(refreshInFlight, refresh)) refreshInFlight = null;
    });
  }

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await ref.read(tokenStoreProvider).readAccessToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }

        final tenantId =
            ref.read(activeTenantIdProvider) ??
            ref.read(preferencesStoreProvider).getString(StorageKeys.tenantId);
        final hasTenant = tenantId != null && tenantId.isNotEmpty;
        if (hasTenant) {
          options.headers['X-Tenant-Id'] = tenantId;
        }

        // Tenant-isolation safety net. The API scopes business data by the
        // tenant header; a business request sent without one would come back
        // unscoped. Auth endpoints run before a tenant exists, so they're exempt.
        final isAuthEndpoint = options.path.contains('/auth/');
        if (token != null &&
            token.isNotEmpty &&
            !hasTenant &&
            !isAuthEndpoint) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.cancel,
              error: 'Chưa chọn không gian làm việc.',
            ),
          );
          return;
        }

        handler.next(options);
      },
      onError: (error, handler) async {
        // A business request with an expired access token is recoverable:
        // rotate its refresh token and replay the original request once.
        final status = error.response?.statusCode;
        final isAuthEndpoint = error.requestOptions.path.contains('/auth/');
        final hasRetried = error.requestOptions.extra['sessionRetried'] == true;
        final skipRefresh =
            error.requestOptions.extra['skipSessionRefresh'] == true;
        if (status == 401 && !isAuthEndpoint && !hasRetried && !skipRefresh) {
          final tokenStore = ref.read(tokenStoreProvider);
          final generation = tokenStore.generation;
          try {
            await refreshAccessToken();
            final data = error.requestOptions.data;
            if (data is FormData) {
              final factory = error.requestOptions.extra['formDataFactory'];
              if (factory is Future<FormData> Function()) {
                error.requestOptions.data = await factory();
              } else if (data.isFinalized) {
                handler.next(error);
                return;
              }
            }
            error.requestOptions.extra['sessionRetried'] = true;
            final response = await dio.fetch<Map<String, dynamic>>(
              error.requestOptions,
            );
            handler.resolve(response);
            return;
          } on DioException catch (refreshError) {
            // Refresh của phiên CŨ bị từ chối sau khi đã đăng xuất (và có thể
            // người khác đã đăng nhập): không được làm hết hạn phiên mới.
            if (refreshError.response?.statusCode == 401 &&
                tokenStore.generation == generation) {
              final signal = ref.read(unauthorizedSignalProvider.notifier);
              signal.state = signal.state + 1;
            } else {
              // Preserve the refresh failure (offline/timeout/5xx). Returning
              // the original access-token 401 would falsely expire a valid
              // rolling session while the server is temporarily unavailable.
              handler.next(refreshError);
              return;
            }
            // A rejected refresh token is authoritative; forward the original
            // business 401 so session state can expire it.
          }
        }
        // Module vừa bị tắt ở workspace (MS-I33): đọc lại cờ để menu ẩn nó.
        // Không chặn lỗi — màn vẫn hiện câu của API qua trạng thái lỗi sẵn có.
        if (isFeatureDisabledResponse(error.response)) {
          unawaited(ref.read(featureFlagRefresherProvider).request());
        }
        handler.next(error);
      },
    ),
  );

  return dio;
});
