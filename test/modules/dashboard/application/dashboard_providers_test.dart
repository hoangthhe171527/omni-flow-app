import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/modules/dashboard/application/dashboard_providers.dart';
import 'package:omni_app/modules/dashboard/domain/revenue_period.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session_controller.dart';

import '../data/dashboard_api_contract_test.dart' show FakeAdapter, envelope;

void main() {
  ProviderContainer make(FakeAdapter adapter, Set<String> perms) {
    final c = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(
          ApiClient(Dio()..httpClientAdapter = adapter),
        ),
        accessProvider.overrideWithValue(AccessPolicy(perms)),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('thiếu cả hai quyền revenue → null, không gọi mạng', () async {
    final adapter = FakeAdapter(
      200,
      envelope({'current': <num>[], 'previous': <num>[]}),
    );
    final c = make(adapter, {'tasks.read', 'inbox.read'});
    expect(await c.read(revenueSeriesProvider.future), isNull);
    expect(adapter.requests, isEmpty);
  });

  test('có quyền read.all → gọi mạng với range đang chọn', () async {
    final adapter = FakeAdapter(
      200,
      envelope({
        'current': [1],
        'previous': <num>[],
        'target': null,
      }),
    );
    final c = make(adapter, {'crm.sales_overview.read.all'});
    c.read(revenueRangeProvider.notifier).state = RevenueRange.year;
    expect(await c.read(revenueSeriesProvider.future), isNotNull);
    expect(adapter.requests.single.uri.queryParameters['range'], 'year');
  });

  test(
    'dashboardAwaitingReplyProvider gửi status=open&unread=1&per_page=5',
    () async {
      final adapter = FakeAdapter(200, envelope(<Object>[]));
      final c = make(adapter, {'inbox.read'});
      await c.read(dashboardAwaitingReplyProvider.future);
      final req = adapter.requests.single;
      expect(req.uri.path, '/api/v1/inbox/conversations');
      final q = req.uri.queryParameters;
      expect(q['status'], 'open');
      expect(q['unread'], '1');
      expect(q['per_page'], '5');
    },
  );

  test(
    'dashboardMyTasksProvider gửi assignee=me&bucket=today&per_page=5',
    () async {
      final adapter = FakeAdapter(200, envelope(<Object>[]));
      final c = make(adapter, {'tasks.read'});
      await c.read(dashboardMyTasksProvider.future);
      final q = adapter.requests.single.uri.queryParameters;
      expect(q['assignee'], 'me');
      expect(q['bucket'], 'today');
      expect(q['per_page'], '5');
    },
  );
}
