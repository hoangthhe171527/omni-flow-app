import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_envelope.dart';
import '../../../security/session/session_controller.dart';
import '../../inbox/application/inbox_realtime.dart';
import '../../inbox/data/inbox_api.dart';
import '../../inbox/domain/conversation.dart';
import '../../tasks/data/tasks_api.dart';
import '../../tasks/domain/task.dart';
import '../data/dashboard_api.dart';
import '../domain/dashboard_permissions.dart';
import '../domain/revenue_period.dart';
import '../domain/revenue_series.dart';

final revenueRangeProvider = StateProvider<RevenueRange>(
  (_) => RevenueRange.month,
);

/// `null` = không có nguồn (thiếu quyền: không gọi mạng; hoặc server 403/404).
final revenueSeriesProvider = FutureProvider.autoDispose<RevenueSeries?>((
  ref,
) async {
  final access = ref.watch(accessProvider);
  if (!access.canAny(DashboardPermissions.revenue)) return null;
  final range = ref.watch(revenueRangeProvider);
  return ref.watch(dashboardApiProvider).revenueSeries(range);
});

final dashboardMyTasksProvider = FutureProvider.autoDispose<Paged<Task>>((ref) {
  return ref.watch(tasksApiProvider).mine(bucket: TaskBucket.today, perPage: 5);
});

final dashboardAwaitingReplyProvider =
    FutureProvider.autoDispose<CursorPaged<Conversation>>((ref) {
      ref.watch(inboxRealtimeSignalProvider);
      return ref
          .watch(inboxApiProvider)
          .list(query: const {'status': 'open', 'unread': 1}, perPage: 5);
    });
