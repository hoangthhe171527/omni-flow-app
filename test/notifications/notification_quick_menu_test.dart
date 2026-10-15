import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/notifications/presentation/notification_quick_menu.dart';

void main() {
  testWidgets('chạm chuông chỉ mở menu; chọn hành động mới trả kết quả', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    NotificationQuickAction? selected;

    await tester.pumpWidget(
      MaterialApp(
        theme: OmniTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Align(
              alignment: Alignment.topRight,
              child: IconButton(
                onPressed: () async {
                  selected = await showNotificationQuickMenu(
                    context,
                    anchor: const Rect.fromLTWH(330, 40, 44, 44),
                    unread: 3,
                  );
                },
                icon: const Icon(Icons.notifications_none_rounded),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.notifications_none_rounded));
    await tester.pumpAndSettle();
    expect(selected, isNull);
    expect(find.byKey(const Key('notification-quick-menu')), findsOneWidget);
    expect(find.text('3 chưa đọc'), findsOneWidget);
    expect(find.text('Xem tất cả thông báo'), findsOneWidget);
    expect(find.text('Đánh dấu tất cả đã đọc'), findsOneWidget);
    expect(find.text('Cài đặt thông báo'), findsOneWidget);

    await tester.tap(find.text('Đánh dấu tất cả đã đọc'));
    await tester.pumpAndSettle();
    expect(selected, NotificationQuickAction.markAllRead);
  });

  testWidgets('không có thông báo mới thì ẩn hành động đọc tất cả', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: OmniTheme.light(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showNotificationQuickMenu(
              context,
              anchor: const Rect.fromLTWH(0, 20, 44, 44),
              unread: 0,
            ),
            child: const Text('Mở'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();
    expect(find.text('Đã đọc hết'), findsOneWidget);
    expect(find.text('Đánh dấu tất cả đã đọc'), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const Key('notification-quick-menu'))).dx,
      12,
    );
  });
}
