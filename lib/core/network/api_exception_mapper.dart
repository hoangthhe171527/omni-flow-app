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
  final map = body is Map
      ? body.cast<String, dynamic>()
      : const <String, dynamic>{};
  final message = _forHumans((map['message'] as String?)?.trim());

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
    _ when status != null && status >= 500 => ServerException(
      message ?? 'Máy chủ đang gặp sự cố.',
      code: '$status',
    ),
    _ => NetworkException(
      message ?? error.message ?? 'Đã có lỗi xảy ra.',
      code: status?.toString(),
    ),
  };
}

/// Những mẩu chỉ xuất hiện trong lời của KHUNG, không phải lời của sản phẩm.
///
/// Laravel trả về tiếng Anh cho lỗi hạ tầng, và app chuyển tiếp nguyên văn —
/// nên một người thợ ở xưởng từng nhìn thấy đúng dòng này trên màn hình:
///
///   "The route api/v1/tasks/01a079…/checklist/c2 could not be found."
///
/// Nó không nói được gì với người đọc, và còn phơi cả đường dẫn nội bộ.
const _internalMarkers = [
  'api/v1',
  'could not be found',
  'server error',
  'unauthenticated',
  'this action is unauthorized',
  'too many attempts',
  'sqlstate',
  'call to a member function',
  'undefined ',
  'exception',
];

/// Giữ lời của API khi nó nói với NGƯỜI, bỏ đi khi nó nói với lập trình viên.
///
/// Bỏ đi thì `mapDioException` rơi về câu tiếng Việt theo mã HTTP — chung
/// chung hơn, nhưng đọc được. Mã trạng thái vẫn nằm trong `code`, nên chỗ cần
/// phân biệt vẫn phân biệt được.
///
/// Danh sách cố ý NGẮN và cụ thể: mọi thông báo nghiệp vụ của API này đều
/// bằng tiếng Việt, nên chỉ cần bắt đúng những chuỗi khung sinh ra. Lọc theo
/// kiểu "không có dấu tiếng Việt thì bỏ" sẽ nuốt luôn những câu tiếng Anh hợp
/// lệ do tích hợp bên thứ ba trả về.
String? _forHumans(String? message) {
  if (message == null || message.isEmpty) return null;

  final lower = message.toLowerCase();
  for (final marker in _internalMarkers) {
    if (lower.contains(marker)) return null;
  }

  return message;
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
      messages is List
          ? messages.map((m) => '$m').toList()
          : <String>['$messages'],
    ),
  );
}
