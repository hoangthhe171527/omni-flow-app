import 'dart:io' show HttpDate, HttpException;

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
    404 => NotFoundException(
      message ?? 'Không tìm thấy dữ liệu.',
      // Mọi 404 của API đi qua envelope `success:false`; route không tồn tại
      // thì Laravel trả `{message:"The route … could not be found."}`.
      routeMissing: !map.containsKey('success'),
    ),
    422 => ValidationException(
      message ?? 'Dữ liệu chưa hợp lệ.',
      errors: _fieldErrors(map['errors']),
      reason: _reason(map),
    ),
    429 => _rateLimited(message, error.response?.headers.value('retry-after')),
    _ when status != null && status >= 500 => ServerException(
      message ?? 'Máy chủ đang gặp sự cố.',
      code: '$status',
    ),
    // Không dùng `error.message` của Dio: đó là câu tiếng Anh cho lập trình
    // viên ("This exception was thrown because the response has a status
    // code of 409…") — APP-I7.
    null => const NetworkException('Không kết nối được máy chủ.'),
    _ => RequestRejectedException(
      message ?? 'Yêu cầu không thực hiện được (mã $status).',
      code: '$status',
      reason: _reason(map),
      data: map['data'],
    ),
  };
}

RateLimitedException _rateLimited(String? message, String? retryAfter) {
  final retry = parseRetryAfter(retryAfter);
  return RateLimitedException(
    message ?? _rateLimitText(retry),
    retryAfter: retry,
  );
}

/// `Retry-After`: số giây, hoặc ngày giờ HTTP. Hỏng/thiếu → null.
Duration? parseRetryAfter(String? value, {DateTime? now}) {
  if (value == null || value.trim().isEmpty) return null;
  final seconds = int.tryParse(value.trim());
  if (seconds != null) return Duration(seconds: seconds < 0 ? 0 : seconds);
  try {
    final at = HttpDate.parse(value.trim());
    final diff = at.difference(now ?? DateTime.now().toUtc());
    return diff.isNegative ? Duration.zero : diff;
  } on FormatException {
    return null;
  } on HttpException {
    return null;
  }
}

String _rateLimitText(Duration? retry) => retry == null || retry.inSeconds <= 0
    ? 'Bạn thao tác quá nhanh. Vui lòng thử lại sau ít phút.'
    : 'Bạn thao tác quá nhanh. Vui lòng thử lại sau ${retry.inSeconds} giây.';

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

/// Mã nghiệp vụ của lỗi: `code` (vd 422 `personal_thread_not_reassignable`),
/// hoặc `error_code` ở những endpoint dùng tên khoá cũ.
String? _reason(Map<String, dynamic> map) {
  for (final key in const ['code', 'error_code']) {
    final value = map[key];
    if (value is String && value.isNotEmpty) return value;
  }
  return null;
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
