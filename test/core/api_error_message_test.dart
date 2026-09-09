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
}
