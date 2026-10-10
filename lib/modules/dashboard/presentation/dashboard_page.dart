import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../../../security/session/session_controller.dart';
import '../../inbox/domain/inbox_permissions.dart';
import '../../tasks/domain/task_permissions.dart';
import '../application/dashboard_providers.dart';
import '../domain/dashboard_permissions.dart';
import 'widgets/awaiting_reply_card.dart';
import 'widgets/my_tasks_card.dart';
import 'widgets/revenue_card.dart';

/// Màn Tổng quan (MainV2): header chỉ logo + chuông + tài khoản (không tiêu
/// đề, ngày, chi nhánh, ô tìm), rồi thẻ doanh thu, Việc của tôi, Chờ phản hồi.
/// Mỗi thẻ tự ẩn khi thiếu quyền. Không có hàng "Cần chú ý".
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  Future<void> _refresh(WidgetRef ref) {
    final access = ref.read(accessProvider);
    ref
      ..invalidate(revenueSeriesProvider)
      ..invalidate(dashboardMyTasksProvider)
      ..invalidate(dashboardAwaitingReplyProvider);
    // Chỉ chờ nguồn được phép: đọc `.future` của nguồn không có thẻ sẽ gọi
    // mạng thay cho người không có quyền.
    Future<void> settle(Future<Object?> f) => f.then((_) {}, onError: (_) {});
    return Future.wait([
      if (access.canAny(DashboardPermissions.revenue))
        settle(ref.read(revenueSeriesProvider.future)),
      if (access.canAny(TaskPermissions.anyRead))
        settle(ref.read(dashboardMyTasksProvider.future)),
      if (access.canAny(InboxPermissions.anyRead))
        settle(ref.read(dashboardAwaitingReplyProvider.future)),
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: const OmniTopBar(semanticsTitle: 'Tổng quan'),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            OmniSpacing.lg,
            12,
            OmniSpacing.lg,
            OmniSpacing.bottomSafe,
          ),
          children: const [
            RevenueCard(),
            _Gap(),
            MyTasksCard(),
            _Gap(),
            AwaitingReplyCard(),
          ],
        ),
      ),
    );
  }
}

class _Gap extends StatelessWidget {
  const _Gap();

  @override
  Widget build(BuildContext context) => const SizedBox(height: 12);
}
