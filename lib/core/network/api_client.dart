import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import 'api_envelope.dart';
import 'api_exception_mapper.dart';
import 'dio_provider.dart';

/// The single seam between the app and the HTTP API.
///
/// Paths passed in are relative to `/api/v1` (`'/inbox/conversations'`), so no
/// caller ever repeats the version prefix.
class ApiClient {
  ApiClient(this._dio);

  final Dio _dio;

  Future<ApiEnvelope> get(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) =>
      _send(() => _dio.get<Map<String, dynamic>>(
            _url(path),
            queryParameters: _clean(query),
            cancelToken: cancelToken,
          ));

  Future<ApiEnvelope> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) =>
      _send(() => _dio.post<Map<String, dynamic>>(
            _url(path),
            data: body,
            queryParameters: _clean(query),
            cancelToken: cancelToken,
          ));

  Future<ApiEnvelope> put(String path, {Object? body}) => _send(
        () => _dio.put<Map<String, dynamic>>(_url(path), data: body),
      );

  Future<ApiEnvelope> patch(String path, {Object? body}) => _send(
        () => _dio.patch<Map<String, dynamic>>(_url(path), data: body),
      );

  Future<ApiEnvelope> delete(String path, {Object? body}) => _send(
        () => _dio.delete<Map<String, dynamic>>(_url(path), data: body),
      );

  Future<ApiEnvelope> upload(
    String path, {
    required String field,
    required String filePath,
    String? filename,
    Map<String, dynamic> fields = const {},
  }) async {
    final form = FormData.fromMap({
      ...fields,
      field: await MultipartFile.fromFile(filePath, filename: filename),
    });
    return _send(
      () => _dio.post<Map<String, dynamic>>(_url(path), data: form),
    );
  }

  Future<ApiEnvelope> _send(
    Future<Response<Map<String, dynamic>>> Function() request,
  ) async {
    try {
      final response = await request();
      return ApiEnvelope(response.data ?? const {});
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  String _url(String path) =>
      path.startsWith('/') ? '${AppConfig.apiPrefix}$path' : '${AppConfig.apiPrefix}/$path';

  /// Dio serialises nulls as the literal string "null"; drop them instead so an
  /// unset filter simply isn't sent.
  Map<String, dynamic>? _clean(Map<String, dynamic>? query) {
    if (query == null) return null;
    final cleaned = <String, dynamic>{};
    query.forEach((key, value) {
      if (value == null) return;
      if (value is String && value.isEmpty) return;
      cleaned[key] = value;
    });
    return cleaned.isEmpty ? null : cleaned;
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(dioProvider));
});
