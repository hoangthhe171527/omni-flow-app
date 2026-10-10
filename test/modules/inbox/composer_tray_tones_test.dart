import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/design/tokens/tokens.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/message_composer.dart';

/// Ô tròn của khay công cụ lấy màu từ [OmniFeatureTones] (sáng lẫn tối), không
/// phải hex pastel viết tay.
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
                onPickImages: () async => const [],
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

  Color circleOf(WidgetTester tester, IconData icon) {
    final box = tester.widget<Container>(
      find
          .ancestor(of: find.byIcon(icon), matching: find.byType(Container))
          .first,
    );
    return (box.decoration! as BoxDecoration).color!;
  }

  for (final dark in [false, true]) {
    testWidgets(
      'khay công cụ theo OmniFeatureTones (${dark ? 'tối' : 'sáng'})',
      (tester) async {
        final theme = dark
            ? OmniTheme.dark(TargetPlatform.android)
            : OmniTheme.light(TargetPlatform.android);
        await pump(tester, theme);

        OmniTaskTone tone(OmniHue hue) => dark
            ? OmniFeatureTones.dark(hue, theme.colorScheme.surface)
            : OmniFeatureTones.light(hue);

        expect(
          circleOf(tester, Icons.task_alt_rounded),
          tone(OmniHue.orange).background,
        );
        expect(
          circleOf(tester, Icons.bolt_rounded),
          tone(OmniHue.teal).background,
        );
      },
    );
  }
}
