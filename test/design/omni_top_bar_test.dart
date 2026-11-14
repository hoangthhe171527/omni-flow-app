import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/core/nav/search_mode.dart';

Widget _host(
  ProviderContainer c, {
  int unread = 0,
  void Function(BuildContext, Rect)? onBell,
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
          onBell: onBell ?? (_, _) {},
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
    'kiểu B: chuông và avatar là viên kính tròn rời, chuông có chấm',
    (tester) async {
      final handle = tester.ensureSemantics();
      final c = ProviderContainer();
      addTearDown(c.dispose);

      await tester.pumpWidget(_host(c, unread: 3));
      await tester.pump();

      // Màn gốc: logo Viomni thay tiêu đề lớn (người dùng chọn 2026-11-08).
      expect(find.byType(OmniBrandMark), findsOneWidget);
      expect(find.byType(OmniGlass), findsNWidgets(2));
      expect(find.bySemanticsLabel(RegExp('Thông báo')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('omni-top-bar-bell-dot')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('tile')), findsOneWidget);
      handle.dispose();
    },
  );

  testWidgets('không có thông báo thì không có chấm; chạm chuông gọi onBell', (
    tester,
  ) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    var taps = 0;
    Rect? anchor;

    await tester.pumpWidget(
      _host(
        c,
        onBell: (_, rect) {
          taps++;
          anchor = rect;
        },
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('omni-top-bar-bell-dot')), findsNothing);
    await tester.tap(find.byIcon(Icons.notifications_none_rounded));
    expect(taps, 1);
    expect(anchor?.size, const Size(44, 44));
  });

  testWidgets('chuông vùng chạm 44; tiêu đề trang là header', (t) async {
    final handle = t.ensureSemantics();
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await t.pumpWidget(_host(c, semanticsTitle: 'Hộp thư'));
    await t.pump();

    expect(
      t.getSize(find.byKey(const ValueKey('omni-top-bar-bell-face'))),
      const Size(44, 44),
    );
    // Chữ không hiện (logo đứng chỗ đó) nhưng vẫn đọc tên màn như header.
    expect(find.text('Hộp thư'), findsNothing);
    final node = t.getSemantics(
      find.byKey(const ValueKey('omni-top-bar-brand')),
    );
    expect(node.label, 'Hộp thư');
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

  testWidgets('chiều cao gồm hàng tiêu đề 48 và dải tìm; bottom được vẽ', (
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
    // Đệm trên 4, hàng tiêu đề 48, đệm 8, dải tìm 40, đệm dưới 8.
    expect(bar.preferredSize.height, 4 + 48 + 8 + 40 + 8);
    expect(const OmniTopBar().preferredSize.height, 4 + 48 + 8);

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

  testWidgets('màn con: nút quay lại gọi onBack, tiêu đề nhỏ, không chuông', (
    tester,
  ) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    var back = 0;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          home: OmniTopBarSlot(
            unreadOf: (_) => 0,
            onBell: (_, _) {},
            child: Scaffold(
              appBar: OmniTopBar(
                semanticsTitle: 'Khách hàng',
                onBack: () => back++,
                actions: [
                  OmniTopBarAction(
                    icon: Icons.edit_note_rounded,
                    tooltip: 'Sửa',
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);
    expect(find.byTooltip('Sửa'), findsOneWidget);
    expect(tester.widget<Text>(find.text('Khách hàng')).style!.fontSize, 17);
    await tester.tap(find.byTooltip('Quay lại'));
    expect(back, 1);
  });

  testWidgets('chạm ô tìm: bật chế độ tìm, không hiện Huỷ, chạm ngoài thì thoát', (
    tester,
  ) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final ctrl = TextEditingController();
    addTearDown(ctrl.dispose);
    await tester.pumpWidget(
      _host(
        c,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: TextField(controller: ctrl),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Huỷ'), findsNothing);

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(c.read(searchModeProvider), isTrue);
    expect(find.text('Huỷ'), findsNothing);

    // Chạm ra ngoài vùng tìm kiếm (lớp mờ) -> thoát chế độ tìm.
    await tester.tap(find.bySemanticsLabel('Thoát tìm kiếm'));
    await tester.pumpAndSettle();
    expect(c.read(searchModeProvider), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AnnotatedRegion<SystemUiOverlayStyle> theo brightness của theme', (
    tester,
  ) async {
    Future<SystemUiOverlayStyle> styleFor(ThemeData theme) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(appBar: OmniTopBar()),
        ),
      );
      await tester.pumpAndSettle();
      final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.descendant(
          of: find.byType(OmniTopBar),
          matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
        ),
      );
      return region.value;
    }

    expect(await styleFor(ThemeData.light()), SystemUiOverlayStyle.dark);
    expect(await styleFor(ThemeData.dark()), SystemUiOverlayStyle.light);
  });
}
