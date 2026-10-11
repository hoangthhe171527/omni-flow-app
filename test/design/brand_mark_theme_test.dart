import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/design/tokens/tokens.dart';

void main() {
  Future<OmniBrandMarkPainter> painterFor(
    WidgetTester tester,
    Brightness brightness, {
    bool? onInk,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        debugShowCheckedModeBanner: false,
        home: Center(child: OmniBrandMark(size: 40, onInk: onInk)),
      ),
    );
    await tester.pumpAndSettle();
    final paint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(OmniBrandMark),
        matching: find.byType(CustomPaint),
      ),
    );
    return paint.painter! as OmniBrandMarkPainter;
  }

  testWidgets('nền sáng dùng ô trắng, nét màu chính', (tester) async {
    final p = await painterFor(tester, Brightness.light);
    expect(p.tile, Colors.white);
    expect(p.tileBorder, const Color(0xFFE3E8EF));
    expect(p.stroke, OmniColors.primary);
  });

  testWidgets('nền tối giữ ô mực, nét orbit', (tester) async {
    final p = await painterFor(tester, Brightness.dark);
    expect(p.tile, OmniColors.ink);
    expect(p.tileBorder, isNull);
    expect(p.stroke, OmniColors.orbit);
  });

  testWidgets('onInk: true giữ ô inkRaised dù theme sáng', (tester) async {
    final p = await painterFor(tester, Brightness.light, onInk: true);
    expect(p.tile, OmniColors.inkRaised);
    expect(p.stroke, OmniColors.orbit);
  });

  testWidgets('onInk: false ép ô sáng dù theme tối', (tester) async {
    final p = await painterFor(tester, Brightness.dark, onInk: false);
    expect(p.tile, Colors.white);
    expect(p.stroke, OmniColors.primary);
  });
}
