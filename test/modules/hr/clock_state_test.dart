import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/core/network/api_exception_mapper.dart';
import 'package:omni_app/modules/hr/domain/clock_state.dart';
import 'package:omni_app/modules/hr/domain/hr_models.dart';

/// 422 thật như `AttendanceController::mePunch` trả về, qua đúng bộ ánh xạ lỗi
/// của app — bài này hỏng nếu ai đó đổi `mapDioException` làm rơi `code`.
AppException _reject(String code, {double? distance}) => mapDioException(
  DioException(
    requestOptions: RequestOptions(path: '/hr/me/punches'),
    type: DioExceptionType.badResponse,
    response: Response(
      requestOptions: RequestOptions(path: '/hr/me/punches'),
      statusCode: 422,
      data: {
        'success': false,
        'code': code,
        'message': code == 'DEVICE_NOT_BOUND'
            ? 'Máy này chưa được gắn với bạn. Nhờ quản đốc gỡ máy cũ.'
            : 'Bạn đang ở ngoài xưởng. Gửi giải trình nếu đang làm ngoài.',
        'data': {
          'accepted': false,
          'reject_code': code,
          'method': null,
          'distance_m': distance,
        },
      },
    ),
  ),
);

const _zone = HrZone(
  wifi: [HrWifi(name: 'Xưởng 50 Dân Chủ', ssid: 'Xuong-50DanChu')],
  hasSite: true,
  radiusM: 150,
);

void main() {
  group('phân loại nút chấm', () {
    test('chưa chấm → Chấm vào; đã vào → Chấm ra; đủ → Đã xong ca', () {
      expect(classifyClock(serverNext: 'in'), ClockAction.clockIn);
      expect(classifyClock(serverNext: 'out'), ClockAction.clockOut);
      expect(classifyClock(serverNext: 'done'), ClockAction.done);
    });

    test('lượt chờ offline đẩy nút sang lượt kế, không đợi có mạng', () {
      expect(
        classifyClock(serverNext: 'in', queuedKinds: ['in']),
        ClockAction.clockOut,
      );
      expect(
        classifyClock(serverNext: 'in', queuedKinds: ['in', 'out']),
        ClockAction.done,
      );
      expect(
        classifyClock(serverNext: 'out', queuedKinds: ['out']),
        ClockAction.done,
      );
    });

    test('máy lạ / ngoài vùng / khoá tháng → Không chấm được', () {
      for (final code in ['DEVICE_NOT_BOUND', 'OUT_OF_ZONE', 'MONTH_LOCKED']) {
        expect(
          classifyClock(serverNext: 'in', rejectCode: code),
          ClockAction.blocked,
          reason: code,
        );
      }
      // Mã lạ không khoá nút.
      expect(
        classifyClock(serverNext: 'in', rejectCode: 'X'),
        ClockAction.clockIn,
      );
      // Xong ca thắng mọi lời từ chối cũ.
      expect(
        classifyClock(serverNext: 'done', rejectCode: 'OUT_OF_ZONE'),
        ClockAction.done,
      );
    });
  });

  group('lỗi chấm của API', () {
    test('DEVICE_NOT_BOUND đọc ra mã và lời', () {
      final r = PunchRejection.fromError(_reject('DEVICE_NOT_BOUND'));
      expect(r, isNotNull);
      expect(r!.code, 'DEVICE_NOT_BOUND');
      expect(r.message, contains('gỡ máy cũ'));
    });

    test('OUT_OF_ZONE giữ khoảng cách để hiện "Cách xưởng 1,2 km"', () {
      final r = PunchRejection.fromError(
        _reject('OUT_OF_ZONE', distance: 1234.5),
      );
      expect(r!.code, 'OUT_OF_ZONE');
      expect(r.distanceM, 1234.5);
      final line = describeLocation(zone: _zone, rejection: r);
      expect(line.value, 'Cách xưởng 1,2 km');
      expect(line.tone, LocationTone.bad);
    });

    test('mất mạng không phải lời từ chối, mà là vào hàng chờ', () {
      final offline = mapDioException(
        DioException(
          requestOptions: RequestOptions(path: '/hr/me/punches'),
          type: DioExceptionType.connectionError,
        ),
      );
      expect(PunchRejection.fromError(offline), isNull);
      expect(isOfflineError(offline), isTrue);
      expect(isOfflineError(_reject('OUT_OF_ZONE')), isFalse);
    });
  });

  group('dòng vị trí', () {
    test('WiFi xưởng (SSID trong ngoặc kép của iOS) → Trong xưởng', () {
      final line = describeLocation(
        zone: _zone,
        reading: const SensorReading(ssid: '"Xuong-50DanChu"'),
      );
      expect(line.title, 'WiFi xưởng');
      expect(line.value, 'Trong xưởng');
      expect(line.subtitle, 'Xưởng 50 Dân Chủ');
    });

    test('mất mạng đứng trước mọi thứ', () {
      final line = describeLocation(
        zone: _zone,
        reading: const SensorReading(ssid: 'Xuong-50DanChu'),
        offline: true,
      );
      expect(line.value, 'Lưu trên máy');
    });

    test('web / không cảm biến → Ngoài vùng, không vỡ', () {
      final line = describeLocation(
        zone: _zone,
        reading: const SensorReading(unavailable: true),
      );
      expect(line.value, 'Ngoài vùng');
    });

    test('máy lạ → Chưa đăng ký', () {
      final line = describeLocation(
        zone: _zone,
        rejection: PunchRejection.fromError(_reject('DEVICE_NOT_BOUND')),
      );
      expect(line.title, 'Điện thoại này');
      expect(line.value, 'Chưa đăng ký');
    });
  });
}
