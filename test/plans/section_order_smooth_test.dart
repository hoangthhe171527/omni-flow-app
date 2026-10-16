import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/design/tokens/tokens.dart';
import 'package:omni_app/modules/plans/application/plans_providers.dart';
import 'package:omni_app/modules/plans/domain/plan.dart';
import 'package:omni_app/modules/plans/presentation/section_order_page.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';

/// Trang "Sắp xếp nhóm việc" kéo mượt (findings nguyên nhân 6, plan K11–K13):
/// một vùng cuộn duy nhất để bộ tự cuộn ở mép bám đúng Scrollable, tay cầm
/// nhấc ngay sau 2px, bóng của bản nổi lớn dần theo `animation`.
void main() {
  const planId = 'p1';
  const n = 14;
  final names = [for (var i = 0; i < n; i++) 'Nhom $i'];

  final plan = Plan.fromJson({
    'id': planId,
    'name': 'Kế hoạch dài',
    'sections': [
      for (var i = 0; i < n; i++)
        {
          'id': 's$i',
          'name': names[i],
          'order': i,
          if (i == 3) 'requires_checklist': true,
        },
    ],
  });
  final tasks = [
    for (var i = 0; i < 200; i++)
      Task.fromJson({'id': 't$i', 'title': 't$i', 'section_id': 's${i % n}'}),
  ];

  Future<void> pump(WidgetTester t, {bool reduceMotion = false}) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          planProvider(planId).overrideWith((ref) async => plan),
          planTasksProvider(
            planId,
          ).overrideWith((ref) async => (tasks: tasks, truncated: false)),
        ],
        child: MaterialApp(
          theme: OmniTheme.light(TargetPlatform.android),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reduceMotion),
            child: child!,
          ),
          home: const SectionOrderPage(planId: planId),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  Finder grip(String name) => find
      .byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Kéo để đổi chỗ $name',
      )
      .first;

  ScrollPosition position(WidgetTester t) =>
      t.state<ScrollableState>(find.byType(Scrollable).first).position;

  List<BoxShadow>? proxyShadow(WidgetTester t) {
    final box = find.ancestor(
      of: find.text('Nhom 1').last,
      matching: find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).boxShadow != null,
      ),
    );
    if (box.evaluate().isEmpty) return null;
    return (t.widget<DecoratedBox>(box.first).decoration as BoxDecoration)
        .boxShadow;
  }

  List<String> order(WidgetTester t) {
    final found = <(String, double)>[];
    for (final name in names) {
      final f = find.text(name);
      if (f.evaluate().isNotEmpty) found.add((name, t.getTopLeft(f).dy));
    }
    found.sort((a, b) => a.$2.compareTo(b.$2));
    return [for (final e in found) e.$1];
  }

  testWidgets('một Scrollable: không SingleChildScrollView, không shrinkWrap', (
    t,
  ) async {
    await pump(t);
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(find.byType(Scrollable), findsOneWidget);
  });

  testWidgets('giữ tay cầm ở mép dưới 1 giây → danh sách tự cuộn, offset tăng '
      'ngặt mỗi mẫu 100ms cho tới max', (t) async {
    await pump(t);
    final pos = position(t);
    expect(pos.maxScrollExtent, greaterThan(0));

    final g = await t.startGesture(t.getCenter(grip('Nhom 1')));
    await t.pump();
    await g.moveTo(const Offset(20, 830));
    await t.pump();

    var prev = pos.pixels;
    final samples = <double>[];
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
      final now = pos.pixels;
      samples.add(now);
      expect(
        now > prev || now == pos.maxScrollExtent,
        isTrue,
        reason: 'mẫu $i: $prev → $now (max ${pos.maxScrollExtent}) $samples',
      );
      prev = now;
    }
    expect(samples.last, greaterThan(0), reason: '$samples');

    await g.up();
    await t.pumpAndSettle();
  });

  testWidgets('nhấc ngay: ngón đi từng 3px, bản nổi lệch ngón ≤ 4px mọi khung, '
      'không khung nào nhảy > 8px', (t) async {
    await pump(t);
    final y0 = t.getTopLeft(find.text('Nhom 1')).dy;

    final g = await t.startGesture(t.getCenter(grip('Nhom 1')));
    await t.pump();
    var finger = 0.0;
    var prevProxy = 0.0;
    final trace = <String>[];
    for (var i = 1; i <= 12; i++) {
      await g.moveBy(const Offset(0, 3));
      finger += 3;
      await t.pump(const Duration(milliseconds: 16));
      final proxy = t.getTopLeft(find.text('Nhom 1').last).dy - y0;
      trace.add('$finger→$proxy');
      expect(
        (proxy - finger).abs(),
        lessThanOrEqualTo(4),
        reason: 'lần $i: $trace',
      );
      expect(
        (proxy - prevProxy).abs(),
        lessThanOrEqualTo(8),
        reason: 'lần $i: $trace',
      );
      prevProxy = proxy;
    }

    await g.up();
    await t.pumpAndSettle();
  });

  testWidgets(
    'bóng proxy tăng theo animation: khung đầu blur < 26, sau 300ms = 26 (0 10 26)',
    (t) async {
      await pump(t);
      final g = await t.startGesture(t.getCenter(grip('Nhom 1')));
      await t.pump();
      // 20px: quá cả touch slop 18px, để bản cũ cũng nhấc lên và so được bóng.
      await g.moveBy(const Offset(0, 20));
      await t.pump();

      final first = proxyShadow(t);
      expect(first, isNotNull, reason: 'phải có bản nổi trong Overlay');
      final blur0 = first!.isEmpty ? 0.0 : first.single.blurRadius;
      expect(blur0, lessThan(26));

      await t.pump(const Duration(milliseconds: 300));
      final settled = proxyShadow(t)!.single;
      expect(settled.blurRadius, 26);
      expect(settled.offset, const Offset(0, 10));
      expect(settled.color, OmniShadows.dragging.single.color);

      await g.up();
      await t.pumpAndSettle();
    },
  );

  testWidgets('thả xong vẫn đúng thứ tự và "Lưu" bật; giảm chuyển động vẫn chỉ '
      'có mũi tên', (t) async {
    await pump(t);
    final handle = grip('Nhom 0');
    final g = await t.startGesture(t.getCenter(handle));
    final target = t.getCenter(find.text('Nhom 1')).dy;
    for (var i = 0; i < 40 && t.getCenter(handle).dy < target; i++) {
      await g.moveBy(const Offset(0, 8));
      await t.pump();
    }
    await g.up();
    await t.pumpAndSettle();

    expect(order(t).take(3), ['Nhom 1', 'Nhom 0', 'Nhom 2']);
    expect(
      t.widget<TextButton>(find.widgetWithText(TextButton, 'Lưu')).onPressed,
      isNotNull,
    );

    await t.pumpWidget(const SizedBox());
    await pump(t, reduceMotion: true);
    expect(find.byType(SliverReorderableList), findsNothing);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            (w.properties.label ?? '').startsWith('Kéo để đổi chỗ'),
      ),
      findsNothing,
    );
    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(find.byTooltip('Xuống dưới'), findsWidgets);
    await t.tap(find.byTooltip('Xuống dưới').first);
    await t.pump();
    expect(order(t).take(2), ['Nhom 1', 'Nhom 0']);
  });

  testWidgets(
    'khung viền bo góc giữ nguyên: DecoratedSliver viền outlineVariant, bo smAll',
    (t) async {
      await pump(t);
      final scheme = Theme.of(
        t.element(find.byType(SectionOrderPage)),
      ).colorScheme;
      final slivers = t
          .widgetList<DecoratedSliver>(find.byType(DecoratedSliver))
          .map((s) => s.decoration)
          .whereType<BoxDecoration>()
          .toList();
      expect(
        slivers.any(
          (d) =>
              d.borderRadius == OmniRadius.smAll &&
              d.border == Border.all(color: scheme.outlineVariant),
        ),
        isTrue,
        reason: '$slivers',
      );
      expect(
        slivers.any(
          (d) =>
              d.borderRadius == OmniRadius.smAll && d.color == scheme.surface,
        ),
        isTrue,
        reason: '$slivers',
      );
    },
  );
}
