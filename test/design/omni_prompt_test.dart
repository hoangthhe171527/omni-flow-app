import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/components/components.dart';

void main() {
  Future<String?> Function() open(WidgetTester tester) {
    String? result;
    var done = false;
    return () async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showOmniPrompt(
                    context: context,
                    title: 'Gắn nhãn',
                    confirmLabel: 'Áp dụng',
                    fieldKey: const Key('prompt-field'),
                  );
                  done = true;
                },
                child: const Text('mở'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('mở'));
      await tester.pumpAndSettle();
      expect(done, isFalse);
      return result;
    };
  }

  testWidgets('trả chữ đã cắt khoảng trắng; đóng xong không lỗi', (t) async {
    String? result;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showOmniPrompt(
                context: context,
                title: 'Gắn nhãn',
                confirmLabel: 'Áp dụng',
                fieldKey: const Key('prompt-field'),
              ),
              child: const Text('mở'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('mở'));
    await t.pumpAndSettle();

    final apply = find.widgetWithText(TextButton, 'Áp dụng');
    expect(t.widget<TextButton>(apply).onPressed, isNull, reason: 'ô trống');

    await t.enterText(find.byKey(const Key('prompt-field')), '  VIP  ');
    await t.pump();
    await t.tap(apply);
    // Hoạt ảnh đóng hộp vẫn vẽ ô nhập: controller không được huỷ sớm.
    await t.pumpAndSettle();

    expect(result, 'VIP');
    expect(find.byKey(const Key('prompt-field')), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('Huỷ trả null, không treo', (t) async {
    final run = open(t);
    await run();
    await t.enterText(find.byKey(const Key('prompt-field')), 'abc');
    await t.tap(find.widgetWithText(TextButton, 'Huỷ'));
    await t.pumpAndSettle();

    expect(find.byKey(const Key('prompt-field')), findsNothing);
    expect(t.takeException(), isNull);
  });
}
