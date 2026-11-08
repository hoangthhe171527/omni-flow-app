import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/conversation_actions.dart';

/// Hộp thoại Gắn nhãn: trả nhãn đã cắt khoảng trắng, và hộp kính của
/// showOmniPrompt tự dispose controller khi đóng.
void main() {
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
    await act();
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('Áp dụng trả nhãn đã cắt khoảng trắng', (tester) async {
    final label = await open(tester, () async {
      await tester.enterText(find.byType(TextField), '  VIP  ');
      await tester.tap(find.text('Áp dụng'));
    });
    expect(label, 'VIP');
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('Huỷ trả null', (tester) async {
    final label = await open(tester, () => tester.tap(find.text('Huỷ')));
    expect(label, isNull);
    expect(find.byType(TextField), findsNothing);
  });
}
