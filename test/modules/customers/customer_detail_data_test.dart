import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/modules/customers/application/customers_providers.dart';
import 'package:omni_app/modules/customers/data/customers_api.dart';
import 'package:omni_app/modules/customers/domain/customer_activity.dart';
import 'package:omni_app/modules/customers/domain/customer_summary.dart';
import 'package:omni_app/modules/opportunities/application/opportunities_providers.dart';
import 'package:omni_app/modules/opportunities/data/opportunities_api.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session_controller.dart';

/// Hợp đồng dữ liệu trang chi tiết khách. Khoá theo omni-flow-api (2026-10-10):
/// - `GetCustomerSummary::execute` → `orders.{count,total_amount}`,
///   `opportunities_count` (+ paid, outstanding, last_order_at, quotes_count).
/// - `InteractionLogDTO::toArray` → `interaction_type`, `content`,
///   `interacted_at`, `created_at`; `InteractionLogController::index` nhận
///   `customer_id`, `exclude_types`, `per_page`.
/// - `SalesOpportunityController::stringFilters` nhận `customer_id`.
class _FakeClient extends ApiClient {
  _FakeClient() : super(Dio());

  final gets = <({String path, Map<String, dynamic>? query})>[];
  Object? data;
  AppException? failWith;

  @override
  Future<ApiEnvelope> get(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) async {
    gets.add((path: path, query: query));
    final error = failWith;
    if (error != null) throw error;
    return ApiEnvelope({'success': true, 'data': data});
  }
}

void main() {
  group('CustomerSummary.fromJson', () {
    test('đọc orders.total_amount, orders.count, opportunities_count', () {
      final s = CustomerSummary.fromJson({
        'orders': {'count': 4, 'total_amount': 186000000},
        'opportunities_count': 3,
      });
      expect(s.ordersTotal, 186000000);
      expect(s.ordersCount, 4);
      expect(s.opportunitiesCount, 3);
    });

    test('thiếu orders → tổng null, số đơn 0', () {
      final s = CustomerSummary.fromJson({'opportunities_count': 2});
      expect(s.ordersTotal, isNull);
      expect(s.ordersCount, 0);
      expect(s.opportunitiesCount, 2);
    });
  });

  group('CustomersApi', () {
    test('summary gọi GET /customers/{id}/summary', () async {
      final client = _FakeClient()
        ..data = {
          'orders': {'count': 1, 'total_amount': 5.5},
          'opportunities_count': 7,
        };
      final s = await CustomersApi(client).summary('c1');
      expect(client.gets.single.path, '/customers/c1/summary');
      expect(s.ordersTotal, 5.5);
      expect(s.opportunitiesCount, 7);
    });

    test(
      'activities: /interaction-logs, customer_id, bỏ VIEW, map loại',
      () async {
        final client = _FakeClient()
          ..data = [
            {
              'id': 'a1',
              'interaction_type': 'VIEW',
              'content': 'Xem hồ sơ',
              'interacted_at': '2026-10-01T03:00:00Z',
            },
            {
              'id': 'a2',
              'interaction_type': 'CALL',
              'content': 'Gọi tư vấn',
              'interacted_at': '2026-10-02T03:00:00Z',
              'created_at': '2026-10-02T04:00:00Z',
            },
            {
              'id': 'a3',
              'interaction_type': 'NOTE',
              'content': 'Ghi chú',
              'created_at': '2026-10-03T04:00:00Z',
            },
          ];
        final list = await CustomersApi(client).activities('c1', perPage: 5);
        final q = client.gets.single;
        expect(q.path, '/interaction-logs');
        expect(q.query!['customer_id'], 'c1');
        expect(q.query!['per_page'], 5);
        expect(q.query!['exclude_types'], 'VIEW');
        expect(list.map((a) => a.id), ['a2', 'a3']);
        expect(list.first.kind, ActivityKind.call);
        expect(list.first.text, 'Gọi tư vấn');
        expect(list.first.at, DateTime.parse('2026-10-02T03:00:00Z'));
        // thiếu interacted_at → created_at
        expect(list.last.at, DateTime.parse('2026-10-03T04:00:00Z'));
      },
    );
  });

  test('ActivityKind.fromType theo interaction_type của máy chủ', () {
    const expected = {
      'MESSAGE': ActivityKind.message,
      'CHAT': ActivityKind.message,
      'EMAIL': ActivityKind.message,
      'CALL': ActivityKind.call,
      'MEETING': ActivityKind.call,
      'QUOTATION': ActivityKind.order,
      'FOLLOW_UP': ActivityKind.task,
      'ASSIGNMENT': ActivityKind.task,
      'NOTE': ActivityKind.note,
      'LẠ': ActivityKind.other,
    };
    expected.forEach((type, kind) {
      expect(ActivityKind.fromType(type), kind, reason: type);
    });
    expect(ActivityKind.fromType(null), ActivityKind.other);
  });

  group('OpportunitiesApi.listQuery customerId', () {
    test('gửi customer_id khi có', () {
      expect(OpportunitiesApi.listQuery(customerId: 'c1')['customer_id'], 'c1');
    });
    test('không gửi khi null hoặc rỗng', () {
      expect(OpportunitiesApi.listQuery().containsKey('customer_id'), isFalse);
      expect(
        OpportunitiesApi.listQuery(customerId: '').containsKey('customer_id'),
        isFalse,
      );
    });
  });

  group('providers', () {
    test('customerSummaryProvider: 403 → null, không lỗi', () async {
      final client = _FakeClient()..failWith = const ForbiddenException('no');
      final container = ProviderContainer(
        overrides: [
          customersApiProvider.overrideWithValue(CustomersApi(client)),
        ],
      );
      addTearDown(container.dispose);
      final value = await container.read(customerSummaryProvider('c1').future);
      expect(value, isNull);
    });

    test('customerSummaryProvider: thành công trả summary', () async {
      final client = _FakeClient()
        ..data = {
          'orders': {'count': 2, 'total_amount': 10},
        };
      final container = ProviderContainer(
        overrides: [
          customersApiProvider.overrideWithValue(CustomersApi(client)),
        ],
      );
      addTearDown(container.dispose);
      final value = await container.read(customerSummaryProvider('c1').future);
      expect(value!.ordersCount, 2);
    });

    test('customerActivityAccessProvider theo crm.interaction_logs.read', () {
      bool access(AccessPolicy policy) {
        final c = ProviderContainer(
          overrides: [accessProvider.overrideWithValue(policy)],
        );
        addTearDown(c.dispose);
        return c.read(customerActivityAccessProvider);
      }

      expect(access(const AccessPolicy({'crm.interaction_logs.read'})), isTrue);
      expect(access(const AccessPolicy({'crm.customers.read'})), isFalse);
      expect(access(const AccessPolicy.empty()), isFalse);
    });

    test(
      'customerOpportunitiesProvider gọi /sales-opportunities với customer_id, per_page 50',
      () async {
        final client = _FakeClient()..data = <Object>[];
        final container = ProviderContainer(
          overrides: [
            opportunitiesApiProvider.overrideWithValue(
              OpportunitiesApi(client),
            ),
          ],
        );
        addTearDown(container.dispose);
        final list = await container.read(
          customerOpportunitiesProvider('c1').future,
        );
        expect(list, isEmpty);
        final q = client.gets.single;
        expect(q.path, '/sales-opportunities');
        expect(q.query!['customer_id'], 'c1');
        expect(q.query!['per_page'], 50);
        expect(q.query!.containsKey('status'), isFalse);
      },
    );
  });
}
