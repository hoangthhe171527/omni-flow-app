import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_envelope.dart';
import '../../../security/session/session_controller.dart';
import '../../inbox/application/inbox_realtime.dart';
import '../../inbox/data/inbox_api.dart';
import '../../inbox/domain/conversation.dart';
import '../../inbox/domain/inbox_permissions.dart';
import '../../tasks/domain/task_permissions.dart';
import '../../tasks/data/tasks_api.dart';
import '../../tasks/domain/task.dart';
import '../data/dashboard_api.dart';
import '../domain/dashboard_permissions.dart';
import '../domain/revenue_period.dart';
import '../domain/revenue_series.dart';

/// Thẻ nào của Tổng quan được dựng: đủ quyền **và** cờ tính năng của tenant
/// còn bật (tên cờ khớp middleware `feature:` của server — `crm_overview` cho
/// `/sales-overview/*`, `tasks` cho `/tasks`, `inbox` cho `/inbox`). Thẻ ẩn thì
/// provider dữ liệu của nó không bị watch → không gọi mạng.
class DashboardCards {
  const DashboardCards({
    required this.revenue,
    required this.tasks,
    required this.inbox,
  });

  final bool revenue;
  final bool tasks;
  final bool inbox;

  bool get none => !revenue && !tasks && !inbox;
}

final dashboardCardsProvider = Provider<DashboardCards>((ref) {
  final session = ref.watch(sessionProvider);
  final access = ref.watch(accessProvider);
  return DashboardCards(
    revenue:
        access.canAny(DashboardPermissions.revenue) &&
        session.featureEnabled('crm_overview'),
    tasks:
        access.canAny(TaskPermissions.anyRead) &&
        session.featureEnabled('tasks'),
    inbox:
        access.canAny(InboxPermissions.anyRead) &&
        session.featureEnabled('inbox'),
  );
});

final revenueRangeProvider = StateProvider<RevenueRange>(
  (_) => RevenueRange.month,
);

/// `null` = không có nguồn (thiếu quyền: không gọi mạng; hoặc server 403/404).
final revenueSeriesProvider = FutureProvider.autoDispose<RevenueSeries?>((
  ref,
) async {
  if (!ref.watch(dashboardCardsProvider).revenue) return null;
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
