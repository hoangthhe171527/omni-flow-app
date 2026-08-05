import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../storage/preferences_store.dart';
import '../storage/storage_keys.dart';
import '../storage/token_store.dart';
import 'active_tenant.dart';

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

  // Concurrent 401s share one refresh. Otherwise an inbox screen can rotate
  // the same refresh token multiple times and invalidate its own session.
  Future<void>? refreshInFlight;

  Future<void> refreshAccessToken() {
    final active = refreshInFlight;
    if (active != null) return active;

    final refresh = () async {
      final tokenStore = ref.read(tokenStoreProvider);
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

      final response = await dio.post<Map<String, dynamic>>(
        '${AppConfig.apiPrefix}/auth/refresh',
        data: {'refresh_token': refreshToken},
        options: Options(extra: const {'skipSessionRefresh': true}),
      );
      final payload = response.data?['data'];
      if (payload is! Map || payload['access_token'] is! String) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          error: 'Refresh response is missing an access token.',
        );
      }
      await tokenStore.save(
        accessToken: payload['access_token'] as String,
        refreshToken: payload['refresh_token'] as String?,
      );
    }();

    refreshInFlight = refresh;
    return refresh.whenComplete(() => refreshInFlight = null);
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
          try {
            await refreshAccessToken();
            error.requestOptions.extra['sessionRetried'] = true;
            final response = await dio.fetch<Map<String, dynamic>>(
              error.requestOptions,
            );
            handler.resolve(response);
            return;
          } on DioException catch (refreshError) {
            if (refreshError.response?.statusCode == 401) {
              final signal = ref.read(unauthorizedSignalProvider.notifier);
              signal.state = signal.state + 1;
            }
            // A network/server error while refreshing is transient: leave the
            // secure storage intact so a later request can recover.
          }
        }
        handler.next(error);
      },
    ),
  );

  return dio;
});
