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
  String? semanticsTitle,
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
          child: Scaffold(
            appBar: OmniTopBar(bottom: bottom, semanticsTitle: semanticsTitle),
          ),
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

  testWidgets('chuông vẽ 36 nhưng vùng chạm 44; tiêu đề trang là header', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await t.pumpWidget(_host(c, semanticsTitle: 'Hộp thư'));
    await t.pump();

    final bell = find.bySemanticsLabel(RegExp('^Thông báo'));
    expect(t.getSize(bell).width, greaterThanOrEqualTo(44));
    expect(t.getSize(bell).height, greaterThanOrEqualTo(44));
    // Phần vẽ vẫn 36.
    expect(
      t.getSize(
        find
            .ancestor(
              of: find.byIcon(Icons.notifications_none_rounded),
              matching: find.byType(Material),
            )
            .first,
      ),
      const Size(36, 36),
    );
    final node = t.getSemantics(find.bySemanticsLabel('Hộp thư'));
    expect(node.flagsCollection.isHeader, isTrue);
    expect(node.rect.isEmpty, isFalse);
    expect(t.getSize(find.byKey(const ValueKey('tile'))).width, 36);
    handle.dispose();
  });

  testWidgets('không có semanticsTitle thì không có header', (t) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await t.pumpWidget(_host(c));
    await t.pump();
    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.header == true,
      ),
      findsNothing,
    );
  });

  testWidgets('chiều cao gồm hàng 44 và phần bottom; bottom được vẽ', (
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
    expect(bar.preferredSize.height, 4 + 44 + 6 + 40);

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
