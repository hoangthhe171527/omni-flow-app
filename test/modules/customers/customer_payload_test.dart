import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/customers/domain/customer.dart';

/// Lưu khách từ app: trạng thái API mịn hơn nhóm app hiển thị (`AT_RISK`,
/// `LOST` đều hiện "Ngưng hoạt động"). Không đổi trạng thái thì phải gửi lại
/// đúng mã gốc, không phải `INACTIVE`.
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
  );

  for (final raw in ['AT_RISK', 'LOST', 'INACTIVE', 'WARM', 'ACTIVE']) {
    test('$raw không đổi trạng thái → gửi lại $raw', () {
      final customer = Customer.fromJson(json(raw));
      expect(customer.toPayload()['customer_status'], raw);
      expect(edit(customer).toPayload()['customer_status'], raw);
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

  test('sửa form giữ mã số thuế, tags, kênh của bản ghi gốc', () {
    final payload = edit(Customer.fromJson(json('LOST'))).toPayload();
    expect(payload['tax_code'], '0312345678');
    final metadata = payload['metadata'] as Map;
    expect(metadata['tags'], ['vip']);
    expect(metadata['channel'], 'zalo');
    expect(payload['legal_name'], 'Công ty Hoa Sen (sửa)');
  });

  test('tạo mới: nhóm đã chọn → mã tương ứng', () {
    final draft = Customer.blank().applyForm(
      name: 'Khách mới',
      contactName: '',
      phone: '0901',
      email: '',
      address: '',
      source: Customer.blank().source,
      status: CustomerStatus.inactive,
    );
    expect(draft.toPayload()['customer_status'], 'INACTIVE');
  });
}
