import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/components/components.dart';

Widget _host(
  ProviderContainer c, {
  int unread = 0,
  void Function(BuildContext)? onBell,
  PreferredSizeWidget? bottom,
  bool tile = true,
}) {
  return UncontrolledProviderScope(
    container: c,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: OmniAccountSlot(
        builder: (_) => const SizedBox(),
        tileBuilder: tile
            ? (_) => const SizedBox.square(key: ValueKey('tile'), dimension: 36)
            : null,
        child: OmniTopBarSlot(
          unreadOf: (_) => unread,
          onBell: onBell ?? (_) {},
          child: Scaffold(appBar: OmniTopBar(bottom: bottom)),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'logo trái, chuông có chấm khi có thông báo, đăng ký BrandAnchor',
    (tester) async {
      final handle = tester.ensureSemantics();
      final c = ProviderContainer();
      addTearDown(c.dispose);

      await tester.pumpWidget(_host(c, unread: 3));
      await tester.pump();

      expect(find.byType(OmniBrandMark), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Thông báo')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('omni-top-bar-bell-dot')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('tile')), findsOneWidget);
      expect(c.read(brandAnchorProvider), isNotNull);
      handle.dispose();
    },
  );

  testWidgets('không có thông báo thì không có chấm; chạm chuông gọi onBell', (
    tester,
  ) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    var taps = 0;

    await tester.pumpWidget(_host(c, onBell: (_) => taps++));
    await tester.pump();

    expect(find.byKey(const ValueKey('omni-top-bar-bell-dot')), findsNothing);
    await tester.tap(find.byIcon(Icons.notifications_none_rounded));
    expect(taps, 1);
  });

  testWidgets('chiều cao gồm hàng 36 và phần bottom; bottom được vẽ', (
    tester,
  ) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);

    const bar = OmniTopBar(
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(40),
        child: SizedBox(key: ValueKey('bottom'), height: 40),
      ),
    );
    expect(bar.preferredSize.height, 8 + 36 + 10 + 40);

    await tester.pumpWidget(
      _host(
        c,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(40),
          child: SizedBox(key: ValueKey('bottom'), height: 40),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('bottom')), findsOneWidget);
  });

  testWidgets('BrandAnchor chỉ xoá khoá của chính nó khi gỡ', (tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);

    await tester.pumpWidget(_host(c));
    await tester.pump();
    expect(c.read(brandAnchorProvider), isNotNull);

    // Một neo mới hơn chiếm chỗ trước khi neo cũ bị gỡ: không bị xoá nhầm.
    final newer = GlobalKey();
    c.read(brandAnchorProvider.notifier).state = newer;
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(c.read(brandAnchorProvider), same(newer));

    // Và khi khoá còn là của nó thì được xoá.
    await tester.pumpWidget(_host(c));
    await tester.pump();
    expect(c.read(brandAnchorProvider), isNot(same(newer)));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(c.read(brandAnchorProvider), isNull);
  });
}
