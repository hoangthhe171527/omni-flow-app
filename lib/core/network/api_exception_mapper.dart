import 'package:dio/dio.dart';

import '../error/app_exception.dart';

/// Turns a [DioException] into the app's own failure type. The API always
/// answers errors as `{ success:false, message, error_code?, required_permissions? }`.
AppException mapDioException(DioException error) {
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return const TimeoutException('Kết nối quá hạn. Vui lòng thử lại.');
    case DioExceptionType.cancel:
      return RequestBlockedException(
        error.error?.toString() ?? 'Yêu cầu đã bị huỷ.',
      );
    case DioExceptionType.connectionError:
      return const NetworkException('Không có kết nối mạng.');
    default:
      break;
  }

  final status = error.response?.statusCode;
  final body = error.response?.data;
  final map = body is Map ? body.cast<String, dynamic>() : const <String, dynamic>{};
  final message = (map['message'] as String?)?.trim();

  return switch (status) {
    401 => UnauthorizedException(message ?? 'Phiên đăng nhập đã hết hạn.'),
    403 => ForbiddenException(
        message ?? 'Bạn không có quyền thực hiện thao tác này.',
        requiredPermissions: _stringList(map['required_permissions']),
      ),
    404 => NotFoundException(message ?? 'Không tìm thấy dữ liệu.'),
    422 => ValidationException(
        message ?? 'Dữ liệu chưa hợp lệ.',
        errors: _fieldErrors(map['errors']),
      ),
    _ when status != null && status >= 500 =>
      ServerException(message ?? 'Máy chủ đang gặp sự cố.', code: '$status'),
    _ => NetworkException(
        message ?? error.message ?? 'Đã có lỗi xảy ra.',
        code: status?.toString(),
      ),
  };
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value.map((e) => '$e').toList();
}

Map<String, List<String>> _fieldErrors(Object? value) {
  if (value is! Map) return const {};
  return value.map(
    (key, messages) => MapEntry(
      '$key',
      messages is List ? messages.map((m) => '$m').toList() : <String>['$messages'],
    ),
  );
}
