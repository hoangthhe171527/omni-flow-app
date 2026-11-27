import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../../hr/hr.dart';
import '../application/dashboard_providers.dart';
import 'widgets/awaiting_reply_card.dart';
import 'widgets/my_tasks_card.dart';
import 'widgets/revenue_card.dart';

/// Màn Tổng quan (MainV2): header tên màn lớn + chuông + tài khoản (không
/// ngày, chi nhánh, ô tìm), rồi thẻ doanh thu, Việc của tôi, Chờ phản hồi.
/// Mỗi thẻ tự ẩn khi thiếu quyền. Không có hàng "Cần chú ý".
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  static const emptyMessage = 'Chưa có mục nào để hiển thị ở Tổng quan';

  Future<void> _refresh(WidgetRef ref) {
    final cards = ref.read(dashboardCardsProvider);
    refreshHrHomeCard(ref);
    ref
      ..invalidate(revenueSeriesProvider)
      ..invalidate(dashboardMyTasksProvider)
      ..invalidate(dashboardAwaitingReplyProvider);
    // Chỉ chờ nguồn được phép: đọc `.future` của nguồn không có thẻ sẽ gọi
    // mạng thay cho người không có quyền.
    Future<void> settle(Future<Object?> f) => f.then((_) {}, onError: (_) {});
    return Future.wait([
      if (cards.revenue) settle(ref.read(revenueSeriesProvider.future)),
      if (cards.tasks) settle(ref.read(dashboardMyTasksProvider.future)),
      if (cards.inbox) settle(ref.read(dashboardAwaitingReplyProvider.future)),
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mọi thẻ đều ẩn (thiếu quyền / cờ tắt, hoặc server từ chối doanh thu →
    // provider trả null) → báo trống thay cho trang trắng. Chỉ watch doanh
    // thu khi thẻ được phép, để không gọi mạng thay người không có quyền.
    final cards = ref.watch(dashboardCardsProvider);
    var revenueVisible = cards.revenue;
    if (revenueVisible) {
      final rev = ref.watch(revenueSeriesProvider);
      revenueVisible = !(rev.hasValue && rev.value == null && !rev.isLoading);
    }
    final hr = ref.watch(hrAccessProvider);
    final hrCard = hr.clock || hr.workshop;
    final none = !hrCard && !revenueVisible && !cards.tasks && !cards.inbox;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const OmniTopBar(semanticsTitle: 'Tổng quan'),
      body: OmniTopBarOverlap.wrap(
        child: Builder(
          builder: (context) {
            final topInset = OmniTopBarOverlap.of(context);
            return RefreshIndicator.adaptive(
              edgeOffset: topInset,
              onRefresh: () => _refresh(ref),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: OmniSpacing.screen.copyWith(
                  top: topInset,
                  bottom: OmniSpacing.bottomSafe,
                ),
                children: none
                    ? const [
                        OmniEmptyState(
                          icon: LucideIcons.layoutDashboard,
                          title: emptyMessage,
                        ),
                      ]
                    : const [
                        // Thẻ chấm công / xưởng hôm nay đứng đầu (nhan-su-kpi/03 §5.1).
                        HrHomeCard(),
                        RevenueCard(),
                        MyTasksCard(),
                        AwaitingReplyCard(),
                      ],
              ),
            );
          },
        ),
      ),
    );
  }
}
