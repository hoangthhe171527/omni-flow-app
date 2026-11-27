import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/utils/formatters.dart';
import '../../../design/components/components.dart';
import '../../../design/platform/omni_motion_scope.dart';
import '../../../design/tokens/tokens.dart';
import '../application/notifications_providers.dart';
import '../application/push_notifications.dart';
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
      // "Đọc hết" là nút chữ xanh trơn (spec phong cách iOS §3.2 bậc "Chữ" —
      // kính chỉ cho lớp điều hướng); không chuông — đang ở chính trang này.
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
          SizedBox(
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
        ],
        searchBottom: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: OmniSegmented(
            // Số đếm cạnh nhãn, không ghép vào chữ (spec phong cách iOS §3.4).
            labels: const ['Tất cả', 'Chưa đọc'],
            counts: [null, unreadCount],
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
                      icon: LucideIcons.bell,
                      title: 'Chưa có thông báo',
                      message:
                          'Khi có việc được giao hoặc hoàn thành, bạn sẽ thấy ở đây.',
                    ),
              data: (state) {
                final groups = groupNotificationsByDay(state.items);

                // Nhóm LƯỜI (rà soát kiến trúc 27/11/2026): "Trước đó" dài
                // dần theo từng trang tải thêm — chỉ dựng dòng trong tầm nhìn.
                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  controller: _scrollController,
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        OmniTopBarOverlap.of(context) + 4,
                        16,
                        OmniSpacing.bottomSafe,
                      ),
                      sliver: SliverMainAxisGroup(
                        slivers: [
                          for (var g = 0; g < groups.length; g++) ...[
                            if (g > 0)
                              const SliverToBoxAdapter(
                                child: SizedBox(height: OmniGroupSection.gap),
                              ),
                            // Hiện dần chỉ ở lượt mở đầu; nhóm cuộn tới sau
                            // thì hiện ngay.
                            _entered
                                ? OmniSliverGroup(
                                    key: ValueKey(
                                      'notification-group-${groups[g].label}',
                                    ),
                                    title: groups[g].label,
                                    dividerIndent: NotificationRow.textInset,
                                    itemCount: groups[g].items.length,
                                    itemBuilder: (context, i) {
                                      final item = groups[g].items[i];
                                      return NotificationRow(
                                        notification: item,
                                        onTap: () => _open(item),
                                      );
                                    },
                                  )
                                : _Rise(
                                    sliver: OmniSliverGroup(
                                      key: ValueKey(
                                        'notification-group-${groups[g].label}',
                                      ),
                                      title: groups[g].label,
                                      dividerIndent: NotificationRow.textInset,
                                      itemCount: groups[g].items.length,
                                      itemBuilder: (context, i) {
                                        final item = groups[g].items[i];
                                        return NotificationRow(
                                          notification: item,
                                          onTap: () => _open(item),
                                        );
                                      },
                                    ),
                                  ),
                          ],
                        ],
                      ),
                    ),
                  ],
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
    // Nhân sự (chấm công, đơn, phiếu lương…): mở qua đường của push.
    final hr = PushIntent.hrFromInApp(
      wireType: notification.wireType,
      entityId: notification.entityId,
    );
    if (hr != null) {
      ref.read(pushIntentProvider.notifier).state = hr;
      return;
    }

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
  const _Rise({required this.sliver});

  final Widget sliver;

  @override
  Widget build(BuildContext context) {
    // Bậc hiệu năng thấp: hiện ngay (mỗi nhóm hiện dần = một lớp vẽ mờ).
    if (!OmniMotion.enabled(context) ||
        !OmniPerformance.riseOnScroll(context)) {
      return sliver;
    }

    // Nhóm là sliver (lười) nên chỉ mờ dần, không dời lên như bản Column cũ.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: OmniCurves.standard,
      child: sliver,
      builder: (context, t, child) => SliverOpacity(opacity: t, sliver: child),
    );
  }
}

/// Một thông báo (duyệt 26/11/2026, rà soát mục 16–17) — dùng chung cho trang
/// Thông báo và bảng chuông. Chấm ĐỎ chưa đọc ở lề trái ([OmniUnreadDot]); ô
/// icon 38 bo 11 MÀU THEO LOẠI (đơn/tiền tím, việc xanh, chấm công cam, khác
/// xám); tiêu đề 15/600 + giờ bên phải; nội dung 13.5 xám tối đa 2 dòng. Đã
/// đọc: tiêu đề 500 chữ nhạt. Cả dòng là đích chạm.
class NotificationRow extends StatelessWidget {
  const NotificationRow({
    super.key,
    required this.notification,
    required this.onTap,
    this.borderRadius,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  /// Bo của vệt nhấn (dòng trong bảng chuông bo 16); null = theo thẻ nhóm.
  final BorderRadius? borderRadius;

  /// Lề trái tới chữ: 16 + ô icon 38 + 12 — `dividerIndent` của nhóm.
  static const double textInset = 66;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unread = notification.isUnread;
    final (tileFg, tileBg) = _tileColors(context, notification);

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
          borderRadius: borderRadius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 58),
            child: Stack(
              children: [
                if (unread)
                  const Positioned(
                    left: 4,
                    top: 25,
                    child: OmniUnreadDot(
                      size: 8,
                      ring: false,
                      excludeSemantics: true,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 14, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: tileBg,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          _iconFor(notification),
                          size: 20,
                          color: tileFg,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    notification.title,
                                    style: OmniType.body.copyWith(
                                      height: 1.3,
                                      fontWeight: unread
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: unread
                                          ? scheme.onSurface
                                          : scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                if (notification.createdAt != null) ...[
                                  const SizedBox(width: OmniSpacing.sm),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      Formatters.relative(
                                        notification.createdAt,
                                      ),
                                      style: OmniType.micro.copyWith(
                                        color: scheme.onSurfaceVariant,
                                        fontFeatures: OmniType.tabular,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (notification.body.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                notification.body,
                                style: OmniType.rowBody.copyWith(
                                  height: 1.35,
                                  color: scheme.onSurfaceVariant,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
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

/// Loại chấm công / tăng ca của Nhân sự (`notification_type` nguyên văn).
const _attendanceWires = {
  'ATTENDANCE_REMIND_IN',
  'ATTENDANCE_REMIND_OUT',
  'ATTENDANCE_MISSING',
  'OT_UNREGISTERED',
};

/// Sắc ô icon theo loại (duyệt 26/11/2026): đơn / tiền tím, việc xanh, chấm
/// công cam; null = xám (loại khác, tin nhắn, đơn từ…).
OmniHue? notificationHue(AppNotification n) {
  final wire = (n.wireType ?? n.kind.wire).toUpperCase();
  if (_attendanceWires.contains(wire)) return OmniHue.orange;
  if (wire == 'PAYSLIP_PUBLISHED' ||
      wire.contains('ORDER') ||
      wire.contains('PAYMENT') ||
      wire.contains('INVOICE') ||
      wire.contains('EXPENSE')) {
    return OmniHue.violet;
  }
  if (n.kind.isTask) return OmniHue.blue;
  return null;
}

/// (chữ, nền) của ô icon.
(Color, Color) _tileColors(BuildContext context, AppNotification n) {
  final theme = Theme.of(context);
  final hue = notificationHue(n);
  if (hue == null) {
    return (
      theme.colorScheme.onSurfaceVariant,
      theme.brightness == Brightness.dark
          ? OmniColors.darkMuted
          : OmniColors.muted,
    );
  }
  final tone = OmniFeatureTones.of(context, hue);
  return (tone.foreground, tone.background);
}

IconData _iconFor(AppNotification n) {
  final wire = (n.wireType ?? '').toUpperCase();
  if (_attendanceWires.contains(wire)) return LucideIcons.clock;
  if (wire == 'PAYSLIP_PUBLISHED') return LucideIcons.wallet;
  return _iconForKind(n.kind);
}

IconData _iconForKind(NotificationKind kind) => switch (kind) {
  NotificationKind.inboxMessage => LucideIcons.messageCircle,
  NotificationKind.taskAssigned => LucideIcons.contact,
  NotificationKind.taskCreated => LucideIcons.listPlus,
  NotificationKind.taskStageOpen => LucideIcons.pointer,
  NotificationKind.taskIssue => LucideIcons.triangleAlert,
  NotificationKind.taskProgress => LucideIcons.activity,
  NotificationKind.taskCompleted => LucideIcons.circleCheck,
  NotificationKind.taskCommented ||
  NotificationKind.taskMentioned => LucideIcons.messageCircle,
  NotificationKind.taskDueSoon => LucideIcons.clock,
  NotificationKind.taskReminder => LucideIcons.alarmClock,
  NotificationKind.taskOverdue => LucideIcons.triangleAlert,
  NotificationKind.other => LucideIcons.bell,
};
