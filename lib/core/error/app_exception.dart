/// Transport-agnostic failures. Nothing above [core/network] should ever see a
/// `DioException` — the client maps everything into one of these.
sealed class AppException implements Exception {
  const AppException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => '$runtimeType($code): $message';
}

class NetworkException extends AppException {
  const NetworkException(super.message, {super.code});
}

class TimeoutException extends AppException {
  const TimeoutException(super.message) : super(code: 'timeout');
}

class UnauthorizedException extends AppException {
  const UnauthorizedException(super.message) : super(code: '401');
}

/// The server refused on permissions. [requiredPermissions] is echoed by the
/// API so the UI can name what is missing instead of a blank "no access".
class ForbiddenException extends AppException {
  const ForbiddenException(super.message, {this.requiredPermissions = const []})
    : super(code: '403');

  final List<String> requiredPermissions;
}

class NotFoundException extends AppException {
  const NotFoundException(super.message, {this.routeMissing = false})
    : super(code: '404');

  /// 404 KHÔNG mang envelope `{success:false,…}` của API — tức là Laravel (hay
  /// proxy) không có route này, chứ không phải API đã từ chối/không thấy bản
  /// ghi. Chỗ gọi một route mới dùng nó để rơi về đường cũ với API chưa cập
  /// nhật mà không nuốt 404 thật của nghiệp vụ.
  final bool routeMissing;
}

/// 422 — field-level validation errors keyed by field name.
class ValidationException extends AppException {
  const ValidationException(super.message, {this.errors = const {}})
    : super(code: '422');

  final Map<String, List<String>> errors;

  String? firstFor(String field) => errors[field]?.firstOrNull;
}

class ServerException extends AppException {
  const ServerException(super.message, {super.code});
}

/// The request never left the device — e.g. it was blocked because no tenant is
/// selected yet. Distinct from [NetworkException] so it is never retried.
class RequestBlockedException extends AppException {
  const RequestBlockedException(super.message) : super(code: 'blocked');
}
