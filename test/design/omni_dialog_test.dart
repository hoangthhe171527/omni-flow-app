import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/platform/omni_dialogs.dart';

void main() {
  Future<void> open(
    WidgetTester tester,
    TargetPlatform platform, {
    void Function(bool)? onResult,
    bool destructive = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: platform),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                final ok = await showOmniConfirm(
                  context: context,
                  title: 'Hoàn thành công việc?',
                  message: 'Quản lý sẽ nhận thông báo.',
                  confirmLabel: 'Hoàn thành',
                  destructive: destructive,
                );
                onResult?.call(ok);
              },
              child: const Text('mở'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
  }

  // Một thẻ kính kiểu iOS cho cả hai nền tảng (viomni-apple-uiux.html).
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform: thẻ kính bo 24, hai nút chữ chia đôi', (
      tester,
    ) async {
      await open(tester, platform);

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      final shape = dialog.shape! as RoundedRectangleBorder;
      expect((shape.borderRadius as BorderRadius).topLeft.x, 24);
      final cancel = tester.getRect(find.text('Huỷ'));
      final ok = tester.getRect(find.text('Hoàn thành'));
      expect(cancel.center.dy, closeTo(ok.center.dy, 1));
      expect(cancel.center.dx, lessThan(ok.center.dx));
    });
  }

  testWidgets('phá huỷ: nút xác nhận màu lỗi', (tester) async {
    await open(tester, TargetPlatform.android, destructive: true);
    final button = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Hoàn thành'),
    );
    final theme = Theme.of(tester.element(find.text('Hoàn thành')));
    expect(button.style!.foregroundColor!.resolve({}), theme.colorScheme.error);
  });

  testWidgets('gạt bỏ hộp thoại là KHÔNG đồng ý', (tester) async {
    // Bấm ra ngoài không phải "chưa trả lời". Với một hành động phá huỷ, hiểu
    // sai chỗ này là xoá nhầm dữ liệu của người ta — nên kiểu trả về là bool
    // chứ không phải bool?, để chỗ gọi không mắc lỗi đó được.
    bool? result;
    await open(tester, TargetPlatform.iOS, onResult: (r) => result = r);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });

  testWidgets('xác nhận trả về true', (tester) async {
    bool? result;
    await open(tester, TargetPlatform.android, onResult: (r) => result = r);

    await tester.tap(find.text('Hoàn thành'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });

  testWidgets('huỷ trả về false', (tester) async {
    bool? result;
    await open(tester, TargetPlatform.android, onResult: (r) => result = r);

    await tester.tap(find.text('Huỷ'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });

  testWidgets('nhãn huỷ mặc định là Huỷ, tiếng Việt', (tester) async {
    await open(tester, TargetPlatform.iOS);

    expect(find.text('Huỷ'), findsOneWidget);
  });

  testWidgets('hành động phá huỷ không phải mặc định (không đậm)', (
    tester,
  ) async {
    // Mặc định là cái người dùng bấm khi không đọc kỹ. Xoá tài khoản không
    // được nằm ở đó: nút phá huỷ đỏ nhưng KHÔNG đậm như nút mặc định.
    await open(tester, TargetPlatform.iOS, destructive: true);
    final button = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Hoàn thành'),
    );
    expect(
      button.style!.textStyle!.resolve({})!.fontWeight,
      isNot(FontWeight.w600),
    );
  });
}
