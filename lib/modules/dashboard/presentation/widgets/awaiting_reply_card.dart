/// Thẻ "Chờ phản hồi" trên Tổng quan: ≤5 hội thoại mở còn tin chưa đọc.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:omni_app/design/components/components.dart';

import '../../../inbox/application/inbox_providers.dart';
import '../../../inbox/domain/conversation.dart';
import '../../../inbox/domain/inbox_filter.dart';
import '../../../inbox/inbox.dart' show ConversationRow;
import '../../../inbox/inbox_routes.dart';
import '../../application/dashboard_providers.dart';
import 'dashboard_card_parts.dart';

class AwaitingReplyCard extends ConsumerWidget {
  const AwaitingReplyCard({super.key});

  static const limit = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Thiếu quyền hộp thư hoặc cờ `inbox` tắt → thẻ không tồn tại, không gọi
    // mạng.
    if (!ref.watch(dashboardCardsProvider).inbox) {
      return const SizedBox.shrink();
    }
    final async = ref.watch(dashboardAwaitingReplyProvider);
    final page = async.valueOrNull;
    final items = page?.items.take(limit).toList() ?? const <Conversation>[];

    final Widget body;
    if (async.hasError && !async.isLoading) {
      body = DashboardCardError(
        error: async.error!,
        onRetry: () => ref.invalidate(dashboardAwaitingReplyProvider),
      );
    } else if (page == null) {
      body = const DashboardCardSkeleton();
    } else if (items.isEmpty) {
      body = const DashboardEmptyLine('Đã trả lời hết');
    } else {
      body = Column(
        children: [
          for (final c in items)
            ConversationRow(
              conversation: c,
              onTap: () => context.pushNamed(
                InboxRoutes.thread,
                pathParameters: {'id': c.id},
              ),
            ),
        ],
      );
    }

    return OmniCollapsibleCard(
      title: 'Chờ phản hồi',
      storageKey: 'dashboard.awaiting',
      // Con trỏ không có tổng: chỉ đếm được khi đã thấy hết.
      count: page == null || page.hasMore ? null : page.items.length,
      footer: items.isEmpty
          ? null
          : DashboardSeeAll(
              onPressed: () {
                // Bắt container trước khi `go`: sau khi chuyển màn, thẻ này
                // có thể đã bị tháo và `ref` không còn dùng được.
                final container = ProviderScope.containerOf(
                  context,
                  listen: false,
                );
                container
                    .read(inboxFilterProvider.notifier)
                    .setQuick(InboxQuickFilter.unread);
                context.goNamed(InboxRoutes.list);
              },
            ),
      child: body,
    );
  }
}
