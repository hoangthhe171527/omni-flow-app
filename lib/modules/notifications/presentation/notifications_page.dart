import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../application/notifications_providers.dart';
import '../domain/app_notification.dart';

/// The bell.
///
/// One list, newest first, unread marked. No filters and no tabs: a workshop
/// notification is either something to act on or something already handled, and
/// a tab bar over twenty rows is furniture, not navigation.
class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key, this.onOpenTask});

  /// Where a task notification goes when tapped. Injected rather than imported
  /// so this screen does not depend on the tasks module's router.
  final void Function(String taskId)? onOpenTask;

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 400) {
      ref.read(notificationsProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Holds the socket open for as long as this screen is mounted. The screen
    // owns the subscription, not the controller: fetching a list should not be
    // what opens a connection.
    ref.watch(notificationRealtimeProvider);
    final notifications = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      backgroundColor: OmniColors.background,
      appBar: AppBar(
        title: const Text('Thông báo'),
        toolbarHeight: 56,
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () =>
                  ref.read(notificationsProvider.notifier).markAllRead(),
              child: const Text('Đọc hết'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(notificationsProvider.notifier).refresh(),
        child: OmniAsyncView(
          value: notifications,
          onRetry: () => ref.invalidate(notificationsProvider),
          isEmpty: (state) => state.items.isEmpty,
          empty: const OmniEmptyState(
            icon: Icons.notifications_none_rounded,
            title: 'Chưa có thông báo',
            message:
                'Khi có việc được giao hoặc hoàn thành, bạn sẽ thấy ở đây.',
          ),
          data: (state) => ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.only(bottom: OmniSpacing.bottomSafe),
            itemCount: state.items.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, color: OmniColors.border),
            itemBuilder: (context, index) {
              final notification = state.items[index];

              return NotificationRow(
                notification: notification,
                onTap: () => _open(notification),
              );
            },
          ),
        ),
      ),
    );
  }

  void _open(AppNotification notification) {
    ref.read(notificationsProvider.notifier).markRead(notification.id);

    final taskId = notification.taskId;
    // A row this build cannot route is still worth reading and still marks
    // itself read — it just does not navigate. Better than a dead end on a
    // screen that does not exist.
    if (taskId != null) widget.onOpenTask?.call(taskId);
  }
}

/// One notification.
///
/// The whole row is the target at 72dp; the unread dot is an indicator, never
/// something to aim at.
class NotificationRow extends StatelessWidget {
  const NotificationRow({
    super.key,
    required this.notification,
    required this.onTap,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = notification.isUnread;

    return Material(
      // Unread is carried by weight and a dot as well as by the tint, so it
      // survives both dim workshop light and colour-blindness.
      color: unread ? OmniColors.accent : OmniColors.card,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.all(OmniSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _KindIcon(kind: notification.kind),
                const SizedBox(width: OmniSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: unread
                            ? OmniType.bodyStrong
                            : OmniType.body.copyWith(
                                color: OmniColors.secondaryForeground,
                              ),
                      ),
                      const SizedBox(height: OmniSpacing.xxs),
                      Text(
                        notification.body,
                        style: OmniType.caption.copyWith(
                          color: OmniColors.mutedForeground,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (notification.createdAt != null) ...[
                        const SizedBox(height: OmniSpacing.xs),
                        Text(
                          Formatters.relative(notification.createdAt),
                          style: OmniType.micro.copyWith(
                            color: OmniColors.mutedForeground,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (unread) ...[
                  const SizedBox(width: OmniSpacing.sm),
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: OmniSpacing.xs),
                    decoration: const BoxDecoration(
                      color: OmniColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A glyph per kind, so the list can be read by shape before it is read by
/// words. Never an emoji: they render differently on every Android skin.
class _KindIcon extends StatelessWidget {
  const _KindIcon({required this.kind});

  final NotificationKind kind;

  @override
  Widget build(BuildContext context) {
    final (icon, colour) = switch (kind) {
      NotificationKind.taskAssigned => (
        Icons.assignment_ind_outlined,
        OmniColors.primary,
      ),
      NotificationKind.taskStageOpen => (
        Icons.pan_tool_alt_outlined,
        OmniColors.info,
      ),
      NotificationKind.taskProgress => (
        Icons.timeline_rounded,
        OmniColors.info,
      ),
      NotificationKind.taskCompleted => (
        Icons.check_circle_outline_rounded,
        OmniColors.success,
      ),
      NotificationKind.taskOverdue => (
        Icons.warning_amber_rounded,
        OmniColors.destructive,
      ),
      NotificationKind.taskDueSoon => (
        Icons.schedule_rounded,
        OmniColors.warning,
      ),
      NotificationKind.taskCommented || NotificationKind.taskMentioned => (
        Icons.chat_bubble_outline_rounded,
        OmniColors.primary,
      ),
      NotificationKind.inboxMessage => (
        Icons.forum_outlined,
        OmniColors.primary,
      ),
      NotificationKind.other => (
        Icons.notifications_none_rounded,
        OmniColors.mutedForeground,
      ),
    };

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(OmniRadius.md),
      ),
      child: Icon(icon, size: 20, color: colour),
    );
  }
}
