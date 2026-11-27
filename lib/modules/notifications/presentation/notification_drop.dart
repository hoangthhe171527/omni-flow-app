import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../design/components/components.dart';
import '../../../design/platform/omni_motion_scope.dart';
import '../../../design/tokens/tokens.dart';
import '../application/notifications_providers.dart';
import '../application/push_notifications.dart';
import '../domain/app_notification.dart';
import 'notifications_page.dart' show NotificationRow;

/// Bảng thông báo mở TỪ CHÍNH CÁI CHUÔNG (duyệt 26/11/2026, rà soát mục 17):
/// bấm chuông KHÔNG chuyển trang. Thẻ đặc bo 24 (#1C1C1E ở chế độ tối), viền
/// mảnh, bóng sâu, mũi nhọn nhỏ chỉ về chuông; phóng từ góc chuông 35% → 100%
/// có nảy nhẹ (~420ms), các dòng hiện lần lượt (trễ 60ms). Lớp phủ sau tối,
/// không nhoè. Tối đa 5 thông báo mới nhất; chạm một dòng là đi thẳng tới việc
/// / hội thoại; vuốt trái dòng chưa đọc = đánh dấu đã đọc; "Xem tất cả" mở
/// trang đầy đủ. Giảm chuyển động: hiện thẳng.
Future<void> showNotificationDrop(
  BuildContext context, {
  required Rect anchor,
  required void Function(String taskId) onOpenTask,
  required void Function(String conversationId) onOpenConversation,
  required VoidCallback onSeeAll,
}) {
  HapticFeedback.selectionClick();
  final reduce = !OmniMotion.enabled(context);
  final size = MediaQuery.sizeOf(context);
  final dark = Theme.of(context).brightness == Brightness.dark;
  // Gốc phóng = tâm chuông (≈ đầu mũi nhọn), quy về Alignment của cả màn.
  final origin = Alignment(
    (anchor.center.dx / size.width) * 2 - 1,
    (anchor.center.dy / size.height) * 2 - 1,
  );
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Đóng thông báo',
    barrierColor: Colors.transparent,
    transitionDuration: reduce
        ? Duration.zero
        : const Duration(milliseconds: 420),
    pageBuilder: (dialogContext, _, _) => _NotificationDrop(
      anchor: anchor,
      onOpenTask: onOpenTask,
      onOpenConversation: onOpenConversation,
      onSeeAll: onSeeAll,
    ),
    transitionBuilder: (context, animation, _, child) {
      final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      // Lớp phủ tối, KHÔNG nhoè (duyệt 26/11/2026).
      final scrim = FadeTransition(
        opacity: fade,
        child: ColoredBox(
          color: Colors.black.withValues(alpha: dark ? 0.45 : 0.25),
          child: const SizedBox.expand(),
        ),
      );
      final Widget panel = reduce
          ? child
          : FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: const Interval(0, 0.48, curve: Curves.easeOut),
              ),
              child: ScaleTransition(
                alignment: origin,
                // cubic-bezier(.2,.95,.25,1.12): vượt nhẹ rồi lắng. Lúc đóng
                // thu nhanh về chuông, không nảy.
                scale: CurvedAnimation(
                  parent: animation,
                  curve: const Cubic(0.2, 0.95, 0.25, 1.12),
                  reverseCurve: Curves.easeInCubic,
                ).drive(Tween(begin: 0.35, end: 1)),
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
  /// "Tất cả / Chưa đọc" lọc TẠI CHỖ trên trang đã nạp — không đụng
  /// `notificationUnreadOnlyProvider` (dùng chung với trang Thông báo).
  bool _unreadOnly = false;

  void _open(AppNotification n) {
    HapticFeedback.selectionClick();
    ref.read(notificationsProvider.notifier).markRead(n.id);
    Navigator.of(context).pop();
    final hr = PushIntent.hrFromInApp(
      wireType: n.wireType,
      entityId: n.entityId,
    );
    if (hr != null) {
      ref.read(pushIntentProvider.notifier).state = hr;
      return;
    }
    final taskId = n.taskId;
    if (taskId != null) {
      widget.onOpenTask(taskId);
      return;
    }
    final conversationId = n.conversationId;
    if (conversationId != null) widget.onOpenConversation(conversationId);
  }

  /// Dòng trong bảng: bo 16, cách mép thẻ 6. Chưa đọc thì vuốt trái để đánh
  /// dấu đã đọc (API đánh dấu từng cái) — dòng trượt về chỗ, chấm đỏ tắt.
  Widget _row(AppNotification n) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: NotificationRow(
        key: ValueKey('notification-drop-${n.id}'),
        notification: n,
        borderRadius: BorderRadius.circular(16),
        onTap: () => _open(n),
      ),
    );
    if (!n.isUnread) return row;
    final primary = Theme.of(context).colorScheme.primary;
    return Dismissible(
      key: ValueKey('notification-drop-swipe-${n.id}'),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: 0.25},
      confirmDismiss: (_) async {
        HapticFeedback.selectionClick();
        ref.read(notificationsProvider.notifier).markRead(n.id);
        return false;
      },
      background: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: primary.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 18),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.check, size: 18, color: primary),
                  const SizedBox(width: 6),
                  Text(
                    'Đã đọc',
                    style: OmniType.bodySm.copyWith(
                      color: primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      child: row,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    ref.watch(notificationRealtimeProvider);
    final notifications = ref.watch(notificationsProvider);
    final unreadCount =
        ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;

    final size = MediaQuery.sizeOf(context);
    // Mũi nhọn cao 8 nằm trong khe giữa chuông và thẻ.
    final top = widget.anchor.bottom + 10;
    final wide = size.width >= 500;
    final pad = wide ? 16.0 : 12.0;
    final panelWidth = wide ? 390.0 : size.width - 2 * pad;
    // Mũi nhọn rộng 16, đỉnh thẳng tâm chuông; kẹp để không chạm góc bo 24.
    final arrowRight = (size.width - pad - widget.anchor.center.dx - 8).clamp(
      22.0,
      math.max(22.0, panelWidth - 38),
    );
    final card = dark ? OmniColors.darkCard : scheme.surface;
    final line = dark
        ? OmniColors.darkBorder
        : scheme.outline.withValues(alpha: .22);
    final muted = scheme.onSurfaceVariant;

    final list = notifications.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(child: CircularProgressIndicator.adaptive()),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Chưa tải được thông báo',
              textAlign: TextAlign.center,
              style: OmniType.body.copyWith(color: muted),
            ),
            TextButton(
              onPressed: () => ref.invalidate(notificationsProvider),
              style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
      data: (state) {
        final items =
            (_unreadOnly ? state.items.where((n) => n.isUnread) : state.items)
                .take(_NotificationDrop.maxRows)
                .toList();
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.bell,
                  size: 26,
                  color: muted.withValues(alpha: 0.65),
                ),
                const SizedBox(height: 6),
                Text(
                  _unreadOnly
                      ? 'Bạn đã đọc hết thông báo'
                      : 'Chưa có thông báo',
                  textAlign: TextAlign.center,
                  style: OmniType.bodySm.copyWith(color: muted),
                ),
              ],
            ),
          );
        }
        var k = 0;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final group in groupNotificationsByDay(items)) ...[
              // Đầu nhóm chữ HOA 12/700 xám (HÔM NAY / TRƯỚC ĐÓ).
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
                child: Semantics(
                  header: true,
                  label: group.label,
                  excludeSemantics: true,
                  child: Text(
                    group.label.toUpperCase(),
                    style: OmniType.micro.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.72,
                      color: muted,
                    ),
                  ),
                ),
              ),
              for (final n in group.items)
                _StaggerIn(
                  key: ValueKey('notification-drop-in-${n.id}'),
                  delay: Duration(milliseconds: 120 + 60 * k++),
                  child: _row(n),
                ),
            ],
          ],
        );
      },
    );

    final panel = DecoratedBox(
      key: const ValueKey('notification-drop'),
      decoration: BoxDecoration(
        color: card,
        borderRadius: OmniRadius.xxlAll,
        border: Border.all(color: line, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.65 : 0.18),
            blurRadius: 60,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: OmniRadius.xxlAll,
        child: Material(
          type: MaterialType.transparency,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 8, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            'Thông báo',
                            style: OmniType.title.copyWith(
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                      // Số chưa đọc nằm ở phân đoạn "Chưa đọc n" bên dưới:
                      // viên đỏ chữ trắng cũ chỉ 3,55:1.
                      if (unreadCount > 0) ...[
                        TextButton(
                          key: const ValueKey('notification-drop-read-all'),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(44, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            ref
                                .read(notificationsProvider.notifier)
                                .markAllRead();
                          },
                          child: Text(
                            'Đọc hết',
                            style: OmniType.body.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 2),
                  child: OmniSegmented(
                    key: const ValueKey('notification-drop-filter'),
                    compact: true,
                    labels: const ['Tất cả', 'Chưa đọc'],
                    counts: [null, unreadCount > 0 ? unreadCount : null],
                    index: _unreadOnly ? 1 : 0,
                    onChanged: (i) => setState(() => _unreadOnly = i == 1),
                  ),
                ),
                list,
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 10, 0, 14),
                  child: Center(
                    // Nút viên xám "Xem tất cả ›".
                    child: Material(
                      color: dark ? OmniColors.darkMuted : OmniColors.muted,
                      shape: const StadiumBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        key: const ValueKey('notification-drop-see-all'),
                        onTap: () {
                          Navigator.of(context).pop();
                          widget.onSeeAll();
                        },
                        child: SizedBox(
                          height: 44,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Xem tất cả',
                                  style: OmniType.bodySm.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurface,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  LucideIcons.chevronRight,
                                  size: 16,
                                  color: scheme.onSurface,
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
            ),
          ),
        ),
      ),
    );

    return Stack(
      children: [
        Positioned(
          top: top,
          left: wide ? null : pad,
          right: pad,
          width: wide ? panelWidth : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: size.height - top - 24),
            child: Semantics(
              scopesRoute: true,
              namesRoute: true,
              explicitChildNodes: true,
              label: 'Thông báo',
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  panel,
                  // Mũi nhọn chỉ về chuông; vẽ SAU thẻ để phủ viền trên.
                  Positioned(
                    top: -8,
                    right: arrowRight.toDouble(),
                    child: ExcludeSemantics(
                      child: CustomPaint(
                        size: const Size(16, 9),
                        painter: _ArrowPainter(fill: card, stroke: line),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Mũi nhọn tam giác đỉnh bo nhẹ: nền = màu thẻ, viền mảnh hai cạnh xiên;
/// 1px đáy phủ lên viền trên của thẻ để mũi liền với thẻ.
class _ArrowPainter extends CustomPainter {
  const _ArrowPainter({required this.fill, required this.stroke});

  final Color fill;
  final Color stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    const h = 8.0;
    final edge = Path()
      ..moveTo(0, h)
      ..lineTo(w / 2 - 1.6, 1.2)
      ..quadraticBezierTo(w / 2, 0, w / 2 + 1.6, 1.2)
      ..lineTo(w, h);
    final body = Path.from(edge)
      ..lineTo(w, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(body, Paint()..color = fill);
    canvas.drawPath(
      edge,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );
  }

  @override
  bool shouldRepaint(_ArrowPainter old) =>
      old.fill != fill || old.stroke != stroke;
}

/// Dòng hiện lần lượt: chờ [delay] rồi mờ dần + trượt lên 8px (~380ms).
/// Dùng ticker, không hẹn giờ. Giảm chuyển động: hiện ngay.
class _StaggerIn extends StatefulWidget {
  const _StaggerIn({super.key, required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  State<_StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<_StaggerIn>
    with SingleTickerProviderStateMixin {
  static const _run = Duration(milliseconds: 380);

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.delay + _run,
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: Interval(
      widget.delay.inMilliseconds / (widget.delay + _run).inMilliseconds,
      1,
      curve: const Cubic(0.2, 0.9, 0.3, 1),
    ),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (OmniMotion.enabled(context)) {
      _c.forward();
    } else {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _t,
    child: widget.child,
    builder: (context, child) {
      final t = _t.value.clamp(0.0, 1.0);
      return Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - t)),
          child: child,
        ),
      );
    },
  );
}
