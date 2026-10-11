import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/conversation_actions.dart';

/// Hộp thoại Gắn nhãn: trả nhãn đã cắt khoảng trắng, và controller của ô nhập
/// được dispose khi hộp thoại đóng (trước đây rò rỉ mỗi lần mở).
void main() {
  late TextEditingController controller;

  Future<String?> open(WidgetTester tester, Future<void> Function() act) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: OmniTheme.light(TargetPlatform.android),
          home: Builder(
            builder: (c) {
              ctx = c;
              return const Scaffold();
            },
          ),
        ),
      ),
    );
    final result = showLabelDialog(ctx);
    await tester.pumpAndSettle();
    controller = tester.widget<TextField>(find.byType(TextField)).controller!;
    await act();
    await tester.pumpAndSettle();
    return result;
  }

  /// ChangeNotifier đã dispose ném lỗi khi gắn listener (chế độ debug).
  void expectDisposed(TextEditingController c) =>
      expect(() => c.addListener(() {}), throwsFlutterError);

  testWidgets('Áp dụng trả nhãn đã cắt khoảng trắng, controller được dispose', (
    tester,
  ) async {
    final label = await open(tester, () async {
      await tester.enterText(find.byType(TextField), '  VIP  ');
      await tester.tap(find.text('Áp dụng'));
    });
    expect(label, 'VIP');
    expect(find.byType(LabelDialog), findsNothing);
    expectDisposed(controller);
  });

  testWidgets('Huỷ trả null, controller được dispose', (tester) async {
    final label = await open(tester, () => tester.tap(find.text('Huỷ')));
    expect(label, isNull);
    expectDisposed(controller);
  });
}
