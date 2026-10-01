import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/design/tokens/tokens.dart';

/// Các mảnh dùng chung của bộ Orbit ở phase 2.
void main() {
  Widget host(Widget child, {bool dark = false}) => MaterialApp(
    theme: OmniTheme.light(TargetPlatform.android),
    darkTheme: OmniTheme.dark(TargetPlatform.android),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    home: Scaffold(body: Center(child: child)),
  );

  BoxDecoration pillBox(WidgetTester tester) =>
      tester
              .widget<AnimatedContainer>(find.byType(AnimatedContainer))
              .decoration!
          as BoxDecoration;

  group('viên lọc', () {
    testWidgets('đang chọn: khối mực', (tester) async {
      await tester.pumpWidget(
        host(OmniFilterPill(label: 'Tất cả', selected: true, onTap: () {})),
      );
      expect(pillBox(tester).color, OmniColors.ink);
    });

    testWidgets('chưa chọn: nền xám nhạt', (tester) async {
      await tester.pumpWidget(
        host(OmniFilterPill(label: 'VIP', selected: false, onTap: () {})),
      );
      expect(pillBox(tester).color, OmniColors.muted);
    });

    testWidgets('chế độ tối: viên chọn không chìm vào nền', (tester) async {
      await tester.pumpWidget(
        host(
          OmniFilterPill(label: 'Tất cả', selected: true, onTap: () {}),
          dark: true,
        ),
      );
      expect(pillBox(tester).color, isNot(OmniColors.ink));
    });
  });

  group('giọng màu', () {
    test('sáng: mỗi giọng là cặp nền nhạt / chữ đậm của Orbit', () {
      final scheme = OmniTheme.light(TargetPlatform.android).colorScheme;

      expect(OmniTone.info.resolve(scheme, dark: false), (
        OmniColors.infoText,
        OmniColors.infoSoft,
      ));
      expect(OmniTone.warning.resolve(scheme, dark: false), (
        OmniColors.warningText,
        OmniColors.warningSoft,
      ));
    });

    test('tối: không dùng lại nền nhạt của chế độ sáng', () {
      final scheme = OmniTheme.dark(TargetPlatform.android).colorScheme;
      for (final tone in OmniTone.values) {
        final (_, background) = tone.resolve(scheme, dark: true);
        expect(
          [
            OmniColors.infoSoft,
            OmniColors.warningSoft,
            OmniColors.dangerSoft,
            OmniColors.muted,
            OmniColors.accent,
          ],
          isNot(contains(background)),
          reason: '$tone',
        );
      }
    });

    testWidgets('huy hiệu nhãn mang đúng giọng', (tester) async {
      await tester.pumpWidget(
        host(const OmniBadge(label: 'VIP', tone: OmniTone.warning)),
      );
      final box =
          tester.widget<Container>(find.byType(Container)).decoration!
              as BoxDecoration;
      expect(box.color, OmniColors.warningSoft);
    });
  });

  group('ô nhập', () {
    testWidgets('focus thì có vầng sáng, rời focus thì tắt', (tester) async {
      await tester.pumpWidget(
        host(
          const SizedBox(
            width: 300,
            child: OmniField(label: 'Email', child: TextField()),
          ),
        ),
      );

      List<BoxShadow>? shadows() =>
          (tester
                      .widget<AnimatedContainer>(
                        find.descendant(
                          of: find.byType(OmniFocusGlow),
                          matching: find.byType(AnimatedContainer),
                        ),
                      )
                      .decoration!
                  as BoxDecoration)
              .boxShadow;

      expect(shadows(), isEmpty);

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(shadows()!.single.color, OmniColors.accentSoft);
      expect(shadows()!.single.spreadRadius, 4);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(shadows(), isEmpty);
    });

    testWidgets('ô tìm mặc định là khối xám không viền', (tester) async {
      await tester.pumpWidget(
        host(SizedBox(width: 300, child: OmniSearchField(onChanged: (_) {}))),
      );
      final decoration = tester
          .widget<TextField>(find.byType(TextField))
          .decoration!;
      expect(decoration.fillColor, OmniColors.muted);
      expect(
        (decoration.enabledBorder! as OutlineInputBorder).borderSide,
        BorderSide.none,
      );
    });
  });
}
