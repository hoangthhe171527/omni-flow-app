import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../application/notifications_providers.dart';
import '../domain/app_notification.dart';
import 'notifications_page.dart' show NotificationRow;

/// Bảng thông báo "giọt nước" nở ra từ chuông (rà soát 12/11/2026, mục
/// `#s-chuong`): bấm chuông KHÔNG chuyển trang. Bảng kính phồng từ chính nút
/// chuông (co 12% → nở quá một chút → lắng về 100%, lò xo ~0,55 s, như menu
/// kính iOS 26), nền sau chỉ nhoè nhẹ. Tối đa 5 thông báo mới nhất; chạm một
/// dòng là đi thẳng tới việc / hội thoại; "Xem tất cả" mở trang đầy đủ.
/// Giảm chuyển động: chỉ hiện mờ dần.
Future<void> showNotificationDrop(
  BuildContext context, {
  required Rect anchor,
  required void Function(String taskId) onOpenTask,
  required void Function(String conversationId) onOpenConversation,
  required VoidCallback onSeeAll,
}) {
  HapticFeedback.selectionClick();
  final reduce = MediaQuery.disableAnimationsOf(context);
  final size = MediaQuery.sizeOf(context);
  // Tâm phồng = tâm chuông, quy về toạ độ Alignment của cả màn.
  final origin = Alignment(
    (anchor.center.dx / size.width) * 2 - 1,
    (anchor.center.dy / size.height) * 2 - 1,
  );
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Đóng thông báo',
    barrierColor: Colors.transparent,
    transitionDuration: Duration(milliseconds: reduce ? 150 : 300),
    pageBuilder: (dialogContext, _, _) => _NotificationDrop(
      anchor: anchor,
      onOpenTask: onOpenTask,
      onOpenConversation: onOpenConversation,
      onSeeAll: onSeeAll,
    ),
    transitionBuilder: (context, animation, _, child) {
      final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      // Nền: blur cố định σ6 bọc FadeTransition (không thay đổi sigma mỗi khung
      // hình để tránh compile lại shader blur); bậc thấp chỉ phủ scrim nhẹ.
      final scrim = FadeTransition(
        opacity: fade,
        child: !OmniPerformance.scrimBlur(context)
            ? ColoredBox(
                color: Colors.black.withValues(alpha: 0.14),
                child: const SizedBox.expand(),
              )
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.08),
                  child: const SizedBox.expand(),
                ),
              ),
      );
      final Widget panel = reduce
          ? FadeTransition(opacity: fade, child: child)
          : FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: const Interval(0, 0.35, curve: Curves.easeOut),
              ),
              child: ScaleTransition(
                alignment: origin,
                // Phồng như giọt nước: vượt nhẹ rồi lắng. Lúc đóng: thu gọn
                // nhanh về chuông, không nảy.
                scale: CurvedAnimation(
                  parent: animation,
                  curve: const _DropletCurve(),
                  reverseCurve: Curves.easeInCubic,
                ).drive(Tween(begin: 0.12, end: 1)),
                child: child,
              ),
            );
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
              child: scrim,
            ),
          ),
          panel,
        ],
      );
    },
  );
}

/// easeOutBack nhẹ hơn: vượt ~4% rồi lắng — nhịp "giọt nước" của menu kính.
class _DropletCurve extends Curve {
  const _DropletCurve();

  @override
  double transformInternal(double t) {
    const s = 1.4;
    final x = t - 1;
    return x * x * ((s + 1) * x + s) + 1;
  }
}

class _NotificationDrop extends ConsumerStatefulWidget {
  const _NotificationDrop({
    required this.anchor,
    required this.onOpenTask,
    required this.onOpenConversation,
    required this.onSeeAll,
  });

  final Rect anchor;
  final void Function(String taskId) onOpenTask;
  final void Function(String conversationId) onOpenConversation;
  final VoidCallback onSeeAll;

  static const int maxRows = 5;

  @override
  ConsumerState<_NotificationDrop> createState() => _NotificationDropState();
}

class _NotificationDropState extends ConsumerState<_NotificationDrop> {
  void _open(AppNotification n) {
    HapticFeedback.selectionClick();
    ref.read(notificationsProvider.notifier).markRead(n.id);
    Navigator.of(context).pop();
    final taskId = n.taskId;
    if (taskId != null) {
      widget.onOpenTask(taskId);
      return;
    }
    final conversationId = n.conversationId;
    if (conversationId != null) widget.onOpenConversation(conversationId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    ref.watch(notificationRealtimeProvider);
    final notifications = ref.watch(notificationsProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider).valueOrNull;
    final top = widget.anchor.bottom + 8;
    final hairline = scheme.outline.withValues(alpha: dark ? 0.35 : 0.22);

    final list = notifications.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(child: CircularProgressIndicator.adaptive()),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Text(
          'Chưa tải được thông báo',
          textAlign: TextAlign.center,
          style: OmniType.body.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
      data: (state) {
        final items = state.items.take(_NotificationDrop.maxRows).toList();
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.notifications_none_rounded,
                  size: 26,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.65),
                ),
                const SizedBox(height: 6),
                Text(
                  'Chưa có thông báo',
                  textAlign: TextAlign.center,
                  style: OmniType.bodySm.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) Divider(height: 1, indent: 54, color: hairline),
              NotificationRow(
                key: ValueKey('notification-drop-${items[i].id}'),
                notification: items[i],
                onTap: () => _open(items[i]),
              ),
            ],
          ],
        );
      },
    );

    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPad = screenWidth >= 500 ? 16.0 : 12.0;

    return Stack(
      children: [
        Positioned(
          top: top,
          left: screenWidth >= 500 ? null : horizontalPad,
          right: horizontalPad,
          width: screenWidth >= 500 ? 390 : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height - top - 24,
            ),
            child: Semantics(
              scopesRoute: true,
              namesRoute: true,
              explicitChildNodes: true,
              label: 'Thông báo',
              child: OmniGlass(
                key: const ValueKey('notification-drop'),
                radius: 24,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surface.withValues(alpha: dark ? 0.88 : 0.92),
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 13, 10, 10),
                            child: Row(
                              children: [
                                Text(
                                  'Thông báo',
                                  style: OmniType.navTitle.copyWith(
                                    color: scheme.onSurface,
                                  ),
                                ),
                                if ((unreadCount ?? 0) > 0) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: scheme.primary.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '$unreadCount mới',
                                      style: OmniType.caption.copyWith(
                                        color: scheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                                const Spacer(),
                                if ((unreadCount ?? 0) > 0)
                                  TextButton(
                                    key: const ValueKey(
                                      'notification-drop-read-all',
                                    ),
                                    style: TextButton.styleFrom(
                                      minimumSize: const Size(0, 30),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                    ),
                                    onPressed: () {
                                      HapticFeedback.selectionClick();
                                      ref
                                          .read(notificationsProvider.notifier)
                                          .markAllRead();
                                    },
                                    child: Text(
                                      'Đọc hết',
                                      style: OmniType.bodySm.copyWith(
                                        color: scheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Divider(height: 1, color: hairline),
                          list,
                          Divider(height: 1, color: hairline),
                          InkWell(
                            key: const ValueKey('notification-drop-see-all'),
                            onTap: () {
                              Navigator.of(context).pop();
                              widget.onSeeAll();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 11,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Xem tất cả thông báo',
                                    style: OmniType.bodySm.copyWith(
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 18,
                                    color: scheme.primary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
