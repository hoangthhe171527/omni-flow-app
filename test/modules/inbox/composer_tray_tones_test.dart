import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/message_composer.dart';

/// Menu công cụ dùng đúng surface/màu nhấn của theme ở cả sáng lẫn tối.
void main() {
  Future<void> pump(WidgetTester tester, ThemeData theme) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Column(
            children: [
              const Expanded(child: SizedBox.expand()),
              MessageComposer(
                onPickImages: (_) async => const [],
                onSend: (_, _, _) async {},
                onCreateTask: () {},
                loadTemplates: () async => const [],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Thêm'));
    await tester.pumpAndSettle();
  }

  for (final dark in [false, true]) {
    testWidgets('menu công cụ theo theme (${dark ? 'tối' : 'sáng'})', (
      tester,
    ) async {
      final theme = dark
          ? OmniTheme.dark(TargetPlatform.android)
          : OmniTheme.light(TargetPlatform.android);
      await pump(tester, theme);

      expect(find.byKey(const Key('composer-tools-menu')), findsOneWidget);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.task_alt_rounded)).color,
        theme.colorScheme.primary,
      );
      expect(
        tester.widget<Icon>(find.byIcon(Icons.bolt_rounded)).color,
        theme.colorScheme.primary,
      );
    });
  }
}
