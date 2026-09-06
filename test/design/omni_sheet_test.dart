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

  double topRadius(WidgetTester tester) {
    final shape = sheet(tester).shape! as RoundedRectangleBorder;

    return ((shape.borderRadius as BorderRadius).topLeft).x;
  }

  // Mỗi nền tảng một test riêng, không mở hai sheet trong cùng một tester:
  // pumpWidget lần hai dùng lại cây widget cũ, nên sheet thứ hai vẫn mang cấu
  // hình của lần đầu và test sẽ "xanh" vì lý do sai.
  testWidgets('iOS: có thanh kéo, bo 14', (tester) async {
    // Thanh kéo là dấu hiệu người dùng iPhone đọc để biết sheet kéo xuống đóng
    // được.
    await open(tester, TargetPlatform.iOS);

    expect(sheet(tester).showDragHandle, isTrue);
    expect(topRadius(tester), 14);
  });

  testWidgets('Android: không thanh kéo, bo rộng hơn', (tester) async {
    // Trên Android nút back của hệ thống đã nói sheet đóng được, nên thanh kéo
    // chỉ là thứ thừa chiếm chỗ.
    await open(tester, TargetPlatform.android);

    expect(sheet(tester).showDragHandle, isFalse);
    expect(topRadius(tester), greaterThan(14));
  });
}
