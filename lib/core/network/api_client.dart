import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../error/app_exception.dart';
import 'api_envelope.dart';
import 'active_tenant.dart';
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
  }) => _send(
    () => _dio.get<Map<String, dynamic>>(
      _url(path),
      queryParameters: _clean(query),
      cancelToken: cancelToken,
    ),
  );

  Future<ApiEnvelope> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) => _send(
    () => _dio.post<Map<String, dynamic>>(
      _url(path),
      data: body,
      queryParameters: _clean(query),
      cancelToken: cancelToken,
    ),
  );

  Future<ApiEnvelope> put(String path, {Object? body}) =>
      _send(() => _dio.put<Map<String, dynamic>>(_url(path), data: body));

  Future<ApiEnvelope> patch(String path, {Object? body}) =>
      _send(() => _dio.patch<Map<String, dynamic>>(_url(path), data: body));

  Future<ApiEnvelope> delete(String path, {Object? body}) =>
      _send(() => _dio.delete<Map<String, dynamic>>(_url(path), data: body));

  Future<ApiEnvelope> upload(
    String path, {
    required String field,
    required String filePath,
    String? filename,
    Map<String, dynamic> fields = const {},
  }) async {
    final FormData form;
    try {
      form = FormData.fromMap({
        ...fields,
        field: await MultipartFile.fromFile(filePath, filename: filename),
      });
    } on Object catch (_) {
      // Reading the file is I/O outside Dio, so it throws a raw
      // FileSystemException rather than a DioException — and callers only catch
      // AppException. That escaped every handler above: the outgoing bubble sat
      // on "đang gửi" forever, with no error and no retry. Android reclaiming a
      // picked image from its cache before the upload starts makes this a
      // routine occurrence, not an edge case.
      throw const NetworkException(
        'Không đọc được tệp đã chọn. Vui lòng chọn lại.',
        code: 'file_unreadable',
      );
    }

    return _send(() => _dio.post<Map<String, dynamic>>(_url(path), data: form));
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

  String _url(String path) => path.startsWith('/')
      ? '${AppConfig.apiPrefix}$path'
      : '${AppConfig.apiPrefix}/$path';

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

/// Dựng lại MỖI KHI đổi không gian làm việc (hay đăng xuất: tenant về null).
///
/// Mọi provider API của module theo dõi provider này, và mọi provider dữ liệu
/// theo dõi provider API của nó — nên đổi tenant đánh dấu bẩn cả chuỗi, và lần
/// đọc sau tải lại từ server. Không có dòng này thì provider giữ cache cả phiên
/// (danh sách nhân viên, kênh, tổng quan cơ hội…) vẫn trả dữ liệu của không
/// gian CŨ sau khi đổi sang không gian mới — một lỗi rò dữ liệu giữa hai công
/// ty, không phải chỉ là số liệu cũ.
final apiClientProvider = Provider<ApiClient>((ref) {
  ref.watch(activeTenantIdProvider);
  return ApiClient(ref.watch(dioProvider));
});
