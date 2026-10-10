import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/design/theme/omni_theme.dart';

Widget host({bool animations = true, bool initiallyExpanded = true}) =>
    MaterialApp(
      theme: OmniTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(800, 600),
          disableAnimations: !animations,
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            child: OmniCollapsibleCard(
              title: 'Việc của tôi',
              count: 7,
              initiallyExpanded: initiallyExpanded,
              footer: const Text('Chân thẻ'),
              child: const SizedBox(height: 100, child: Text('Thân thẻ')),
            ),
          ),
        ),
      ),
    );

SemanticsData headerData(WidgetTester t) => t
    .getSemantics(
      find
          .ancestor(
            of: find.text('Việc của tôi'),
            matching: find.byWidgetPredicate(
              (w) => w is Semantics && w.properties.button == true,
            ),
          )
          .first,
    )
    .getSemanticsData();

void main() {
  testWidgets('bấm tiêu đề thu/mở; semantics expanded đổi theo', (t) async {
    final h = t.ensureSemantics();
    await t.pumpWidget(host());
    expect(find.text('7'), findsOneWidget);
    expect(find.text('Thân thẻ'), findsOneWidget);
    expect(find.text('Chân thẻ'), findsOneWidget);

    expect(headerData(t).flagsCollection.isExpanded, Tristate.isTrue);

    await t.tap(find.text('Việc của tôi'));
    await t.pumpAndSettle();
    expect(find.text('Thân thẻ'), findsNothing);
    expect(find.text('Chân thẻ'), findsNothing);

    expect(headerData(t).flagsCollection.isExpanded, Tristate.isFalse);

    await t.tap(find.text('Việc của tôi'));
    await t.pumpAndSettle();
    expect(find.text('Thân thẻ'), findsOneWidget);
    h.dispose();
  });

  testWidgets('tiêu đề cao ≥44', (t) async {
    await t.pumpWidget(host());
    final btn = find.ancestor(
      of: find.text('Việc của tôi'),
      matching: find.byType(InkWell),
    );
    expect(t.getSize(btn.first).height, greaterThanOrEqualTo(44));
  });

  testWidgets('initiallyExpanded=false → thân ẩn', (t) async {
    await t.pumpWidget(host(initiallyExpanded: false));
    expect(find.text('Thân thẻ'), findsNothing);
  });

  testWidgets('tắt chuyển động → một khung là xong', (t) async {
    await t.pumpWidget(host(animations: false));
    await t.tap(find.text('Việc của tôi'));
    await t.pump();
    // (Gợn mực InkWell vẫn chạy nên không dùng hasRunningAnimations.)
    expect(find.text('Thân thẻ'), findsNothing);
    expect(find.byType(AnimatedSize), findsNothing);
    final rot = t.widget<AnimatedRotation>(find.byType(AnimatedRotation));
    expect(rot.duration, Duration.zero);
  });

  testWidgets('bật chuyển động → mũi tên xoay và thân co dần', (t) async {
    await t.pumpWidget(host());
    double turns() =>
        t.widget<AnimatedRotation>(find.byType(AnimatedRotation)).turns;
    expect(turns(), .5); // mở: ⌄ xoay ngược lên
    await t.tap(find.text('Việc của tôi'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(t.hasRunningAnimations, isTrue);
    await t.pumpAndSettle();
    expect(turns(), 0);
  });

  testWidgets('storageKey: trạng thái thu giữ qua lần dựng lại (PageStorage)', (
    t,
  ) async {
    final show = ValueNotifier(true);
    await t.pumpWidget(
      MaterialApp(
        theme: OmniTheme.light(),
        home: Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: show,
            builder: (_, v, _) => v
                ? const SingleChildScrollView(
                    child: OmniCollapsibleCard(
                      title: 'Việc của tôi',
                      storageKey: 'k1',
                      child: Text('Thân thẻ'),
                    ),
                  )
                : const SizedBox(),
          ),
        ),
      ),
    );
    await t.tap(find.text('Việc của tôi'));
    await t.pumpAndSettle();
    expect(find.text('Thân thẻ'), findsNothing);
    show.value = false;
    await t.pump();
    show.value = true;
    await t.pumpAndSettle();
    expect(find.text('Việc của tôi'), findsOneWidget);
    expect(find.text('Thân thẻ'), findsNothing);
  });
}
