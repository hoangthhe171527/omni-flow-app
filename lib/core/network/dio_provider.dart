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

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await ref.read(tokenStoreProvider).readAccessToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }

        final tenantId = ref.read(activeTenantIdProvider) ??
            ref.read(preferencesStoreProvider).getString(StorageKeys.tenantId);
        final hasTenant = tenantId != null && tenantId.isNotEmpty;
        if (hasTenant) {
          options.headers['X-Tenant-Id'] = tenantId;
        }

        // Tenant-isolation safety net. The API scopes business data by the
        // tenant header; a business request sent without one would come back
        // unscoped. Auth endpoints run before a tenant exists, so they're exempt.
        final isAuthEndpoint = options.path.contains('/auth/');
        if (token != null && token.isNotEmpty && !hasTenant && !isAuthEndpoint) {
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
      onError: (error, handler) {
        // A 401 outside the auth endpoints means the token died mid-session.
        // Signal it; the session controller ends the session and the router
        // sends the user to login. A 401 ON an auth endpoint is a failed login
        // and is handled inline by the caller.
        final status = error.response?.statusCode;
        final isAuthEndpoint = error.requestOptions.path.contains('/auth/');
        if (status == 401 && !isAuthEndpoint) {
          final signal = ref.read(unauthorizedSignalProvider.notifier);
          signal.state = signal.state + 1;
        }
        handler.next(error);
      },
    ),
  );

  return dio;
});
