import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/design/tokens/tokens.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('logo chiếm đúng cỡ được yêu cầu', (tester) async {
    await tester.pumpWidget(wrap(const OmniBrandMark(size: 52)));

    expect(tester.getSize(find.byType(OmniBrandMark)), const Size(52, 52));
  });

  testWidgets('logo trang trí không được đọc; logo có nhãn thì được đọc', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(wrap(const OmniBrandMark()));
    expect(find.bySemanticsLabel('Viomni'), findsNothing);

    await tester.pumpWidget(wrap(const OmniBrandMark(semanticLabel: 'Viomni')));
    expect(find.bySemanticsLabel('Viomni'), findsOneWidget);

    handle.dispose();
  });

  test('ô logo đổi sang mực sáng hơn khi nằm trên nền mực', () {
    final light = OmniBrandMarkPainter(
      tile: OmniColors.ink,
      stroke: OmniColors.orbit,
      strokeWidth: 5.5,
      dotRadius: 6.5,
    );
    final onInk = OmniBrandMarkPainter(
      tile: OmniColors.inkRaised,
      stroke: OmniColors.orbit,
      strokeWidth: 5.5,
      dotRadius: 6.5,
    );

    expect(onInk.shouldRepaint(light), isTrue);
  });

  test('khung hình khác nhau thì vẽ lại, giống nhau thì không', () {
    OmniBrandMarkPainter at(OmniBrandFrame frame) => OmniBrandMarkPainter(
      tile: OmniColors.ink,
      stroke: OmniColors.orbit,
      strokeWidth: 5.5,
      dotRadius: 6.5,
      frame: frame,
    );

    expect(
      at(
        const OmniBrandFrame(ring: 0.5),
      ).shouldRepaint(at(OmniBrandFrame.complete)),
      isTrue,
    );
    expect(
      at(const OmniBrandFrame()).shouldRepaint(at(OmniBrandFrame.complete)),
      isFalse,
    );
  });

  testWidgets('vẽ được mọi khung hình của hiệu ứng mà không lỗi', (
    tester,
  ) async {
    for (final p in [0.0, 0.1, 0.3, 0.5, 0.75, 0.9, 1.0]) {
      await tester.pumpWidget(MaterialApp(home: OmniSplash(progress: p)));
      expect(tester.takeException(), isNull, reason: 'progress $p');
    }
  });

  testWidgets('chữ Viomni: "omni" mang màu chính trên nền sáng', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const OmniWordmark()));

    final rich = tester.widget<Text>(find.byType(Text)).textSpan! as TextSpan;
    final omni = rich.children!.single as TextSpan;

    expect(rich.text, 'Vi');
    expect(omni.text, 'omni');
    expect(omni.style!.color, OmniColors.primary);
  });
}
