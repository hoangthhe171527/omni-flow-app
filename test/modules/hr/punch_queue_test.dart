import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/modules/hr/data/punch_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _punch(String kind) => {
  'kind': kind,
  'client_at': '2026-11-24T00:52:00.000Z',
  'device_key': 'abcdef0123456789',
};

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  PunchQueue queue({String membership = 'm-1'}) =>
      PunchQueue(prefs, tenantId: 't-1', membershipId: membership);

  test(
    'lượt chấm lúc mất mạng được lưu kèm offline:true, theo thứ tự',
    () async {
      await queue().add(_punch('in'));
      await queue().add(_punch('out'));

      // Đọc lại bằng một đối tượng mới: dữ liệu nằm trên đĩa, không trong RAM.
      final q = queue();
      expect(q.kinds, ['in', 'out']);
      expect(q.items.every((i) => i['offline'] == true), isTrue);
      expect(q.items.first['client_at'], '2026-11-24T00:52:00.000Z');
    },
  );

  test('vẫn mất mạng → dừng, giữ nguyên hàng', () async {
    await queue().add(_punch('in'));
    await queue().add(_punch('out'));
    var calls = 0;

    final r = await queue().flush((_) async {
      calls++;
      throw const NetworkException('Không có kết nối mạng.');
    });

    expect(calls, 1, reason: 'không thử lượt sau khi lượt trước còn kẹt');
    expect(r.sent, 0);
    expect(r.remaining, 2);
    expect(queue().kinds, ['in', 'out']);
  });

  test('có mạng → gửi lần lượt, hàng rỗng', () async {
    await queue().add(_punch('in'));
    await queue().add(_punch('out'));
    final sent = <String>[];

    final r = await queue().flush((body) async => sent.add('${body['kind']}'));

    expect(sent, ['in', 'out']);
    expect(r.sent, 2);
    expect(r.remaining, 0);
    expect(queue().isEmpty, isTrue);
    expect(prefs.getKeys(), isEmpty, reason: 'hàng rỗng thì xoá khoá');
  });

  test('server từ chối (ngoài vùng) → bỏ lượt đó, báo lại, gửi tiếp', () async {
    await queue().add(_punch('in'));
    await queue().add(_punch('out'));
    final sent = <String>[];

    final r = await queue().flush((body) async {
      if (body['kind'] == 'in') {
        throw const ValidationException(
          'Bạn đang ở ngoài xưởng.',
          reason: 'OUT_OF_ZONE',
        );
      }
      sent.add('${body['kind']}');
    });

    expect(r.rejected?.code, 'OUT_OF_ZONE');
    expect(sent, ['out']);
    expect(queue().isEmpty, isTrue);
  });

  test('mỗi người một hàng: không gửi nhầm lượt của người khác', () async {
    await queue(membership: 'm-1').add(_punch('in'));
    expect(queue(membership: 'm-2').isEmpty, isTrue);
  });
}
