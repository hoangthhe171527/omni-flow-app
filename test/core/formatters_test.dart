import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/core/utils/formatters.dart';
import 'package:omni_app/modules/opportunities/domain/opportunity.dart';

/// Tiền rút gọn kiểu vi-VN như web (`formatMoneyCompact`) và ngày giờ theo giờ
/// VN (Asia/Ho_Chi_Minh), không theo múi giờ của máy (APP-I14).
void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  group('vndCompact — như formatMoneyCompact của web', () {
    test('dấu phẩy thập phân, hậu tố tr/tỷ, nghìn là "k" không cách', () {
      expect(Formatters.vndCompact(34900000), '34,9 tr');
      expect(Formatters.vndCompact(1200000000), '1,2 tỷ');
      expect(Formatters.vndCompact(12000), '12k');
      expect(Formatters.vndCompact(1000000), '1 tr');
      expect(Formatters.vndCompact(-2500000), '-2,5 tr');
      expect(Formatters.vndCompact(999), '999');
      expect(Formatters.vndCompact(null), '—');
    });
  });

  group('ngày giờ theo giờ VN', () {
    // Kỳ vọng tính từ UTC, nên đúng ở MỌI múi máy (review M5). Dart không đặt
    // được múi giờ trong test; máy dev UTC+7 thì toLocal() cũ cũng ra đúng.
    DateTime vnOf(DateTime instant) =>
        instant.toUtc().add(const Duration(hours: 7));

    test('giá trị cục bộ khác 00:00 là mốc thật: quy về UTC rồi +7 (M4)', () {
      final local = DateTime(2026, 10, 5, 10, 15);
      expect(VnTime.of(local), vnOf(local));
      expect(VnTime.of(local).isUtc, isTrue);
      final vn = vnOf(local);
      final hh = vn.hour.toString().padLeft(2, '0');
      final mm = vn.minute.toString().padLeft(2, '0');
      expect(Formatters.time(local), '$hh:$mm');
    });

    test('mốc UTC sát nửa đêm VN: ngày theo VN, không theo múi máy', () {
      // 16:59Z = 23:59 ngày 4 VN; 17:01Z = 00:01 ngày 5 VN.
      expect(Formatters.date(DateTime.utc(2026, 10, 4, 16, 59)), '04/10/2026');
      expect(Formatters.date(DateTime.utc(2026, 10, 4, 17, 1)), '05/10/2026');
      expect(Formatters.time(DateTime.utc(2026, 10, 4, 17, 1)), '00:01');
    });

    test('ngày lịch cục bộ 00:00 giữ nguyên ngày', () {
      expect(VnTime.of(DateTime(2026, 10, 5)), DateTime.utc(2026, 10, 5));
      expect(
        VnTime.day(DateTime.parse('2026-10-05')),
        DateTime.utc(2026, 10, 5),
      );
    });

    test('mốc UTC 18:30 ngày 4 là 01:30 ngày 5 ở VN', () {
      final at = DateTime.utc(2026, 10, 4, 18, 30);
      expect(Formatters.date(at), '05/10/2026');
      expect(Formatters.time(at), '01:30');
    });

    test('ngày lịch YYYY-MM-DD không lệch ngày ở múi nào', () {
      expect(Formatters.date(DateTime.parse('2026-10-05')), '05/10/2026');
    });

    test('"Hôm qua" so theo ngày VN, kể cả sát nửa đêm VN', () {
      // 22:00 ngày 4 VN so với 00:30 ngày 5 VN: khác ngày VN → Hôm qua.
      expect(
        Formatters.relative(
          DateTime.utc(2026, 10, 4, 15),
          clock: DateTime.utc(2026, 10, 4, 17, 30),
        ),
        'Hôm qua',
      );
      // 01:00 → 05:00 cùng ngày 5 VN (trước 07:00 UTC): vẫn "giờ", dù ở UTC
      // hai mốc nằm ở hai ngày khác nhau.
      expect(
        Formatters.relative(
          DateTime.utc(2026, 10, 4, 18),
          clock: DateTime.utc(2026, 10, 4, 22),
        ),
        '4 giờ',
      );
    });

    test('tiêu đề ngày "Hôm nay/Hôm qua" theo ngày VN', () {
      final clock = DateTime.utc(2026, 10, 4, 17, 30); // 00:30 ngày 5 VN
      expect(
        Formatters.dayHeader(DateTime.utc(2026, 10, 4, 17, 10), clock: clock),
        'Hôm nay',
      );
      expect(
        Formatters.dayHeader(DateTime.utc(2026, 10, 4, 16, 50), clock: clock),
        'Hôm qua',
      );
    });
  });

  group('quá hạn của cơ hội theo ngày VN', () {
    final opp = Opportunity.fromJson({
      'id': 'o1',
      'title': 'Piano',
      'opportunity_stage': 'new',
      'opportunity_status': 'OPEN',
      'expected_end_date': '2026-10-04',
    });

    test('00:01 ngày 5 VN thì hạn ngày 4 đã quá', () {
      expect(opp.isOverdueAt(DateTime.utc(2026, 10, 4, 17, 1)), isTrue);
    });

    test('23:59 ngày 4 VN thì chưa quá hạn', () {
      expect(opp.isOverdueAt(DateTime.utc(2026, 10, 4, 16, 59)), isFalse);
    });

    // Dạng API thật trả (`datetime` cast → ISO UTC nửa đêm), như JSON thật.
    test('expected_end_date dạng API thật cho cùng kết quả', () {
      final real = Opportunity.fromJson({
        'id': 'o2',
        'title': 'Piano',
        'opportunity_stage': 'new',
        'opportunity_status': 'OPEN',
        'expected_end_date': '2026-10-04T00:00:00.000000Z',
      });
      expect(real.isOverdueAt(DateTime.utc(2026, 10, 4, 17, 1)), isTrue);
      expect(real.isOverdueAt(DateTime.utc(2026, 10, 4, 16, 59)), isFalse);
    });
  });
}
