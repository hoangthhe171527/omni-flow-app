import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../domain/revenue_period.dart';
import '../domain/revenue_series.dart';

class DashboardApi {
  DashboardApi(this._client);

  final ApiClient _client;

  /// `GET /sales-overview/revenue-series` (omni-flow-api
  /// `SalesOverviewController::revenueSeries`). Trả `null` khi không có nguồn:
  /// 403 (thiếu quyền hoặc module `crm_overview` tắt — FEATURE_DISABLED cũng là
  /// 403) và 404 (server chưa có route). Lỗi khác ném để thẻ hiện "thử lại".
  Future<RevenueSeries?> revenueSeries(RevenueRange r, {DateTime? now}) async {
    final w = revenueWindow(r, (now ?? DateTime.now()).toUtc());
    try {
      final response = await _client.get(
        '/sales-overview/revenue-series',
        query: {
          'range': r.name,
          'from': w.from,
          'to': w.to,
          'prev_from': w.prevFrom,
          'prev_to': w.prevTo,
          'now': w.now,
        },
      );
      return RevenueSeries.fromJson(response.object, r, w.slots);
    } on ForbiddenException {
      return null;
    } on NotFoundException {
      return null;
    }
  }
}

final dashboardApiProvider = Provider<DashboardApi>((ref) {
  return DashboardApi(ref.watch(apiClientProvider));
});
