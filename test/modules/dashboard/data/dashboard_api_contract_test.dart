import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/modules/dashboard/data/dashboard_api.dart';
import 'package:omni_app/modules/dashboard/domain/revenue_period.dart';

import '../../../support/fake_http_adapter.dart';

/// Hợp đồng với omni-flow-api feat/revenue-series:
/// `GET /sales-overview/revenue-series` → `{success, data: {bucket, current,
/// previous, target, currency}}`.
void main() {
  final now = DateTime.utc(2026, 10, 10, 3);

  DashboardApi apiWith(FakeAdapter a) =>
      DashboardApi(ApiClient(Dio()..httpClientAdapter = a));

  test('gửi đúng đường dẫn và ĐÚNG bộ khoá query; parse data', () async {
    final adapter = FakeAdapter(
      200,
      envelope({
        'bucket': 'day',
        'current': [50, 100],
        'previous': [10, 20, 30],
        'target': 150,
        'currency': 'VND',
      }),
    );
    final s = await apiWith(
      adapter,
    ).revenueSeries(RevenueRange.month, now: now);

    final req = adapter.requests.single;
    expect(req.method, 'GET');
    expect(req.uri.path, '/api/v1/sales-overview/revenue-series');
    final w = revenueWindow(RevenueRange.month, now);
    expect(req.uri.queryParameters, {
      'range': 'month',
      'from': '${w.from}',
      'to': '${w.to}',
      'prev_from': '${w.prevFrom}',
      'prev_to': '${w.prevTo}',
      'now': '${w.now}',
    });
    expect(s!.target, 150);
    expect(s.headline, 150);
    expect(s.targetRatio, 1);
    expect(s.slots, 31);
  });

  test('range gửi đúng tên week/year', () async {
    for (final r in [RevenueRange.week, RevenueRange.year]) {
      final adapter = FakeAdapter(
        200,
        envelope({'current': <num>[], 'previous': <num>[], 'target': null}),
      );
      await apiWith(adapter).revenueSeries(r, now: now);
      expect(adapter.requests.single.uri.queryParameters['range'], r.name);
    }
  });

  test('target null → targetRatio null', () async {
    final adapter = FakeAdapter(
      200,
      envelope({
        'bucket': 'day',
        'current': [5],
        'previous': <num>[],
        'target': null,
        'currency': 'VND',
      }),
    );
    final s = await apiWith(adapter).revenueSeries(RevenueRange.week, now: now);
    expect(s!.targetRatio, isNull);
  });

  final noSource = <(String, int, Map<String, dynamic>)>[
    ('403', 403, {'success': false, 'message': 'Không có quyền'}),
    ('404', 404, {'success': false, 'message': 'Không tìm thấy'}),
    (
      'feature_disabled',
      403,
      {
        'success': false,
        'message': 'Tắt',
        'code': 'FEATURE_DISABLED',
        'error_code': 'FEATURE_DISABLED',
        'feature': 'crm_overview',
      },
    ),
  ];
  for (final (name, status, body) in noSource) {
    test('$name → null, không ném', () async {
      final adapter = FakeAdapter(status, jsonEncode(body));
      final s = await apiWith(
        adapter,
      ).revenueSeries(RevenueRange.month, now: now);
      expect(s, isNull);
    });
  }

  test('500 → ném', () async {
    final adapter = FakeAdapter(500, jsonEncode({'success': false}));
    await expectLater(
      apiWith(adapter).revenueSeries(RevenueRange.month, now: now),
      throwsA(isA<AppException>()),
    );
  });
}
