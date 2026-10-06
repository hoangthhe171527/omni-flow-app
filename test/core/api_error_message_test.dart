import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/core/network/api_exception_mapper.dart';

/// Lỗi hiện ra cho NGƯỜI đọc, không phải cho lập trình viên.
///
/// App chuyển tiếp nguyên văn `message` của API. Với thông báo nghiệp vụ thì
/// đúng — chúng đều bằng tiếng Việt. Nhưng Laravel trả tiếng Anh cho lỗi hạ
/// tầng, và một người thợ ở xưởng đã nhìn thấy đúng dòng này trên màn hình:
///
///   "The route api/v1/tasks/01a079…/checklist/c2 could not be found."
///
/// Nó không nói được gì với người đọc, và còn phơi cả đường dẫn nội bộ.
void main() {
  AppException mapOf(int status, Object? body) => mapDioException(
    DioException(
      requestOptions: RequestOptions(path: '/x'),
      response: Response(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: status,
        data: body,
      ),
      type: DioExceptionType.badResponse,
    ),
  );

  group('lời của khung bị bỏ', () {
    test('route không tồn tại → câu tiếng Việt, không phơi đường dẫn', () {
      final e = mapOf(404, {
        'message':
            'The route api/v1/tasks/01a079ca/checklist/c2 could not be found.',
      });

      expect(e.message, 'Không tìm thấy dữ liệu.');
      expect(e.message, isNot(contains('api/v1')));
    });

    test('những chuỗi Laravel khác cũng vậy', () {
      expect(
        mapOf(500, {'message': 'Server Error'}).message,
        isNot('Server Error'),
      );
      expect(
        mapOf(401, {'message': 'Unauthenticated.'}).message,
        'Phiên đăng nhập đã hết hạn.',
      );
      expect(
        mapOf(403, {'message': 'This action is unauthorized.'}).message,
        'Bạn không có quyền thực hiện thao tác này.',
      );
    });

    test('lỗi PHP rò ra ngoài không được hiện lên màn hình', () {
      final e = mapOf(500, {
        'message': 'SQLSTATE[HY000]: General error: 1 no such table',
      });

      expect(e.message, 'Máy chủ đang gặp sự cố.');
    });

    test('mã trạng thái vẫn giữ, nên chỗ cần phân biệt vẫn phân biệt được', () {
      final e = mapOf(404, {
        'message': 'The route api/v1/x could not be found.',
      });

      expect(e, isA<NotFoundException>());
      expect(e.code, '404');
    });
  });

  group('lời của sản phẩm được giữ nguyên', () {
    test('thông báo nghiệp vụ tiếng Việt', () {
      // Đây mới là thứ đáng hiện: nó nói ra việc cần làm.
      final e = mapOf(404, {
        'message': 'Không tìm thấy việc con này. Có thể ai đó vừa xoá nó.',
      });

      expect(
        e.message,
        'Không tìm thấy việc con này. Có thể ai đó vừa xoá nó.',
      );
    });

    test('cổng QC từ chối kèm tên nhóm việc còn thiếu', () {
      final e = mapOf(422, {
        'message': 'Còn 3 việc con chưa xong: Body ngoài, Đánh bóng, Lên dây.',
      });

      expect(e.message, contains('Body ngoài'));
    });

    test('câu tiếng Anh HỢP LỆ của tích hợp bên thứ ba vẫn giữ', () {
      // Lọc theo kiểu "không có dấu tiếng Việt thì bỏ" sẽ nuốt luôn câu này.
      final e = mapOf(422, {'message': 'Zalo session expired, scan QR again'});

      expect(e.message, 'Zalo session expired, scan QR again');
    });
  });

  // Đợt 7 P1 (APP-I7): 429 và mã lạ không được rơi về câu tiếng Anh của Dio.
  group('429 và mã lạ', () {
    AppException mapWithHeaders(
      int status,
      Object? body,
      Map<String, List<String>> headers,
    ) => mapDioException(
      DioException(
        requestOptions: RequestOptions(path: '/x'),
        response: Response(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: status,
          data: body,
          headers: Headers.fromMap(headers),
        ),
        type: DioExceptionType.badResponse,
      ),
    );

    test('429 kèm Retry-After → "thử lại sau N giây"', () {
      final e = mapWithHeaders(
        429,
        {'message': 'Too Many Attempts.'},
        {
          'retry-after': ['12'],
        },
      );

      expect(e, isA<RateLimitedException>());
      expect(
        e.message,
        'Bạn thao tác quá nhanh. Vui lòng thử lại sau 12 giây.',
      );
      expect(
        (e as RateLimitedException).retryAfter,
        const Duration(seconds: 12),
      );
    });

    test('409 không body → câu tiếng Việt, giữ mã', () {
      final e = mapOf(409, null);

      expect(e, isA<RequestRejectedException>());
      expect(e.code, '409');
      expect(e.message, isNot(contains('status code')));
      expect(e.message, isNot(contains('DioException')));
    });

    test('410 có lời của API → giữ nguyên', () {
      final e = mapOf(410, {'message': 'Liên kết đã hết hạn.'});

      expect(e.message, 'Liên kết đã hết hạn.');
    });
  });

  group('parseRetryAfter', () {
    test('số giây', () {
      expect(parseRetryAfter('0'), Duration.zero);
      expect(parseRetryAfter('7'), const Duration(seconds: 7));
    });

    test('ngày giờ HTTP', () {
      expect(
        parseRetryAfter(
          'Wed, 21 Oct 2026 07:28:00 GMT',
          now: DateTime.utc(2026, 10, 21, 7, 27, 30),
        ),
        const Duration(seconds: 30),
      );
    });

    test('hỏng hoặc thiếu → null', () {
      expect(parseRetryAfter('abc'), isNull);
      expect(parseRetryAfter(null), isNull);
      expect(parseRetryAfter(''), isNull);
    });
  });

  group('humanError', () {
    test('AppException → lời của nó, không phải toString()', () {
      expect(
        humanError(
          const ValidationException('Không có máy nào đang chạy agent.'),
        ),
        'Không có máy nào đang chạy agent.',
      );
    });

    test('lỗi lạ → câu chung', () {
      expect(humanError(StateError('boom'), fallback: 'Lỗi.'), 'Lỗi.');
    });
  });
}
