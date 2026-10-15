import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/components/omni_anchored_menu.dart';
import 'package:omni_app/design/theme/omni_theme.dart';

void main() {
  testWidgets('menu gần đáy mở lên trên và nằm trong safe viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: OmniTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Align(
              alignment: Alignment.bottomRight,
              child: TextButton(
                onPressed: () => showOmniAnchoredMenu<void>(
                  context: context,
                  anchor: const Rect.fromLTWH(330, 570, 44, 44),
                  menuKey: const Key('edge-menu'),
                  builder: (_) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      8,
                      (index) => SizedBox(
                        height: 52,
                        child: Center(child: Text('Mục $index')),
                      ),
                    ),
                  ),
                ),
                child: const Text('Mở'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();

    final menu = find.byKey(const Key('edge-menu'));
    expect(menu, findsOneWidget);
    expect(tester.getBottomRight(menu).dy, lessThanOrEqualTo(564));
    expect(tester.getTopLeft(menu).dy, greaterThanOrEqualTo(12));
  });

  testWidgets('menu dài dưới header được cuộn trong viewport', (tester) async {
    tester.view.physicalSize = const Size(390, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: OmniTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showOmniAnchoredMenu<void>(
                context: context,
                anchor: const Rect.fromLTWH(12, 50, 44, 44),
                menuKey: const Key('long-menu'),
                builder: (_) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    12,
                    (index) => SizedBox(
                      height: 52,
                      child: Center(child: Text('Lựa chọn $index')),
                    ),
                  ),
                ),
              ),
              child: const Text('Lọc'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Lọc'));
    await tester.pumpAndSettle();

    final menu = find.byKey(const Key('long-menu'));
    expect(tester.getBottomRight(menu).dy, lessThanOrEqualTo(468));
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });

  testWidgets('Navigator lồng dùng root overlay và đúng tọa độ toàn màn hình', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: OmniTheme.light(),
        home: Scaffold(
          body: Row(
            children: [
              const SizedBox(width: 120, child: ColoredBox(color: Colors.grey)),
              Expanded(
                child: Navigator(
                  onGenerateRoute: (_) => MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      body: Align(
                        alignment: Alignment.topLeft,
                        child: Builder(
                          builder: (buttonContext) => TextButton(
                            onPressed: () {
                              final box =
                                  buttonContext.findRenderObject() as RenderBox;
                              showOmniAnchoredMenu<void>(
                                context: buttonContext,
                                anchor:
                                    box.localToGlobal(Offset.zero) & box.size,
                                menuKey: const Key('nested-menu'),
                                builder: (_) => const SizedBox(
                                  height: 52,
                                  child: Center(child: Text('Trong menu')),
                                ),
                              );
                            },
                            child: const Text('Mở trong nhánh'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mở trong nhánh'));
    await tester.pumpAndSettle();

    final menu = find.byKey(const Key('nested-menu'));
    expect(menu, findsOneWidget);
    expect(tester.getTopLeft(menu).dx, inInclusiveRange(120, 160));

    // Scrim của root overlay phủ cả rail giả ở bên trái.
    await tester.tapAt(const Offset(20, 100));
    await tester.pumpAndSettle();
    expect(menu, findsNothing);
  });
}
