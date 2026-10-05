import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/domain/channel.dart';
import 'package:omni_app/modules/customers/domain/customer.dart';

/// Lưu khách từ app.
///
/// - Trạng thái API mịn hơn nhóm app hiển thị (`AT_RISK`, `LOST` đều hiện
///   "Ngưng hoạt động"). Không đổi trạng thái thì không được biến nó thành
///   `INACTIVE`.
/// - API gộp NÔNG metadata khi PUT (`UpdateCustomer` → `MetadataPatch::merge`)
///   và giữ nguyên trường không gửi. App chỉ gửi trường đã đổi, nên không ghi
///   đè thứ web vừa sửa (tên pháp lý, nguồn, ghi chú, khoá metadata lạ).
void main() {
  Map<String, dynamic> json(String status) => {
    'id': 'c1',
    'legal_name': 'Công ty Hoa Sen',
    'customer_status': status,
    'tax_code': '0312345678',
    'metadata': {
      'tags': ['vip'],
      'channel': 'zalo',
    },
  };

  Customer edit(Customer c, {CustomerStatus? status}) => c.applyForm(
    name: 'Công ty Hoa Sen (sửa)',
    contactName: 'Chị Mai',
    phone: '0901000001',
    email: '',
    address: 'Hà Nội',
    source: c.source,
    status: status ?? c.status,
    note: c.note,
  );

  for (final raw in ['AT_RISK', 'LOST', 'INACTIVE', 'WARM', 'ACTIVE']) {
    test('$raw không đổi trạng thái → không gửi trạng thái khác $raw', () {
      final customer = Customer.fromJson(json(raw));
      expect(customer.statusCode, raw);
      expect(customer.toPayload()['customer_status'] ?? raw, raw);
      expect(edit(customer).toPayload()['customer_status'] ?? raw, raw);
    });
  }

  test('đổi sang nhóm khác → gửi mã của nhóm mới', () {
    final customer = Customer.fromJson(json('AT_RISK'));
    expect(
      edit(
        customer,
        status: CustomerStatus.active,
      ).toPayload()['customer_status'],
      'ACTIVE',
    );
    expect(
      edit(customer, status: CustomerStatus.vip).toPayload()['customer_status'],
      'WARM',
    );
    expect(
      customer
          .copyWith(status: CustomerStatus.active)
          .toPayload()['customer_status'],
      'ACTIVE',
    );
  });

  test('sửa form không gửi lại mã số thuế, tags, nguồn của bản ghi gốc', () {
    final customer = Customer.fromJson(json('LOST'));
    final payload = edit(customer).toPayload();
    // Máy chủ giữ trường không gửi — gửi lại bản app đang cầm chỉ để ghi đè
    // bản web vừa sửa.
    expect(payload.containsKey('tax_code'), isFalse);
    expect(payload.containsKey('metadata'), isFalse);
    expect(customer.taxCode, '0312345678');
    expect(customer.tags, ['vip']);
    expect(customer.source, Channel.zalo);
    expect(payload['display_name'], 'Công ty Hoa Sen (sửa)');
    expect(payload['primary_contact_phone'], '0901000001');
  });

  test('tạo mới: nhóm đã chọn → mã tương ứng; gửi đủ tên', () {
    final draft = Customer.blank().applyForm(
      name: 'Khách mới',
      contactName: '',
      phone: '0901',
      email: '',
      address: '',
      source: Customer.blank().source,
      status: CustomerStatus.inactive,
    );
    final payload = draft.toPayload();
    expect(payload['customer_status'], 'INACTIVE');
    // `legal_name` là bắt buộc khi tạo (CreateCustomerRequest).
    expect(payload['legal_name'], 'Khách mới');
    expect(payload['display_name'], 'Khách mới');
    expect((payload['metadata'] as Map)['source'], 'zalo');
    expect((payload['metadata'] as Map).containsKey('channel'), isFalse);
  });

  group('tên', () {
    test('sửa tên hiển thị trên app không ghi đè tên pháp lý', () {
      final c = Customer.fromJson({
        'id': 'c1',
        'customer_type': 'DIRECT_CLIENT',
        'legal_name': 'CÔNG TY TNHH AN',
        'display_name': 'An Piano',
        'metadata': {'party_type': 'business'},
      });
      expect(c.name, 'An Piano');
      final p = c.copyWith(name: 'An Piano Hà Nội').toPayload();
      expect(p.containsKey('legal_name'), isFalse);
      expect(p['display_name'], 'An Piano Hà Nội');
    });

    test('khách cá nhân chưa có tên pháp lý → điền luôn', () {
      final c = Customer.fromJson({
        'id': 'c1',
        'display_name': 'Chị Lan',
        'metadata': {'party_type': 'individual'},
      });
      final p = c.copyWith(name: 'Chị Lan Vũ').toPayload();
      expect(p['legal_name'], 'Chị Lan Vũ');
    });

    test('doanh nghiệp chưa có tên pháp lý → vẫn không điền thay', () {
      final c = Customer.fromJson({
        'id': 'c1',
        'display_name': 'An Piano',
        'metadata': {'party_type': 'business'},
      });
      final p = c.copyWith(name: 'An Piano HN').toPayload();
      expect(p.containsKey('legal_name'), isFalse);
    });

    test('không đổi tên → không gửi tên', () {
      final c = Customer.fromJson({
        'id': 'c1',
        'legal_name': 'A',
        'display_name': 'A',
      });
      final p = c.copyWith(phone: '0909').toPayload();
      expect(p.containsKey('display_name'), isFalse);
      expect(p.containsKey('legal_name'), isFalse);
      expect(p['primary_contact_phone'], '0909');
    });
  });

  group('metadata', () {
    Customer web() => Customer.fromJson({
      'id': 'c1',
      'display_name': 'A',
      'metadata': {
        'source': 'zalo',
        'notes': 'khách quen',
        'note': 'khách quen',
        'brand': 'Yamaha',
        'tags': ['cũ'],
      },
    });

    Customer formSave(Customer c, {Channel? source, String? note}) =>
        c.applyForm(
          name: c.name,
          contactName: c.contactName,
          phone: c.phone,
          email: c.email,
          address: c.address,
          source: source ?? c.source,
          status: c.status,
          note: note,
        );

    test('không làm mất khoá metadata web đã ghi', () {
      final p = web().copyWith(tags: ['vip']).toPayload();
      // API gộp metadata: chỉ khoá đổi đi lên, brand/source/notes ở yên.
      expect(p['metadata'], {
        'tags': ['vip'],
      });
    });

    test('đọc ghi chú và nguồn web ghi', () {
      final c = web();
      expect(c.note, 'khách quen');
      expect(c.source, Channel.zalo);
    });

    test('ghi chú: notes (chuỗi) trước note; notes là mảng thì đọc note', () {
      expect(
        Customer.fromJson({
          'id': 'c1',
          'metadata': {'notes': 'mới', 'note': 'cũ'},
        }).note,
        'mới',
      );
      expect(
        Customer.fromJson({
          'id': 'c1',
          'metadata': {'notes': <dynamic>[], 'note': 'app'},
        }).note,
        'app',
      );
    });

    test('lưu form không đổi gì → không gửi metadata', () {
      final c = web();
      expect(
        formSave(c, note: c.note).toPayload().containsKey('metadata'),
        isFalse,
      );
    });

    test('sửa ghi chú → ghi cả notes (web) lẫn note (app cũ)', () {
      final p = formSave(web(), note: 'gọi lại thứ 2').toPayload();
      expect(p['metadata'], {
        'notes': 'gọi lại thứ 2',
        'note': 'gọi lại thứ 2',
      });
    });

    test('xoá ghi chú → gửi null cho cả hai khoá (API xoá khoá)', () {
      final p = formSave(web()).toPayload();
      expect(p['metadata'], {'notes': null, 'note': null});
    });

    test('đổi nguồn → ghi metadata.source, xoá channel cũ của app', () {
      final c = Customer.fromJson({
        'id': 'c1',
        'display_name': 'A',
        'metadata': {'channel': 'zalo'},
      });
      expect(c.source, Channel.zalo);
      final p = formSave(c, source: Channel.facebook).toPayload();
      expect(p['metadata'], {'source': 'facebook', 'channel': null});
    });

    test('nguồn web (source) thắng khoá channel cũ của app', () {
      final c = Customer.fromJson({
        'id': 'c1',
        'metadata': {'source': 'facebook', 'channel': 'zalo'},
      });
      expect(c.source, Channel.facebook);
    });
  });

  group('số liệu', () {
    // Tổng giá trị = tổng đơn không huỷ (`orders_total`, API Đợt 7 A1). API cũ
    // chưa có khoá này thì hiện "—": `lifetime_booking_value` là số adcanvas cũ
    // không ai cập nhật (GD-I11, APP-I4, Review Focus #1).
    test('giá trị trọn đời chỉ đọc orders_total', () {
      expect(
        Customer.fromJson({
          'id': 'c1',
          'orders_total': 3200000,
          'lifetime_booking_value': '9',
        }).lifetimeValue,
        3200000,
      );
      expect(
        Customer.fromJson({
          'id': 'c1',
          'lifetime_booking_value': 9e6,
        }).lifetimeValue,
        isNull,
      );
      expect(
        Customer.fromJson({'id': 'c1', 'orders_total': 0}).lifetimeValue,
        0,
      );
    });

    test('tương tác gần nhất: last_interaction_at trước updated_at', () {
      final c = Customer.fromJson({
        'id': 'c1',
        'last_interaction_at': '2026-09-20T03:00:00Z',
        'updated_at': '2026-09-30T03:00:00Z',
      });
      expect(c.lastInteractionAt!.toUtc().day, 20);
    });

    // Sửa thông tin khách không phải là "liên hệ": thiếu `last_interaction_at`
    // thì không có mốc, không rơi về `updated_at`/`last_booking_date` (Q8a).
    test('không có last_interaction_at → không có mốc tương tác', () {
      final c = Customer.fromJson({
        'id': 'c1',
        'updated_at': '2026-09-30T03:00:00Z',
        'last_booking_date': '2026-09-29T03:00:00Z',
      });
      expect(c.lastInteractionAt, isNull);
    });
  });
}
