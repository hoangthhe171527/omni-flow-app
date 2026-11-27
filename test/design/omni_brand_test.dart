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
    // Màn chờ: khung tĩnh và mọi pha của nhịp tỏa, sáng lẫn tối.
    for (final dark in [false, true]) {
      for (final pulse in [null, 0.0, 0.1, 0.5, 0.99]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: dark ? Brightness.dark : Brightness.light,
            ),
            home: OmniSplash(pulse: pulse),
          ),
        );
        expect(tester.takeException(), isNull, reason: 'pulse $pulse');
      }
    }
  });

  // Hướng "Quỹ đạo" (duyệt 26/11/2026).
  testWidgets('quỹ đạo vẽ được mọi kiểu, sáng lẫn tối, không lỗi', (
    tester,
  ) async {
    for (final dark in [false, true]) {
      for (final orbit in const [
        OmniOrbit(),
        OmniOrbit(scale: 0.78, planets: true, anchorLogo: true),
        OmniOrbit(drawIn: true),
        OmniOrbit(scale: 0.42, opacity: 0.9),
        OmniOrbit(showLogo: false, opacity: 0.45, spin: true),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: dark ? Brightness.dark : Brightness.light,
            ),
            home: Scaffold(body: Center(child: orbit)),
          ),
        );
        await tester.pump(const Duration(milliseconds: 700));
        expect(tester.takeException(), isNull);
        expect(
          find.byType(OmniBrandMark),
          orbit.showLogo ? findsOneWidget : findsNothing,
        );
      }
    }
  });

  testWidgets('quỹ đạo: chạy khi được phép, giảm chuyển động thì đứng yên', (
    tester,
  ) async {
    Widget host({required bool reduced}) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: const MaterialApp(
        home: Scaffold(
          body: Center(child: OmniOrbit(planets: true, drawIn: true)),
        ),
      ),
    );

    await tester.pumpWidget(host(reduced: false));
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(host(reduced: true));
    expect(tester.hasRunningAnimations, isFalse);
    // Khung cuối: logo đủ, không mờ.
    expect(find.byType(OmniBrandMark), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byType(OmniBrandMark),
        matching: find.byType(Opacity),
      ),
      findsNothing,
    );
  });

  testWidgets('màn mở app: khẩu hiệu hiện ở cuối phần dựng hình', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: OmniSplash(progress: 0)));
    expect(find.text(OmniSplash.tagline), findsNothing);
    await tester.pumpWidget(const MaterialApp(home: OmniSplash(progress: 1)));
    expect(find.text(OmniSplash.tagline), findsOneWidget);
    expect(find.text('V'), findsOneWidget);
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
