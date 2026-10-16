import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/plans/application/plans_providers.dart';
import 'package:omni_app/modules/plans/data/plans_api.dart';
import 'package:omni_app/modules/plans/domain/plan.dart';
import 'package:omni_app/modules/plans/presentation/section_order_page.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';

/// Trang "Sắp xếp nhóm việc" (`AppSections.dc.html`): kéo tay cầm hoặc bấm
/// lên/xuống, lưu giữ id và cờ, ghép vào bản mới nhất của kế hoạch (R8).
void main() {
  const planId = 'p1';
  const names = ['Tiếp nhận', 'Đang xử lý', 'Chờ linh kiện', 'Xong'];

  Plan planOf(List<Map<String, dynamic>> sections) =>
      Plan.fromJson({'id': planId, 'name': 'Bảo hành', 'sections': sections});

  final planA = planOf(const [
    {'id': 's1', 'name': 'Tiếp nhận', 'order': 0},
    {'id': 's2', 'name': 'Đang xử lý', 'order': 1, 'counts_for_kpi': true},
    {
      'id': 's3',
      'name': 'Chờ linh kiện',
      'order': 2,
      'requires_checklist': true,
    },
    {'id': 's4', 'name': 'Xong', 'order': 3},
  ]);

  Task task(String id, String section) =>
      Task.fromJson({'id': id, 'title': id, 'section_id': section});

  late _FakePlansApi plansApi;
  late Plan current;
  var truncated = false;
  var tasksLoaded = true;

  Widget host({bool reduceMotion = false}) {
    plansApi = _FakePlansApi();
    current = planA;
    return ProviderScope(
      overrides: [
        plansApiProvider.overrideWithValue(plansApi),
        planProvider(planId).overrideWith((ref) async => current),
        planTasksProvider(planId).overrideWith((ref) async {
          if (!tasksLoaded) {
            await Completer<void>().future;
          }
          return (
            tasks: [
              task('t1', 's1'),
              task('t2', 's1'),
              task('t3', 's2'),
              task('t4', 's4'),
            ],
            truncated: truncated,
          );
        }),
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
    );
  }

  Future<void> pump(WidgetTester t, {bool reduceMotion = false}) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(host(reduceMotion: reduceMotion));
    await t.pumpAndSettle();
  }

  List<String> order(WidgetTester t) {
    final found = <(String, double)>[];
    for (final n in names) {
      final f = find.text(n);
      if (f.evaluate().isNotEmpty) found.add((n, t.getTopLeft(f).dy));
    }
    found.sort((a, b) => a.$2.compareTo(b.$2));
    return [for (final e in found) e.$1];
  }

  Finder saveButton() => find.widgetWithText(TextButton, 'Lưu');

  setUp(() {
    truncated = false;
    tasksLoaded = true;
  });

  testWidgets(
    'mở ra: "Lưu" tắt; mỗi dòng có tên, "N việc", QC ở nhóm có cổng',
    (t) async {
      await pump(t);

      expect(order(t), names);
      expect(t.widget<TextButton>(saveButton()).onPressed, isNull);
      expect(find.text('2 việc'), findsOneWidget);
      expect(find.text('1 việc'), findsNWidgets(2));
      expect(find.text('0 việc'), findsOneWidget);
      expect(find.text('QC'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('section-row-s3')),
          matching: find.text('QC'),
        ),
        findsOneWidget,
      );
      expect(find.text('Sắp xếp nhóm việc'), findsOneWidget);
    },
  );

  testWidgets('đang tải số việc thì ẩn dòng số; cắt bớt thì "≥N việc"', (
    t,
  ) async {
    tasksLoaded = false;
    await pump(t);
    expect(
      find.byWidgetPredicate(
        (w) => w is Text && RegExp(r'^≥?\d+ việc$').hasMatch(w.data ?? ''),
      ),
      findsNothing,
    );
    expect(find.text('2 việc'), findsNothing);

    tasksLoaded = true;
    truncated = true;
    await t.pumpWidget(const SizedBox());
    await pump(t);
    expect(find.text('≥2 việc'), findsOneWidget);
  });

  testWidgets(
    'nút "Xuống dưới" ở dòng 1 → thứ tự đổi, "Lưu" bật; lưu gửi đúng id theo '
    'thứ tự mới, GIỮ cờ',
    (t) async {
      await pump(t);
      await t.tap(find.byTooltip('Xuống dưới').first);
      await t.pump();

      expect(order(t), ['Đang xử lý', 'Tiếp nhận', 'Chờ linh kiện', 'Xong']);
      expect(t.widget<TextButton>(saveButton()).onPressed, isNotNull);

      await t.tap(find.text('Lưu'));
      await t.pumpAndSettle();

      final sent = plansApi.sentSections.single;
      expect(sent.map((s) => s.id), ['s2', 's1', 's3', 's4']);
      expect(sent[0].countsForKpi, isTrue);
      expect(sent[2].requiresChecklist, isTrue);
    },
  );

  testWidgets('đổi rồi đổi lại như cũ → "Lưu" tắt lại', (t) async {
    await pump(t);
    await t.tap(find.byTooltip('Xuống dưới').first);
    await t.pump();
    expect(t.widget<TextButton>(saveButton()).onPressed, isNotNull);

    await t.tap(find.byTooltip('Lên trên').at(1));
    await t.pump();
    expect(order(t), names);
    expect(t.widget<TextButton>(saveButton()).onPressed, isNull);
  });

  testWidgets('dòng đầu: "Lên trên" tắt; dòng cuối: "Xuống dưới" tắt', (
    t,
  ) async {
    await pump(t);

    final ups = find.byTooltip('Lên trên');
    final downs = find.byTooltip('Xuống dưới');
    expect(ups, findsNWidgets(4));
    expect(btn(t, ups.first).onPressed, isNull);
    expect(btn(t, ups.at(1)).onPressed, isNotNull);
    expect(btn(t, downs.last).onPressed, isNull);
    expect(btn(t, downs.first).onPressed, isNotNull);
  });

  testWidgets(
    'kéo tay cầm dòng 1 xuống dưới dòng 2 (kéo tới tâm dòng 2) → thứ tự mới',
    (t) async {
      await pump(t);
      final handle = grip('Tiếp nhận');
      final g = await t.startGesture(t.getCenter(handle));
      await t.pump(kLongPressTimeout);
      // Kéo từng bước tới đúng tâm dòng 2: ngưỡng đổi chỗ của
      // ReorderableListView nằm sát mép nên một cú nhảy dài dễ vượt quá.
      final target = t.getCenter(find.text("Đang xử lý")).dy;
      for (var i = 0; i < 40 && t.getCenter(handle).dy < target; i++) {
        await g.moveBy(const Offset(0, 8));
        await t.pump();
      }
      await g.up();
      await t.pumpAndSettle();

      expect(order(t), ['Đang xử lý', 'Tiếp nhận', 'Chờ linh kiện', 'Xong']);
      expect(t.widget<TextButton>(saveButton()).onPressed, isNotNull);
    },
  );

  testWidgets(
    'R8: lưu ghép vào bản mới nhất — nhóm người khác thêm nối cuối, tên mới giữ',
    (t) async {
      await pump(t);
      await t.tap(find.byTooltip('Xuống dưới').first);
      await t.pump();

      // Người khác đổi tên s1, thêm s5, xoá s4 trong lúc trang đang mở.
      current = planOf(const [
        {'id': 's1', 'name': 'Nhận đàn', 'order': 0},
        {'id': 's2', 'name': 'Đang xử lý', 'order': 1, 'counts_for_kpi': true},
        {
          'id': 's3',
          'name': 'Chờ linh kiện',
          'order': 2,
          'requires_checklist': true,
        },
        {'id': 's5', 'name': 'Mới', 'order': 3},
      ]);
      ProviderScope.containerOf(
        t.element(find.byType(SectionOrderPage)),
      ).invalidate(planProvider(planId));

      await t.tap(find.text('Lưu'));
      await t.pumpAndSettle();

      final sent = plansApi.sentSections.single;
      expect(sent.map((s) => s.id), ['s2', 's1', 's3', 's5']);
      expect(sent[1].name, 'Nhận đàn');
      expect(sent[0].countsForKpi, isTrue);
      expect(sent[2].requiresChecklist, isTrue);
    },
  );

  testWidgets('lưu xong: trang đóng và trả true', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    Object? result;
    plansApi = _FakePlansApi();
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          plansApiProvider.overrideWithValue(plansApi),
          planProvider(planId).overrideWith((ref) async => planA),
          planTasksProvider(
            planId,
          ).overrideWith((ref) async => (tasks: <Task>[], truncated: false)),
        ],
        child: MaterialApp(
          theme: OmniTheme.light(TargetPlatform.android),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async =>
                    result = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => const SectionOrderPage(planId: planId),
                      ),
                    ),
                child: const Text('mở'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('mở'));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Xuống dưới').first);
    await t.pump();
    await t.tap(find.text('Lưu'));
    await t.pumpAndSettle();

    expect(result, isTrue);
    expect(find.byType(SectionOrderPage), findsNothing);
  });

  testWidgets('lỗi lưu (403) → SnackBar câu server, ở lại màn, "Lưu" vẫn bật', (
    t,
  ) async {
    await pump(t);
    plansApi.error = const ForbiddenException(
      'Bạn không có quyền sửa kế hoạch',
    );
    await t.tap(find.byTooltip('Xuống dưới').first);
    await t.pump();
    await t.tap(find.text('Lưu'));
    await t.pumpAndSettle();

    expect(find.text('Bạn không có quyền sửa kế hoạch'), findsOneWidget);
    expect(find.byType(SectionOrderPage), findsOneWidget);
    expect(t.widget<TextButton>(saveButton()).onPressed, isNotNull);
  });

  testWidgets(
    'giảm chuyển động: không SliverReorderableList, không tay cầm, còn nút lên/xuống',
    (t) async {
      await pump(t, reduceMotion: true);

      expect(find.byType(SliverReorderableList), findsNothing);
      // byType so đúng runtimeType; tay cầm giờ là lớp con riêng của trang.
      expect(
        find.byWidgetPredicate((w) => w is ReorderableDragStartListener),
        findsNothing,
      );
      expect(find.byTooltip('Xuống dưới'), findsNWidgets(4));

      await t.tap(find.byTooltip('Xuống dưới').first);
      await t.pump();
      expect(order(t), ['Đang xử lý', 'Tiếp nhận', 'Chờ linh kiện', 'Xong']);
    },
  );

  testWidgets('nút lên/xuống/tay cầm/quay lại ≥ 44×44', (t) async {
    await pump(t);

    for (final f in [
      find.byTooltip('Quay lại'),
      find.byTooltip('Lên trên').first,
      find.byTooltip('Xuống dưới').first,
      grip('Tiếp nhận'),
      saveButton(),
    ]) {
      final size = t.getSize(f);
      expect(size.width, greaterThanOrEqualTo(44), reason: '$f');
      expect(size.height, greaterThanOrEqualTo(44), reason: '$f');
    }
    expect(
      t.getSize(find.byKey(const ValueKey('section-row-s1'))).height,
      greaterThanOrEqualTo(56),
    );
  });
}

class _FakePlansApi implements PlansApi {
  final sentSections = <List<PlanSection>>[];
  AppException? error;

  @override
  Future<Plan> updateSections(String planId, List<PlanSection> sections) async {
    if (error case final e?) throw e;
    sentSections.add(sections);
    return Plan.fromJson({'id': planId, 'name': 'x'});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Finder grip(String name) => find
    .byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == 'Kéo để đổi chỗ $name',
    )
    .first;

IconButton btn(WidgetTester t, Finder tooltip) => t.widget<IconButton>(
  find.ancestor(of: tooltip, matching: find.byType(IconButton)).first,
);
