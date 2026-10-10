import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../design/components/components.dart';
import '../../../design/platform/omni_motion_scope.dart';
import '../../../design/tokens/tokens.dart';
import '../application/notifications_providers.dart';
import '../domain/app_notification.dart';

/// Chuông (`Notifications.dc.html`).
///
/// Một danh sách, mới nhất trước, nhóm "Hôm nay" / "Trước đó" theo ngày VN.
/// Thanh chọn "Tất cả / Chưa đọc · N" lọc ở server; N cũng đếm ở server.
class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({
    super.key,
    this.onOpenTask,
    this.onOpenConversation,
  });

  /// Nơi một thông báo việc dẫn tới. Truyền vào thay vì import, để màn này
  /// không phụ thuộc router của module việc.
  final void Function(String taskId)? onOpenTask;

  /// Nơi thông báo tin nhắn dẫn tới (hội thoại trong hộp thư).
  final void Function(String conversationId)? onOpenConversation;

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
    // Giữ socket mở suốt thời gian màn này còn đó.
    ref.watch(notificationRealtimeProvider);
    final notifications = ref.watch(notificationsProvider);
    final unreadOnly = ref.watch(notificationUnreadOnlyProvider);
    // Đếm ở server, qua mọi trang — không phải số dòng đang trên màn.
    final unread = ref.watch(unreadNotificationBadgeProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: OmniAppBar(
        backgroundColor: scheme.surface,
        title: 'Thông báo',
        centerTitle: true,
        showAccount: false,
        actions: [
          TextButton(
            onPressed: unread > 0
                ? () => ref.read(notificationsProvider.notifier).markAllRead()
                : null,
            child: Text(
              'Đọc hết',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: unread > 0 ? scheme.primary : null,
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(54),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: OmniSegmented(
              labels: ['Tất cả', 'Chưa đọc · $unread'],
              index: unreadOnly ? 1 : 0,
              onChanged: (i) =>
                  ref.read(notificationUnreadOnlyProvider.notifier).state =
                      i == 1,
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(notificationsProvider.notifier).refresh(),
        child: OmniAsyncView(
          value: notifications,
          onRetry: () => ref.invalidate(notificationsProvider),
          isEmpty: (state) => state.items.isEmpty,
          empty: unreadOnly
              ? const _AllReadEmpty()
              : const OmniEmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: 'Chưa có thông báo',
                  message:
                      'Khi có việc được giao hoặc hoàn thành, bạn sẽ thấy ở đây.',
                ),
          data: (state) {
            final groups = groupNotificationsByDay(state.items);

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(
                16,
                14,
                16,
                OmniSpacing.bottomSafe,
              ),
              children: [
                for (final group in groups)
                  _Rise(
                    key: ValueKey(group.label),
                    child: _GroupBlock(
                      label: group.label,
                      items: group.items,
                      onOpen: _open,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _open(AppNotification notification) {
    ref.read(notificationsProvider.notifier).markRead(notification.id);

    // Dòng không định tuyến được vẫn đánh dấu đã đọc, chỉ không điều hướng.
    final taskId = notification.taskId;
    if (taskId != null) {
      widget.onOpenTask?.call(taskId);
      return;
    }
    final conversationId = notification.conversationId;
    if (conversationId != null) {
      widget.onOpenConversation?.call(conversationId);
    }
  }
}

class _AllReadEmpty extends StatelessWidget {
  const _AllReadEmpty();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 60),
      children: [
        Center(
          child: Text(
            'Bạn đã đọc hết thông báo',
            style: OmniType.body.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// `rise`: hiện dần và trượt lên 10px trong 450ms. Tắt khi giảm chuyển động.
class _Rise extends StatelessWidget {
  const _Rise({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!OmniMotion.enabled(context)) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: OmniCurves.standard,
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - t)),
          child: child,
        ),
      ),
    );
  }
}

class _GroupBlock extends StatelessWidget {
  const _GroupBlock({
    required this.label,
    required this.items,
    required this.onOpen,
  });

  final String label;
  final List<AppNotification> items;
  final void Function(AppNotification) onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
            child: Semantics(
              header: true,
              child: Text(
                label,
                style: OmniType.overline.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: scheme.surfaceContainerHighest,
                      ),
                    NotificationRow(
                      notification: items[i],
                      onTap: () => onOpen(items[i]),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Một thông báo. Cả dòng là đích chạm; chấm chưa đọc chỉ là chỉ báo.
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

    return Semantics(
      button: true,
      label: [
        if (unread) 'Chưa đọc',
        notification.title,
        if (notification.body.isNotEmpty) notification.body,
      ].join(', '),
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: unread
            ? OmniColors.byBrightness(
                context,
                OmniColors.unreadRow,
                scheme.primary.withValues(alpha: 0.08),
              )
            : scheme.surface,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Stack(
              children: [
                if (unread)
                  Positioned(
                    left: 7,
                    top: 22,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 12, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _KindIcon(kind: notification.kind),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notification.title,
                              style: OmniType.body.copyWith(
                                fontWeight: unread
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: OmniSpacing.xxs),
                            Text(
                              notification.body,
                              style: OmniType.body.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (notification.createdAt != null) ...[
                        const SizedBox(width: OmniSpacing.sm),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hình theo loại, màu theo sắc: tin nhắn teal, việc xanh, sắp hạn cam, trễ
/// hạn đỏ, còn lại trung tính.
class _KindIcon extends StatelessWidget {
  const _KindIcon({required this.kind});

  final NotificationKind kind;

  @override
  Widget build(BuildContext context) {
    final (icon, hue) = switch (kind) {
      NotificationKind.inboxMessage => (
        Icons.chat_bubble_outline_rounded,
        OmniHue.teal,
      ),
      NotificationKind.taskAssigned => (
        Icons.assignment_ind_outlined,
        OmniHue.blue,
      ),
      NotificationKind.taskStageOpen => (
        Icons.pan_tool_alt_outlined,
        OmniHue.blue,
      ),
      NotificationKind.taskProgress => (Icons.timeline_rounded, OmniHue.blue),
      NotificationKind.taskCompleted => (
        Icons.check_circle_outline_rounded,
        OmniHue.blue,
      ),
      NotificationKind.taskCommented || NotificationKind.taskMentioned => (
        Icons.chat_bubble_outline_rounded,
        OmniHue.blue,
      ),
      NotificationKind.taskDueSoon => (Icons.schedule_rounded, OmniHue.orange),
      NotificationKind.taskOverdue => (
        Icons.warning_amber_rounded,
        OmniHue.red,
      ),
      NotificationKind.other => (
        Icons.notifications_none_rounded,
        OmniHue.neutral,
      ),
    };
    final tone = OmniFeatureTones.of(context, hue);

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: OmniIconSize.lg, color: tone.foreground),
    );
  }
}
