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
    transitionDuration: Duration(milliseconds: reduce ? 160 : 520),
    pageBuilder: (dialogContext, _, _) => _NotificationDrop(
      anchor: anchor,
      onOpenTask: onOpenTask,
      onOpenConversation: onOpenConversation,
      onSeeAll: onSeeAll,
    ),
    transitionBuilder: (context, animation, _, child) {
      final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      // Nền: nhoè vừa (6) + phủ rất nhạt — không tối hẳn như hộp thoại.
      final scrim = AnimatedBuilder(
        animation: fade,
        builder: (context, _) => BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 6 * fade.value,
            sigmaY: 6 * fade.value,
          ),
          child: ColoredBox(
            color: Colors.black.withValues(alpha: 0.08 * fade.value),
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
  /// Mở sẵn ở "Chưa đọc" khi còn tin chưa đọc — lý do người ta bấm chuông.
  bool? _unreadOnly;

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
    final scheme = Theme.of(context).colorScheme;
    ref.watch(notificationRealtimeProvider);
    final notifications = ref.watch(notificationsProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider).valueOrNull;
    final unreadOnly = _unreadOnly ?? (unreadCount ?? 0) > 0;
    final top = widget.anchor.bottom + 8;

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
        final items = state.items
            .where((n) => !unreadOnly || n.isUnread)
            .take(_NotificationDrop.maxRows)
            .toList();
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
            child: Text(
              unreadOnly ? 'Đã đọc hết' : 'Chưa có thông báo',
              textAlign: TextAlign.center,
              style: OmniType.body.copyWith(color: scheme.onSurfaceVariant),
            ),
          );
        }
        return OmniGroupSection(
          dividerIndent: 60,
          children: [
            for (final n in items)
              NotificationRow(
                key: ValueKey('notification-drop-${n.id}'),
                notification: n,
                onTap: () => _open(n),
              ),
          ],
        );
      },
    );

    return Stack(
      children: [
        Positioned(
          top: top,
          left: 10,
          right: 10,
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
                radius: 30,
                padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
                child: Material(
                  type: MaterialType.transparency,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 4, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Thông báo',
                                  style: OmniType.navTitle.copyWith(
                                    color: scheme.onSurface,
                                  ),
                                ),
                              ),
                              if ((unreadCount ?? 0) > 0)
                                TextButton(
                                  key: const ValueKey(
                                    'notification-drop-read-all',
                                  ),
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    ref
                                        .read(notificationsProvider.notifier)
                                        .markAllRead();
                                  },
                                  child: const Text('Đọc hết'),
                                ),
                            ],
                          ),
                        ),
                        OmniSegmented(
                          labels: [
                            unreadCount == null
                                ? 'Chưa đọc'
                                : 'Chưa đọc · $unreadCount',
                            'Tất cả',
                          ],
                          index: unreadOnly ? 0 : 1,
                          onChanged: (i) =>
                              setState(() => _unreadOnly = i == 0),
                        ),
                        const SizedBox(height: 10),
                        list,
                        TextButton(
                          key: const ValueKey('notification-drop-see-all'),
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.onSeeAll();
                          },
                          child: const Text('Xem tất cả thông báo'),
                        ),
                      ],
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
