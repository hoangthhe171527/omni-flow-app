import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// Người dùng đã cuộn: các dòng dựng sau đó hiện ngay, không chạy hiệu ứng
  /// hiện dần (khối cũ chỉ hiện dần một lần lúc mở màn).
  bool _entered = false;

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
    _entered = true;
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
    // Đếm ở server, qua mọi trang — không phải số dòng đang trên màn. Null =
    // chưa về: thanh chọn không kèm số, thay vì "· 0" như thể đã đọc hết.
    final unreadCount = ref.watch(unreadNotificationCountProvider).valueOrNull;
    final unread = unreadCount ?? 0;

    return Scaffold(
      // Nền xám để các thẻ nhóm lồng nổi lên.
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // Thanh trên kiểu B (viomni-apple-uiux.html "Thông báo"): tiêu đề lớn,
      // "Đọc hết" là viên kính chữ; không chuông — đang ở chính trang này.
      extendBodyBehindAppBar: true,
      appBar: OmniTopBar(
        semanticsTitle: 'Thông báo',
        allowBack: true,
        // Mở từ "Xem tất cả" của bảng chuông: kiểu màn con — ‹ · Thông báo ·
        // Đọc hết, không logo, không avatar (rà soát 12/11). Là tab gốc (Bàn
        // làm việc) thì vẫn kiểu màn gốc.
        onBack: ModalRoute.of(context)?.canPop ?? false
            ? () => Navigator.of(context).maybePop()
            : null,
        showBell: false,
        actions: [
          OmniGlass(
            radius: 22,
            child: SizedBox(
              height: 44,
              child: TextButton(
                onPressed: unread > 0
                    ? () {
                        HapticFeedback.selectionClick();
                        ref.read(notificationsProvider.notifier).markAllRead();
                      }
                    : null,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  'Đọc hết',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: unread > 0 ? scheme.primary : null,
                  ),
                ),
              ),
            ),
          ),
        ],
        searchBottom: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: OmniSegmented(
            labels: [
              'Tất cả',
              unreadCount == null ? 'Chưa đọc' : 'Chưa đọc · $unreadCount',
            ],
            index: unreadOnly ? 1 : 0,
            onChanged: (i) =>
                ref.read(notificationUnreadOnlyProvider.notifier).state =
                    i == 1,
          ),
        ),
      ),
      body: OmniTopBarOverlap.wrap(
        child: Builder(
          builder: (context) => RefreshIndicator.adaptive(
            edgeOffset: OmniTopBarOverlap.of(context),
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

                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  controller: _scrollController,
                  padding: EdgeInsets.fromLTRB(
                    16,
                    OmniTopBarOverlap.of(context) + 4,
                    16,
                    OmniSpacing.bottomSafe,
                  ),
                  itemCount: groups.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: OmniGroupSection.gap),
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    final section = OmniGroupSection(
                      key: ValueKey('notification-group-${group.label}'),
                      title: group.label,
                      dividerIndent: 54,
                      children: [
                        for (final item in group.items)
                          NotificationRow(
                            notification: item,
                            onTap: () => _open(item),
                          ),
                      ],
                    );
                    // Hiện dần chỉ ở lượt mở đầu; nhóm cuộn tới sau thì hiện ngay.
                    return _entered ? section : _Rise(child: section);
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _open(AppNotification notification) {
    HapticFeedback.selectionClick();
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
      padding: EdgeInsets.only(top: 60 + OmniTopBarOverlap.of(context)),
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
  const _Rise({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Bậc hiệu năng thấp: hiện ngay (mỗi mục hiện dần = một lớp vẽ mờ).
    if (!OmniMotion.enabled(context) ||
        !OmniPerformance.riseOnScroll(context)) {
      return child;
    }

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

/// Một thông báo trong [OmniGroupSection]. Cả dòng là đích chạm; chấm chưa đọc
/// tròn 8×8 màu chính ở lề trái, ô icon [OmniIconTile] 28×28 bo 8 một tông.
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
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Stack(
              children: [
                if (unread)
                  Positioned(
                    left: 3,
                    top: 20,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                Padding(
                  // 14 + 28 (OmniIconTile) + 12 = 54, khớp `dividerIndent: 54`.
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OmniIconTile(
                        _iconForKind(notification.kind),
                        color: scheme.primary,
                        background: scheme.primary.withValues(alpha: .10),
                      ),
                      const SizedBox(width: 12),
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

IconData _iconForKind(NotificationKind kind) => switch (kind) {
  NotificationKind.inboxMessage => Icons.chat_bubble_outline_rounded,
  NotificationKind.taskAssigned => Icons.assignment_ind_outlined,
  NotificationKind.taskCreated => Icons.add_task_rounded,
  NotificationKind.taskStageOpen => Icons.pan_tool_alt_outlined,
  NotificationKind.taskIssue => Icons.report_problem_outlined,
  NotificationKind.taskProgress => Icons.timeline_rounded,
  NotificationKind.taskCompleted => Icons.check_circle_outline_rounded,
  NotificationKind.taskCommented ||
  NotificationKind.taskMentioned => Icons.chat_bubble_outline_rounded,
  NotificationKind.taskDueSoon => Icons.schedule_rounded,
  NotificationKind.taskReminder => Icons.alarm_rounded,
  NotificationKind.taskOverdue => Icons.warning_amber_rounded,
  NotificationKind.other => Icons.notifications_none_rounded,
};
