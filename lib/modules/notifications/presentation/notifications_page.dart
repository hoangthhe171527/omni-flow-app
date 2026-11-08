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
                // Phẳng: tiêu đề nhóm + từng dòng là một mục của builder, nên mỗi
                // lần "tải thêm" chỉ dựng các dòng đang hiện, không dựng lại cả
                // khối nhóm. Trông y hệt khối cũ (nhóm không có khung bo).
                final entries = <_Entry>[
                  for (final group in groups) ...[
                    _Entry.header(group.label),
                    for (var i = 0; i < group.items.length; i++)
                      _Entry.row(
                        group.label,
                        group.items[i],
                        divider: i > 0,
                        lastInGroup: i == group.items.length - 1,
                      ),
                  ],
                ];

                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  controller: _scrollController,
                  padding: EdgeInsets.fromLTRB(
                    16,
                    14 + OmniTopBarOverlap.of(context),
                    16,
                    OmniSpacing.bottomSafe,
                  ),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final child = entry.notification == null
                        ? _GroupHeader(label: entry.label)
                        : _GroupRow(
                            label: entry.label,
                            notification: entry.notification!,
                            divider: entry.divider,
                            lastInGroup: entry.lastInGroup,
                            onOpen: _open,
                          );
                    // Hiện dần chỉ ở lượt mở đầu; dòng cuộn tới sau thì hiện ngay.
                    return _entered ? child : _Rise(child: child);
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

/// Một mục của danh sách phẳng: tiêu đề nhóm ([notification] null) hoặc một dòng.
class _Entry {
  const _Entry.header(this.label)
    : notification = null,
      divider = false,
      lastInGroup = false;

  const _Entry.row(
    this.label,
    AppNotification this.notification, {
    required this.divider,
    required this.lastInGroup,
  });

  final String label;
  final AppNotification? notification;
  final bool divider;
  final bool lastInGroup;
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
      child: Semantics(
        header: true,
        child: Text(
          label,
          style: OmniType.overline.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Một dòng của nhóm: vạch trên (trừ dòng đầu) + dòng thông báo; dòng cuối nhóm
/// chừa 16px như khối nhóm cũ. Dòng đầu mang khoá `notification-group-<nhãn>`.
class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.label,
    required this.notification,
    required this.divider,
    required this.lastInGroup,
    required this.onOpen,
  });

  final String label;
  final AppNotification notification;
  final bool divider;
  final bool lastInGroup;
  final void Function(AppNotification) onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Nhóm lồng (viomni-apple-uiux.html `.group`): mỗi ngày là một thẻ bo 18
    // trên nền xám — dòng đầu bo trên, dòng cuối bo dưới.
    const r = Radius.circular(18);
    return Padding(
      padding: EdgeInsets.only(bottom: lastInGroup ? 16 : 0),
      child: Material(
        key: divider ? null : ValueKey('notification-group-$label'),
        color: scheme.surface,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.vertical(
          top: divider ? Radius.zero : r,
          bottom: lastInGroup ? r : Radius.zero,
        ),
        child: Column(
          children: [
            if (divider)
              // Vạch chia thụt sau icon (18 + 32 + 10), không chạy full ngang.
              Divider(
                height: 1,
                thickness: 1,
                indent: 60,
                color: scheme.outlineVariant.withValues(alpha: .7),
              ),
            NotificationRow(
              notification: notification,
              onTap: () => onOpen(notification),
            ),
          ],
        ),
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
        // Chưa đọc = chấm màu chính ở lề trái + tiêu đề đậm; không tô nền
        // xanh phẳng (đợt 3 liquid).
        color: scheme.surface,
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
      NotificationKind.taskReminder => (Icons.alarm_rounded, OmniHue.orange),
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
