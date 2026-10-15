import 'package:flutter/material.dart';

import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';

enum NotificationQuickAction { openAll, markAllRead, settings }

/// Menu nhanh của nút chuông. Chuông không đẩy người dùng khỏi màn hiện tại;
/// chỉ một lựa chọn rõ ràng trong menu mới mở màn chuyên sâu.
Future<NotificationQuickAction?> showNotificationQuickMenu(
  BuildContext context, {
  required Rect anchor,
  required int unread,
}) => showOmniAnchoredMenu<NotificationQuickAction>(
  context: context,
  anchor: anchor,
  width: 264,
  menuKey: const Key('notification-quick-menu'),
  semanticsLabel: 'Thông báo nhanh',
  builder: (menuContext) {
    final scheme = Theme.of(menuContext).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Thông báo',
                  style: OmniType.bodyStrong.copyWith(color: scheme.onSurface),
                ),
              ),
              Text(
                unread == 0 ? 'Đã đọc hết' : '$unread chưa đọc',
                style: OmniType.micro.copyWith(
                  color: unread == 0 ? scheme.onSurfaceVariant : scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        OmniAnchoredMenuItem(
          icon: Icons.notifications_none_rounded,
          label: 'Xem tất cả thông báo',
          divider: true,
          onTap: () =>
              Navigator.pop(menuContext, NotificationQuickAction.openAll),
        ),
        if (unread > 0)
          OmniAnchoredMenuItem(
            icon: Icons.done_all_rounded,
            label: 'Đánh dấu tất cả đã đọc',
            divider: true,
            onTap: () =>
                Navigator.pop(menuContext, NotificationQuickAction.markAllRead),
          ),
        OmniAnchoredMenuItem(
          icon: Icons.tune_rounded,
          label: 'Cài đặt thông báo',
          divider: true,
          onTap: () =>
              Navigator.pop(menuContext, NotificationQuickAction.settings),
        ),
      ],
    );
  },
);
