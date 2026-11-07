import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/components/components.dart';

void main() {
  Future<void> open(WidgetTester tester, TargetPlatform platform) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: platform),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showOmniSheet<void>(
                context: context,
                builder: (_) =>
                    const SizedBox(height: 200, child: Text('nội dung')),
              ),
              child: const Text('mở'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
  }

  BottomSheet sheet(WidgetTester tester) =>
      tester.widget<BottomSheet>(find.byType(BottomSheet));

  testWidgets('sheet mở được trên cả hai nền tảng', (tester) async {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      await open(tester, platform);
      expect(find.text('nội dung'), findsOneWidget, reason: '$platform');
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
    }
  });

  Material glass(WidgetTester tester) =>
      tester.widget<Material>(find.byKey(const Key('omni-glass-sheet')));

  double radius(WidgetTester tester) {
    final shape = glass(tester).shape! as RoundedRectangleBorder;
    return (shape.borderRadius as BorderRadius).topLeft.x;
  }

  // Mỗi nền tảng một test riêng, không mở hai sheet trong cùng một tester:
  // pumpWidget lần hai dùng lại cây widget cũ, nên sheet thứ hai vẫn mang cấu
  // hình của lần đầu và test sẽ "xanh" vì lý do sai.
  testWidgets('iOS: viên kính nổi bo 30, có thanh kéo bên trong', (
    tester,
  ) async {
    // Thanh kéo là dấu hiệu người dùng iPhone đọc để biết sheet kéo xuống đóng
    // được.
    await open(tester, TargetPlatform.iOS);

    expect(sheet(tester).backgroundColor, Colors.transparent);
    expect(radius(tester), 30);
    expect(find.byKey(const Key('sheet-handle')), findsOneWidget);
    // Nổi: cách mép trái 8.
    final glassRect = tester.getRect(find.byKey(const Key('omni-glass-sheet')));
    final sheetRect = tester.getRect(find.byType(BottomSheet));
    expect(glassRect.left, greaterThanOrEqualTo(sheetRect.left + 8));
    expect(glassRect.right, lessThanOrEqualTo(sheetRect.right - 8));
  });

  testWidgets('Android: viên kính bo 30, không thanh kéo', (tester) async {
    // Trên Android nút back của hệ thống đã nói sheet đóng được, nên thanh kéo
    // chỉ là thứ thừa chiếm chỗ.
    await open(tester, TargetPlatform.android);

    expect(radius(tester), 30);
    expect(find.byKey(const Key('sheet-handle')), findsNothing);
  });

  testWidgets('giảm chuyển động: sheet hiện ngay, không hoạt ảnh', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          // GestureDetector chứ không TextButton: gợn sóng của nút là một hoạt
          // ảnh riêng, sẽ làm phép đo "sheet không trượt" sai.
          body: Builder(
            builder: (context) => GestureDetector(
              onTap: () => showOmniSheet<void>(
                context: context,
                builder: (_) =>
                    const SizedBox(height: 200, child: Text('nội dung')),
              ),
              child: const Text('mở'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('mở'));
    await tester.pump();
    await tester.pump();

    expect(find.text('nội dung'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
