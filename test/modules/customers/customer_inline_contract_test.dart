import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/modules/customers/application/customer_editor.dart';
import 'package:omni_app/modules/customers/application/customers_providers.dart';
import 'package:omni_app/modules/customers/domain/customer.dart';
import 'package:omni_app/modules/customers/domain/customer_field.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

/// Khoá `UpdateCustomerRequest::rules()` (omni-flow-api
/// modules/Crm/Interfaces/Http/Requests/UpdateCustomerRequest.php:51-64,
/// 2026-10-10). Khoá ngoài danh sách bị máy chủ bỏ LẶNG và vẫn trả 200 — lớp lỗi
/// lặp lại của dự án. Đổi luật máy chủ thì đổi danh sách này cùng lúc.
const serverKeys = {
  'legal_name',
  'display_name',
  'customer_type',
  'industry_category',
  'tax_code',
  'primary_contact_name',
  'primary_contact_phone',
  'primary_contact_email',
  'address',
  'assigned_sales_rep_id',
  'customer_status',
  'metadata',
};

class _FakeClient extends ApiClient {
  _FakeClient() : super(Dio());

  final puts = <({String path, Object? body})>[];
  int gets = 0;
  AppException? failWith;
  Map<String, dynamic> response = const {};

  @override
  Future<ApiEnvelope> put(String path, {Object? body}) async {
    puts.add((path: path, body: body));
    final error = failWith;
    if (error != null) throw error;
    return ApiEnvelope({'success': true, 'data': response});
  }

  @override
  Future<ApiEnvelope> get(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) async {
    gets++;
    return const ApiEnvelope({'success': true, 'data': []});
  }
}

void main() {
  final loaded = Customer.fromJson({
    'id': 'c1',
    'legal_name': 'Spa Hạnh Phúc',
    'display_name': 'Spa Hạnh Phúc',
    'primary_contact_phone': '0283822456',
    'primary_contact_email': 'a@b.vn',
    'address': '12 Lê Thánh Tôn',
    'customer_status': 'ACTIVE',
    'assigned_sales_rep_id': 'u-1',
    'assigned_sales_rep_name': 'Hoàng Trần',
    'metadata': {
      'source': 'zalo',
      'tags': ['Hợp đồng'],
      'notes': 'cũ',
      'note': 'cũ',
      'party_type': 'business',
    },
  });

  Map<String, dynamic> body(CustomerField f, Object? v) =>
      loaded.patch(f, v).toPayload();

  test('mọi khoá gửi đi đều nằm trong luật máy chủ', () {
    for (final (f, v) in <(CustomerField, Object?)>[
      (CustomerField.phone, '0901'),
      (CustomerField.email, 'x@y.vn'),
      (CustomerField.address, 'Q1'),
      (CustomerField.note, 'mới'),
      (CustomerField.owner, (id: 'u-2', name: 'Lan')),
      (CustomerField.owner, (id: null, name: null)),
      (CustomerField.tags, ['VIP']),
    ]) {
      expect(serverKeys.containsAll(body(f, v).keys), isTrue, reason: '$f');
    }
  });

  test('apiKey và nhãn của từng trường', () {
    expect(CustomerField.phone.apiKey, 'primary_contact_phone');
    expect(CustomerField.email.apiKey, 'primary_contact_email');
    expect(CustomerField.address.apiKey, 'address');
    expect(CustomerField.note.apiKey, 'metadata');
    expect(CustomerField.owner.apiKey, 'assigned_sales_rep_id');
    expect(CustomerField.tags.apiKey, 'metadata');
    expect(CustomerField.values.map((f) => f.label), [
      'Điện thoại',
      'Email',
      'Địa chỉ',
      'Ghi chú',
      'Phụ trách',
      'Nhãn',
    ]);
  });

  test('Điện thoại → chỉ primary_contact_phone', () {
    expect(body(CustomerField.phone, '0901 000 001'), {
      'primary_contact_phone': '0901 000 001',
    });
  });
  test('Email → chỉ primary_contact_email', () {
    expect(body(CustomerField.email, 'x@y.vn'), {
      'primary_contact_email': 'x@y.vn',
    });
  });
  test('Địa chỉ → chỉ address', () {
    expect(body(CustomerField.address, 'Q1'), {'address': 'Q1'});
  });
  test('Ghi chú → metadata.notes và metadata.note, không khoá khác', () {
    expect(body(CustomerField.note, 'mới'), {
      'metadata': {'notes': 'mới', 'note': 'mới'},
    });
  });
  test(
    'Ghi chú xoá trống → chuỗi rỗng (máy chủ đổi thành null = xoá khoá)',
    () {
      expect(body(CustomerField.note, ''), {
        'metadata': {'notes': '', 'note': ''},
      });
    },
  );
  test('Phụ trách → assigned_sales_rep_id là userId', () {
    expect(body(CustomerField.owner, (id: 'u-2', name: 'Lan')), {
      'assigned_sales_rep_id': 'u-2',
    });
  });
  test('đổi người phụ trách không giữ tên cũ khi tên mới null', () {
    final next = loaded.patch(CustomerField.owner, (id: 'u-2', name: null));
    expect(next.ownerId, 'u-2');
    expect(next.ownerName, isNull);
  });
  test('Bỏ gán → gửi null TƯỜNG MINH (trước đây bị bỏ lặng)', () {
    final b = body(CustomerField.owner, (id: null, name: null));
    expect(b.containsKey('assigned_sales_rep_id'), isTrue);
    expect(b['assigned_sales_rep_id'], isNull);
    expect(b.length, 1);
  });
  test('Bỏ gán khách có owner_name cũ → xoá luôn khoá cũ (như web)', () {
    final legacy = Customer.fromJson({
      'id': 'c2',
      'display_name': 'A',
      'assigned_sales_rep_id': 'u-1',
      'assigned_sales_rep_name': 'Cũ',
      'metadata': {'owner_name': 'Cũ', 'sales_account': 'u-1'},
    });
    expect(
      legacy.patch(CustomerField.owner, (id: null, name: null)).toPayload(),
      {
        'assigned_sales_rep_id': null,
        'metadata': {'owner_name': null, 'sales_account': null},
      },
    );
  });
  test('Bỏ gán khi vốn không có người → body rỗng', () {
    final none = Customer.fromJson({'id': 'c3', 'display_name': 'B'});
    expect(
      none.patch(CustomerField.owner, (id: null, name: null)).toPayload(),
      isEmpty,
    );
  });
  test('Nhãn → metadata.tags danh sách đầy đủ', () {
    expect(body(CustomerField.tags, ['Hợp đồng', 'VIP']), {
      'metadata': {
        'tags': ['Hợp đồng', 'VIP'],
      },
    });
  });
  test('Doanh nghiệp: sửa trường không bao giờ gửi legal_name', () {
    expect(
      body(CustomerField.phone, '0901').containsKey('legal_name'),
      isFalse,
    );
  });
  test('không đổi gì → body rỗng', () {
    expect(body(CustomerField.address, '12 Lê Thánh Tôn'), isEmpty);
  });
  test(
    'tạo mới chưa chọn người phụ trách → không gửi assigned_sales_rep_id',
    () {
      final blank = Customer.blank();
      final draft = blank.applyForm(
        name: 'Mới',
        contactName: '',
        phone: '',
        email: '',
        address: '',
        source: blank.source,
        status: CustomerStatus.fresh,
      );
      expect(draft.toPayload().containsKey('assigned_sales_rep_id'), isFalse);
    },
  );

  group('CustomerEditor', () {
    late _FakeClient client;
    late ProviderContainer container;

    setUp(() {
      client = _FakeClient();
      container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(client),
          sessionProvider.overrideWithValue(
            Session(
              status: SessionStatus.authenticated,
              policy: AccessPolicy(const {}),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      // Giữ danh sách sống để thấy invalidate dựng lại.
      container.listen(customerListProvider, (_, _) {});
    });

    test(
      'PUT /customers/c1 đúng body, trả bản ghi máy chủ chuẩn hoá',
      () async {
        client.response = {
          'id': 'c1',
          'display_name': 'Spa Hạnh Phúc',
          'primary_contact_phone': '0901000001',
        };
        await container.read(customerListProvider.future);
        final before = client.gets;

        final saved = await container
            .read(customerEditorProvider)
            .save(loaded, CustomerField.phone, '0901 000 001');

        expect(client.puts, hasLength(1));
        expect(client.puts.single.path, '/customers/c1');
        expect(client.puts.single.body, {
          'primary_contact_phone': '0901 000 001',
        });
        expect(saved.phone, '0901000001');
        await container.read(customerListProvider.future);
        expect(client.gets, greaterThan(before));
      },
    );

    test('không đổi gì → không gọi máy chủ', () async {
      final saved = await container
          .read(customerEditorProvider)
          .save(loaded, CustomerField.address, '12 Lê Thánh Tôn');
      expect(saved, same(loaded));
      expect(client.puts, isEmpty);
    });

    test('422 → ném lại, không invalidate danh sách', () async {
      await container.read(customerListProvider.future);
      final before = client.gets;
      client.failWith = const ValidationException(
        'Email không hợp lệ.',
        errors: {
          'primary_contact_email': ['Email không hợp lệ.'],
        },
      );

      await expectLater(
        container
            .read(customerEditorProvider)
            .save(loaded, CustomerField.email, 'sai'),
        throwsA(isA<ValidationException>()),
      );
      await container.read(customerListProvider.future);
      expect(client.gets, before);
    });
  });
}
