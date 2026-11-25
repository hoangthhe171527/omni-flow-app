import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/hr/domain/clock_state.dart';
import 'package:omni_app/modules/hr/domain/hr_models.dart';
import 'package:omni_app/modules/hr/domain/vietqr.dart';
import 'package:qr/qr.dart';

void main() {
  group('VietQR', () {
    test('CRC-16/CCITT-FALSE đúng vector chuẩn', () {
      expect(crc16('123456789'), '29B1');
    });

    test('Techcombank 970407 · 190223353307 (khớp web vietqr.ts)', () {
      final s = vietQrPayload('970407', '190223353307')!;
      expect(s.startsWith('000201010211'), isTrue);
      expect(s, contains('0010A000000727'));
      expect(s, contains('0006970407'));
      expect(s, contains('0112190223353307'));
      expect(s, contains('0208QRIBFTTA'));
      expect(s, contains('5303704'));
      expect(s, contains('5802VN'));
      expect(s.substring(s.length - 8, s.length - 4), '6304');
      expect(s.substring(s.length - 4), crc16(s.substring(0, s.length - 4)));
      // Nguyên chuỗi, đối chiếu thuật toán web (vietqr.ts) cùng đầu vào.
      expect(
        s,
        '00020101021138560010A0000007270126000697040701121902233533070208'
        'QRIBFTTA53037045802VN63042FA4',
      );
      // Mã QR dựng được (mức M) — đúng thứ màn Phiếu lương vẽ.
      final image = QrImage(
        QrCode.fromData(data: s, errorCorrectLevel: QrErrorCorrectLevel.M),
      );
      expect(image.moduleCount, greaterThanOrEqualTo(21));
    });

    test('BIN / số tài khoản sai → null', () {
      expect(vietQrPayload(null, '190223353307'), isNull);
      expect(vietQrPayload('97040', '190223353307'), isNull);
      expect(vietQrPayload('970407', '12345'), isNull);
      expect(vietQrPayload('970407', '19A0223353'), isNull);
    });

    test('phiếu lương đọc account + holder', () {
      final p = Payslip.fromJson('2026-10', {
        'bank': {
          'name': 'Techcombank',
          'bin': '970407',
          'account': '190223353307',
          'holder': 'VU VAN HOANG',
          'account_masked': '•••• 3307',
        },
      });
      expect(p.bankAccount, '190223353307');
      expect(p.bankHolder, 'VU VAN HOANG');
      expect(vietQrPayload(p.bankBin, p.bankAccount), isNotNull);
    });
  });

  group('vị trí GPS trước khi chấm', () {
    final zone = HrZone.fromJson({
      'wifi': const [],
      'has_site': true,
      'radius_m': 150,
      'site': {'lat': 21.0285, 'lng': 105.8542, 'radius_m': 150},
    });

    test('đọc zone.site; null khi API không gửi', () {
      expect(zone.site!.radiusM, 150);
      expect(HrZone.fromJson({'site': null}).site, isNull);
    });

    test('haversine: ~0,001° vĩ độ ≈ 111 m', () {
      expect(distanceM(21.0285, 105.8542, 21.0295, 105.8542), closeTo(111, 1));
    });

    test('cách 40 m → Trong xưởng', () {
      final line = describeLocation(
        zone: zone,
        reading: const SensorReading(lat: 21.02886, lng: 105.8542),
      );
      expect(line.value, 'Trong xưởng');
      expect(line.subtitle, 'Cách xưởng 40 m');
      expect(line.tone, LocationTone.ok);
    });

    test('cách 1,2 km → Ngoài vùng', () {
      final line = describeLocation(
        zone: zone,
        reading: const SensorReading(lat: 21.0393, lng: 105.8542),
      );
      expect(line.value, 'Ngoài vùng');
      expect(line.subtitle, 'Cách xưởng 1,2 km');
      expect(line.tone, LocationTone.bad);
    });

    test('sai số GPS cộng vào bán kính tối đa 50 m (như server)', () {
      // ~178 m: ngoài 150, trong 150 + 50.
      const r = SensorReading(lat: 21.0301, lng: 105.8542, accuracyM: 80);
      expect(describeLocation(zone: zone, reading: r).value, 'Trong xưởng');
    });
  });

  test('/hr/today: cont_types có giá cho quản đốc', () {
    final w = HrWorkshopToday.fromJson({
      'date': '2026-11-24',
      'cont_types': [
        {'code': 'B', 'price': 400000},
        {'code': '', 'price': 1},
      ],
    });
    expect(w.contTypes.single.code, 'B');
    expect(w.contTypes.single.price, 400000);
  });
}
