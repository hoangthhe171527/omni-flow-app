import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/module/nav_destination.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/design/tokens/tokens.dart';
import 'package:omni_app/modules/inbox/inbox_module.dart';
import 'package:omni_app/modules/tasks/tasks_module.dart';

/// Quy ước của bộ Orbit cho điều hướng: vàng là "mới", đỏ là "phải xử lý";
/// màn gốc của tab có tiêu đề lớn 26/800.
void main() {
  group('giọng huy hiệu', () {
    test('Hộp thư đếm tin CHƯA ĐỌC — huy hiệu vàng', () {
      final inbox = const InboxModule().navEntries().firstWhere(
        (e) => e.badge != null,
      );
      expect(inbox.badgeTone, NavBadgeTone.unread);
    });

    test('Việc của tôi đếm việc TRỄ — huy hiệu đỏ', () {
      final tasks = const TasksModule().navEntries().firstWhere(
        (e) => e.badge != null,
      );
      expect(tasks.badgeTone, NavBadgeTone.alert);
    });

    test('huy hiệu vàng mang chữ mực, huy hiệu đỏ mang chữ trắng', () {
      const unread = OmniCountBadge.unread(count: 3);
      const alert = OmniCountBadge.alert(count: 3);

      expect(unread.color, OmniColors.sun);
      expect(unread.foreground, OmniColors.ink);
      expect(alert.color, OmniColors.dangerSurface);
      expect(alert.foreground, Colors.white);
    });

    testWidgets('quá 99 thì hiện 99+', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: OmniCountBadge.unread(count: 250)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('99+'), findsOneWidget);
    });
  });

  group('tiêu đề lớn', () {
    testWidgets('màn gốc: 26/800 canh trái', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(appBar: OmniAppBar(title: 'Việc của tôi')),
        ),
      );

      final bar = tester.widget<AppBar>(find.byType(AppBar));
      expect(bar.titleTextStyle!.fontSize, 26);
      expect(bar.titleTextStyle!.fontWeight, FontWeight.w800);
      expect(bar.centerTitle, isFalse);
    });

    testWidgets('màn đẩy vào giữ tiêu đề thường của theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const Scaffold(appBar: OmniAppBar(title: 'Chi tiết')),
                ),
              ),
              child: const Text('mở'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('mở'));
      await tester.pumpAndSettle();

      final bar = tester.widget<AppBar>(find.byType(AppBar));
      expect(bar.titleTextStyle, isNull);
    });
  });
}
