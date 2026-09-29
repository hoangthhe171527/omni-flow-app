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
    final scheme = Theme.of(context).colorScheme;
    // Holds the socket open for as long as this screen is mounted. The screen
    // owns the subscription, not the controller: fetching a list should not be
    // what opens a connection.
    ref.watch(notificationRealtimeProvider);
    final notifications = ref.watch(notificationsProvider);
    // Đếm ở server, qua mọi trang — không phải số dòng chưa đọc đang trên màn.
    final unread = ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: OmniAppBar(
        backgroundColor: scheme.surface,
        title: 'Thông báo',
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
                Divider(height: 1, color: scheme.outlineVariant),
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
    final scheme = Theme.of(context).colorScheme;
    final unread = notification.isUnread;

    return Material(
      // Unread is carried by weight and a dot as well as by the tint, so it
      // survives both dim workshop light and colour-blindness.
      color: unread ? scheme.primary.withValues(alpha: 0.05) : scheme.surface,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                        style: OmniType.bodyStrong.copyWith(
                          fontWeight: unread
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: OmniSpacing.xxs),
                      Text(
                        notification.body,
                        style: OmniType.body.copyWith(
                          height: 20 / 14,
                          color: unread
                              ? OmniColors.byBrightness(
                                  context,
                                  OmniColors.secondaryForeground,
                                  scheme.onSurfaceVariant,
                                )
                              : scheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (notification.createdAt != null) ...[
                        const SizedBox(height: OmniSpacing.xs),
                        Text(
                          Formatters.relative(notification.createdAt),
                          style: OmniType.micro.copyWith(
                            color: scheme.onSurfaceVariant,
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
                    decoration: BoxDecoration(
                      color: scheme.primary,
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
    // Ô icon bo 12 tô theo giọng Orbit (`MNotifications.dc.html`): trễ hạn
    // đỏ, sắp tới hạn vàng, được giao / tiến độ xanh dương, còn lại mòng két.
    final (icon, tone) = switch (kind) {
      NotificationKind.taskAssigned => (
        Icons.assignment_ind_outlined,
        OmniTone.info,
      ),
      NotificationKind.taskStageOpen => (
        Icons.pan_tool_alt_outlined,
        OmniTone.info,
      ),
      NotificationKind.taskProgress => (Icons.timeline_rounded, OmniTone.info),
      NotificationKind.taskCompleted => (
        Icons.check_circle_outline_rounded,
        OmniTone.success,
      ),
      NotificationKind.taskOverdue => (
        Icons.warning_amber_rounded,
        OmniTone.danger,
      ),
      NotificationKind.taskDueSoon => (
        Icons.schedule_rounded,
        OmniTone.warning,
      ),
      NotificationKind.taskCommented || NotificationKind.taskMentioned => (
        Icons.chat_bubble_outline_rounded,
        OmniTone.success,
      ),
      NotificationKind.inboxMessage => (Icons.forum_outlined, OmniTone.info),
      NotificationKind.other => (
        Icons.notifications_none_rounded,
        OmniTone.neutral,
      ),
    };
    final (foreground, background) = tone.of(context);

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: background,
        borderRadius: OmniRadius.mdAll,
      ),
      child: Icon(icon, size: OmniIconSize.lg, color: foreground),
    );
  }
}
