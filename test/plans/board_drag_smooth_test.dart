import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/design/components/omni_motion_widgets.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/design/tokens/tokens.dart';
import 'package:omni_app/modules/plans/application/plans_providers.dart';
import 'package:omni_app/modules/plans/data/plans_api.dart';
import 'package:omni_app/modules/plans/domain/plan.dart';
import 'package:omni_app/modules/plans/presentation/plan_board_page.dart';
import 'package:omni_app/modules/plans/presentation/widgets/board_column.dart';
import 'package:omni_app/modules/plans/presentation/widgets/board_drag.dart';
import 'package:omni_app/modules/settings/application/appearance_providers.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/data/tasks_api.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/domain/task_permissions.dart';
import 'package:omni_app/modules/tasks/routes.dart';
import 'package:omni_app/modules/team/team.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

import '../support/fixed_background.dart';

/// Hồi quy độ mượt khi kéo thẻ trên bảng (`docs/superpowers/specs/keo-tha-muot`):
/// vùng dựng lại mỗi lần đổi chỗ chèn, vùng đệm chống lật, khe trượt, bản nổi.
void main() {
  const planId = 'p1';
  Plan planWith(String cover) => Plan.fromJson({
    'id': planId,
    'name': 'Muot',
    'cover': cover,
    'sections': [
      for (var s = 0; s < 4; s++) {'id': 's$s', 'name': 'Cot $s', 'order': s},
    ],
  });
  final plan = planWith('plum-1');
  List<Map<String, Object?>> seed([int cards = 10]) => [
    for (var s = 0; s < 4; s++)
      for (var i = 0; i < cards; i++)
        {
          'id': 't$s-$i',
          'title': 'Viec $s-$i tieu de kha dai de xuong dong',
          'section_id': 's$s',
          'order': i.toDouble(),
          'due_date': '2026-10-20',
          'comment_count': 2,
        },
  ];

  /// Dữ liệu "server" của lượt chạy: mỗi lượt tải parse lại từ JSON, như API
  /// thật (mọi `Task` là instance mới).
  late List<Map<String, Object?>> raw;
  List<Task> parse() => [for (final j in raw) Task.fromJson(j)];
  late _FakeTasksApi api;

  /// Tăng để mô phỏng một lượt tải lại (realtime) của danh sách việc.
  final reloadTick = StateProvider<int>((_) => 0);

  /// Kế hoạch "server" hiện tại; tăng [planTick] để tải lại nó (realtime đổi
  /// nhóm việc).
  late Plan current;
  final planTick = StateProvider<int>((_) => 0);

  const phone = Size(390, 844);

  /// Ảnh cover theo URL; test tự `complete` để quyết định lúc ảnh tải xong.
  final covers = <String, Completer<ui.Image>>{};

  Future<void> pumpBoard(
    WidgetTester t, {
    bool reduceMotion = false,
    Size size = const Size(1300, 844),
    int cards = 10,
    String? cover,
  }) async {
    raw = seed(cards);
    current = cover == null ? plan : planWith(cover);
    api = _FakeTasksApi(parse());
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const PlanBoardPage(planId: planId),
        ),
        GoRoute(
          path: '/tasks/:id',
          name: TaskRoutes.detail,
          builder: (_, _) => const Scaffold(),
        ),
      ],
    );
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          planProvider(planId).overrideWith((ref) async {
            ref.watch(planTick);
            return current;
          }),
          planTasksProvider(planId).overrideWith((ref) async {
            ref.watch(reloadTick);
            return (tasks: parse(), truncated: false);
          }),
          backgroundProvider.overrideWith(FixedBackground.new),
          teamDirectoryProvider.overrideWith(
            (ref) async => const <TeamMember>[],
          ),
          plansApiProvider.overrideWithValue(_FakePlansApi(plan)),
          tasksApiProvider.overrideWithValue(api),
          boardCoverImageProvider.overrideWithValue(
            (url) => _TestCover(url, covers.putIfAbsent(url, Completer.new)),
          ),
          sessionProvider.overrideWithValue(
            const Session(
              status: SessionStatus.authenticated,
              user: SessionUser(id: 'u', fullName: 'T', email: 'a@b.vn'),
            ),
          ),
          taskAccessProvider.overrideWithValue(
            TaskAccess.of(AccessPolicy({'tasks.read', 'tasks.write'})),
          ),
        ],
        child: MaterialApp.router(
          theme: OmniTheme.light(TargetPlatform.android),
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reduceMotion),
            child: child!,
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  BoardDragController dragOf(WidgetTester t) =>
      t.widget<BoardColumn>(find.byType(BoardColumn).first).drag!;

  /// Nhấc 'Viec 0-0' và đưa vào cột 2 (x 480), ở [y].
  Future<TestGesture> liftInto(WidgetTester t, {double y = 120}) async {
    final g = await t.startGesture(
      t.getCenter(find.text('Viec 0-0 tieu de kha dai de xuong dong')),
    );
    await t.pump(const Duration(milliseconds: 450));
    await t.pump(const Duration(milliseconds: 200));
    await g.moveTo(Offset(480, y));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));

    return g;
  }

  (int?, int?) targetOf(WidgetTester t) {
    final d = dragOf(t);

    return (d.targetColumn, d.targetIndex);
  }

  /// Lượt dựng lại phần tử, theo tên lớp widget.
  Map<String, int> countRebuilds() {
    final counts = <String, int>{};
    debugOnRebuildDirtyWidget = (e, _) {
      final n = e.widget.runtimeType.toString();
      counts[n] = (counts[n] ?? 0) + 1;
    };
    addTearDown(() => debugOnRebuildDirtyWidget = null);

    return counts;
  }

  int sum(Map<String, int> m) => m.values.fold(0, (a, b) => a + b);

  /// Đi xuống từng 1px từ [from] tới khi chỗ chèn đổi; trả y lúc đổi.
  Future<double> firstBoundary(
    WidgetTester t,
    TestGesture g,
    double from,
  ) async {
    final start = targetOf(t);
    for (var y = from; y < from + 400; y++) {
      await g.moveTo(Offset(480, y));
      await t.pump(const Duration(milliseconds: 16));
      if (targetOf(t) != start) return y;
    }
    fail('chỗ chèn không đổi trong 400px');
  }

  testWidgets(
    'đổi chỗ chèn: ≤2 BoardTaskCard, 0 LongPressDraggable, ≤2 builder '
    'cột, ≤60 phần tử mỗi lần đổi',
    (t) async {
      await pumpBoard(t);
      final g = await liftInto(t);
      expect(targetOf(t).$1, 1);

      final counts = countRebuilds();
      final atChange = <String, int>{};
      var changes = 0;
      var last = targetOf(t);
      for (var i = 0; i < 300; i++) {
        final before = Map.of(counts);
        await g.moveBy(const Offset(0, 2));
        await t.pump(const Duration(milliseconds: 16));
        final now = targetOf(t);
        if (now != last) {
          changes++;
          for (final e in counts.entries) {
            final d = e.value - (before[e.key] ?? 0);
            if (d > 0) atChange[e.key] = (atChange[e.key] ?? 0) + d;
          }
        }
        last = now;
      }
      debugOnRebuildDirtyWidget = null;
      final total = sum(atChange);
      final info =
          'changes=$changes counts=$counts '
          'perChange=${(total / changes).toStringAsFixed(1)}';

      expect(changes, greaterThanOrEqualTo(4), reason: info);
      expect(
        counts['BoardTaskCard'] ?? 0,
        lessThanOrEqualTo(2 * changes),
        reason: info,
      );
      expect(counts['LongPressDraggable<Task>'] ?? 0, 0, reason: info);
      expect(
        counts['_ColumnDropBuilder'] ?? 0,
        lessThanOrEqualTo(2 * changes),
        reason: info,
      );
      // Mức cột cũ: `ListenableBuilder` nghe cả bộ điều khiển ở MỌI cột.
      expect(
        counts['ListenableBuilder'] ?? 0,
        lessThanOrEqualTo(changes),
        reason: info,
      );
      expect(total, lessThanOrEqualTo(60 * changes), reason: info);

      await g.up();
      await t.pumpAndSettle();
    },
  );

  testWidgets('lượt di chuyển không đổi chỗ chèn: 0 BoardTaskCard, 0 '
      'BoardColumn', (t) async {
    await pumpBoard(t);
    final g = await liftInto(t);
    final start = targetOf(t);

    final counts = countRebuilds();
    for (var i = 0; i < 50; i++) {
      await g.moveBy(Offset(i.isEven ? 3 : -3, 0));
      await t.pump(const Duration(milliseconds: 16));
    }
    debugOnRebuildDirtyWidget = null;

    expect(targetOf(t), start);
    expect(counts['BoardTaskCard'] ?? 0, 0);
    expect(counts['BoardColumn'] ?? 0, 0);
    expect(counts['_ColumnDropBuilder'] ?? 0, 0);
    expect(counts['_SlotGap'] ?? 0, 0);

    await g.up();
    await t.pumpAndSettle();
  });

  testWidgets('rung ±1px và ±5px tại ranh giới chèn 60 khung → ô chỗ trống '
      'không lật', (t) async {
    await pumpBoard(t);
    final g = await liftInto(t);
    final y = await firstBoundary(t, g, 120);

    Future<int> jitter(double amp) async {
      var flips = 0;
      var prev = targetOf(t);
      for (var i = 0; i < 60; i++) {
        await g.moveTo(Offset(480, y + (i.isEven ? 0 : -amp)));
        await t.pump(const Duration(milliseconds: 16));
        final now = targetOf(t);
        if (now != prev) flips++;
        prev = now;
      }

      return flips;
    }

    final flips = await jitter(1);
    final flips5 = await jitter(5);
    expect(flips, 0, reason: 'ranh giới y=$y, ±1px, /60 khung');
    expect(flips5, 0, reason: 'ranh giới y=$y, ±5px, /60 khung');

    await g.up();
    await t.pumpAndSettle();
  });

  testWidgets('khe trượt: ngay sau khi đổi chỗ, thẻ phía sau chưa dời đủ 72px; '
      'sau 150ms thì đủ', (t) async {
    await pumpBoard(t);
    final g = await liftInto(t);
    final (column, slot) = targetOf(t);
    expect(column, 1);
    final next = find.byKey(ValueKey('t1-$slot'));
    final y0 = t.getTopLeft(next).dy;
    // Qua tâm "lúc nghỉ" của thẻ ngay dưới chỗ chèn (tâm đo − khe 72) thêm 30.
    await g.moveTo(Offset(480, t.getCenter(next).dy - 72 + 30));
    await t.pump();
    expect(targetOf(t), (1, slot! + 1));

    await t.pump(const Duration(milliseconds: 16));
    final moved = y0 - t.getTopLeft(next).dy;
    expect(moved, greaterThan(0), reason: 'Δ sau 16ms = $moved');
    expect(moved, lessThan(72), reason: 'Δ sau 16ms = $moved');

    await t.pump(const Duration(milliseconds: 200));
    expect(y0 - t.getTopLeft(next).dy, moreOrLessEquals(72));

    await g.up();
    await t.pumpAndSettle();
  });

  testWidgets('giảm chuyển động: khe mở đủ 64 ngay sau một pump, không còn '
      'khung', (t) async {
    await pumpBoard(t, reduceMotion: true);
    final g = await t.startGesture(
      t.getCenter(find.text('Viec 0-0 tieu de kha dai de xuong dong')),
    );
    await t.pump(const Duration(milliseconds: 450));
    await g.moveTo(const Offset(480, 120));
    await t.pump();
    final placeholder = find.byKey(
      const Key('drop-placeholder'),
      skipOffstage: false,
    );
    expect(t.getSize(placeholder).height, 64);
    // Khe không bọc AnimatedSize khi giảm chuyển động (nhánh tức thì).
    final slotAnimations = find.descendant(
      of: find.byType(BoardColumn, skipOffstage: false),
      matching: find.byType(AnimatedSize, skipOffstage: false),
    );
    expect(slotAnimations, findsNothing);

    final (_, slot) = targetOf(t);
    final next = find.byKey(ValueKey('t1-$slot'));
    final y0 = t.getTopLeft(next).dy;
    await g.moveTo(Offset(480, t.getCenter(next).dy - 72 + 30));
    await t.pump();
    expect(y0 - t.getTopLeft(next).dy, moreOrLessEquals(72));
    expect(slotAnimations, findsNothing);

    await g.up();
    await t.pumpAndSettle();
  });

  testWidgets('bản nổi: thẻ nằm trong RepaintBoundary bên trong Transform', (
    t,
  ) async {
    await pumpBoard(t);
    final g = await liftInto(t);
    final transforms = t.widgetList<Transform>(
      find.descendant(
        of: find.byKey(const Key('drag-feedback')),
        matching: find.byType(Transform),
      ),
    );
    expect(transforms.any((w) => w.child is RepaintBoundary), isTrue);

    await g.up();
    await t.pumpAndSettle();
  });

  testWidgets('cột cuộn tới đáy: khe đóng (cột co, cuộn bị kẹp) rồi mở lại → '
      'chỗ chèn khớp thẻ dưới ngón, đứng yên không lật', (t) async {
    await pumpBoard(t);
    const y = 500.0;
    final g = await liftInto(t, y: y);
    final inner = t
        .state<ScrollableState>(
          find.descendant(
            of: find.byWidgetPredicate(
              (w) => w is BoardColumn && w.section.name == 'Cot 1',
            ),
            matching: find.byType(Scrollable),
          ),
        )
        .position;
    expect(inner.maxScrollExtent, greaterThan(0), reason: 'cột phải cuộn được');
    // Khe đang mở: cuộn tới đáy MỚI (đã gồm khe).
    inner.jumpTo(inner.maxScrollExtent);
    await t.pump();
    // Cột cuộn dưới ngón đứng yên: lượt di chuyển kế dò lại chỗ chèn.
    await g.moveTo(const Offset(480, y + 1));
    await t.pump();
    await t.pump(const Duration(milliseconds: 200));
    // Đứng yên (rung 1px) 30 khung: không lật qua lại. Cho phép MỘT lần dò
    // lại ngay sau khi khe đổi chỗ: khe phía trên vùng thấy được co lại thì
    // danh sách lười sửa offset cuộn (giữ thẻ thấy được tại chỗ), nên tâm
    // "lúc nghỉ" dịch một lần — sau đó phải đứng yên.
    final seen = <(int?, int?)>[targetOf(t)];
    for (var i = 0; i < 30; i++) {
      await g.moveTo(Offset(480, y + (i.isEven ? 0 : 1)));
      await t.pump(const Duration(milliseconds: 16));
      if (targetOf(t) != seen.last) seen.add(targetOf(t));
    }
    expect(seen.length, lessThanOrEqualTo(2), reason: 'chỗ chèn: $seen');

    // Sang cột 2: khe cột 1 đóng, nội dung ngắn đi 72, cuộn bị kẹp về đáy cũ.
    await g.moveTo(const Offset(800, y));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(inner.pixels, inner.maxScrollExtent);

    // Chỗ chèn đúng = số thẻ có tâm (đo lúc khe đóng) nằm trên ngón.
    var expected = 0;
    var seenBuilt = false;
    for (var i = 0; i < 10; i++) {
      final card = find.byKey(ValueKey('t1-$i'), skipOffstage: false);
      if (card.evaluate().isEmpty) {
        if (seenBuilt) break;
        expected++;
        continue;
      }
      seenBuilt = true;
      if (t.getCenter(card).dy >= y) break;
      expected++;
    }

    await g.moveTo(const Offset(480, y));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(targetOf(t), (1, expected));

    await g.up();
    await t.pumpAndSettle();
  });

  Finder columnNamed(String name) => find.byWidgetPredicate(
    (w) => w is BoardColumn && w.section.name == name,
    skipOffstage: false,
  );

  ScrollPosition trackOf(WidgetTester t) => t
      .widget<ListView>(find.byKey(const Key('board-track')))
      .controller!
      .position;

  /// Nhấc 'Viec 0-0' (cột 0), chưa di chuyển.
  Future<TestGesture> lift(WidgetTester t) async {
    final g = await t.startGesture(
      t.getCenter(find.text('Viec 0-0 tieu de kha dai de xuong dong')),
    );
    await t.pump(const Duration(milliseconds: 450));

    return g;
  }

  /// Bơm từng khung 16ms tới khi [until] đúng hoặc hết [limitMs]; trả số ms.
  Future<int> pumpFrames(
    WidgetTester t,
    bool Function() until, {
    int limitMs = 1500,
  }) async {
    var ms = 0;
    while (!until() && ms < limitMs) {
      await t.pump(const Duration(milliseconds: 16));
      ms += 16;
    }

    return ms;
  }

  group('tự trượt mép (điện thoại 390)', () {
    testWidgets('giữ ở mép phải: bắt đầu trượt ≤ 50ms, offset tăng ngặt mỗi '
        'khung, mỗi khung ≤ 20px, đích đổi sang cột kế khi ngón vẫn đứng yên', (
      t,
    ) async {
      await pumpBoard(t, size: phone);
      final track = trackOf(t);
      final g = await lift(t);
      await g.moveTo(const Offset(385, 300));
      await t.pump();
      expect(find.text('Thả vào “Cot 1”'), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        await t.pump(const Duration(milliseconds: 16));
      }
      expect(track.pixels, greaterThan(0), reason: 'sau 48ms');

      final offsets = <double>[track.pixels];
      for (var i = 0; i < 30; i++) {
        await t.pump(const Duration(milliseconds: 16));
        offsets.add(track.pixels);
      }
      for (var i = 1; i < offsets.length; i++) {
        if (offsets[i - 1] >= track.maxScrollExtent) break;
        final step = offsets[i] - offsets[i - 1];
        expect(step, greaterThan(0), reason: 'khung $i: $offsets');
        expect(step, lessThanOrEqualTo(20), reason: 'khung $i: $offsets');
      }

      // Ngón đứng yên, dải trôi: dưới ngón giờ là cột kế.
      final ms = await pumpFrames(
        t,
        () => find.text('Thả vào “Cot 2”').evaluate().isNotEmpty,
        limitMs: 1200 - 33 * 16,
      );
      expect(
        find.text('Thả vào “Cot 2”'),
        findsOneWidget,
        reason: 'sau ${33 * 16 + ms}ms, offset ${track.pixels}',
      );

      await g.up();
      await t.pumpAndSettle();
    });

    testWidgets('rời mép → dừng trượt, snap về offsetOf(cột gần nhất), đích = '
        'cột dưới ngón', (t) async {
      await pumpBoard(t, size: phone);
      final track = trackOf(t);
      final g = await lift(t);
      await g.moveTo(const Offset(385, 300));
      await t.pump();
      await pumpFrames(t, () => track.pixels > BoardMetrics.pitch / 2);
      expect(track.pixels, greaterThan(BoardMetrics.pitch / 2));

      await g.moveTo(const Offset(200, 300));
      await t.pumpAndSettle();
      expect(
        track.pixels,
        moreOrLessEquals(BoardSnapPhysics.offsetOf(1, track)),
      );
      expect(find.text('Thả vào “Cot 1”'), findsOneWidget);
      final settled = track.pixels;
      await t.pump(const Duration(milliseconds: 1500));
      expect(track.pixels, settled);

      await g.up();
      await t.pumpAndSettle();
    });

    testWidgets('nhấc tay khi đang trượt → thả vào cột đang sáng, dải snap, '
        'Ticker dừng', (t) async {
      await pumpBoard(t, size: phone);
      final track = trackOf(t);
      final g = await lift(t);
      await g.moveTo(const Offset(385, 300));
      await t.pump();
      await pumpFrames(t, () => dragOf(t).targetColumn == 2);
      final lit = dragOf(t).targetColumn;
      expect(lit, 2);

      await g.up();
      await t.pumpAndSettle();
      expect(api.moves.single.$2, 's$lit');
      final snaps = [
        for (var k = 0; k < 4; k++) BoardSnapPhysics.offsetOf(k, track),
      ];
      expect(
        snaps.any((s) => (s - track.pixels).abs() < 0.5),
        isTrue,
        reason: 'offset ${track.pixels} không phải điểm snap $snaps',
      );
      // Ticker đã dừng và snap đã xong: dải đứng yên, không còn hoạt động
      // cuộn nào, và vài khung sau vẫn ở đúng chỗ.
      final settled = track.pixels;
      await t.pump(const Duration(milliseconds: 500));
      expect(track.pixels, settled);
      expect(track.isScrollingNotifier.value, isFalse);
    });

    testWidgets('dải dựng sẵn cột kế ngoài màn (cacheExtent = 1 pitch)', (
      t,
    ) async {
      await pumpBoard(t, size: phone);
      expect(columnNamed('Cot 2'), findsOneWidget);
      final track = trackOf(t);
      track.jumpTo(BoardSnapPhysics.offsetOf(1, track));
      await t.pump();
      // Cột 1 căn giữa: cột 2 hé, cột 3 nằm hẳn ngoài màn nhưng đã dựng.
      expect(columnNamed('Cot 3'), findsOneWidget);
    });

    testWidgets('tải lại giữa lượt kéo: 0 BoardTaskCard dựng lại, ô chỗ trống '
        'còn nguyên; thả xong thì thấy dữ liệu mới', (t) async {
      await pumpBoard(t, size: phone);
      final g = await lift(t);
      await g.moveTo(const Offset(340, 300));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      final held = targetOf(t);
      expect(held.$1, 1);
      final placeholder = find.byKey(
        const Key('drop-placeholder'),
        skipOffstage: false,
      );
      expect(placeholder, findsOneWidget);

      final counts = countRebuilds();
      raw[20] = {...raw[20], 'title': 'Tieu de moi tu server'};
      ProviderScope.containerOf(
        t.element(find.byType(PlanBoardPage)),
      ).read(reloadTick.notifier).state++;
      for (var i = 0; i < 5; i++) {
        await t.pump(const Duration(milliseconds: 16));
      }
      debugOnRebuildDirtyWidget = null;
      expect(counts['BoardTaskCard'] ?? 0, 0, reason: '$counts');
      expect(placeholder, findsOneWidget);
      expect(targetOf(t), held);
      expect(
        find.text('Tieu de moi tu server', skipOffstage: false),
        findsNothing,
      );

      await g.up();
      await t.pumpAndSettle();
      expect(
        find.text('Tieu de moi tu server', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('header: glass, KHÔNG BackdropFilter, nằm trong '
        'RepaintBoundary', (t) async {
      await pumpBoard(t, size: phone);
      final header = find.byKey(const Key('board-header'));
      expect(t.widget(header), isA<RepaintBoundary>());
      expect(
        find.descendant(of: header, matching: find.byType(BackdropFilter)),
        findsNothing,
      );
      final glass = t.widget<ColoredBox>(
        find.descendant(of: header, matching: find.byType(ColoredBox)).first,
      );
      expect(glass.color, OmniCovers.glass);
    });

    group('header nền ảnh', () {
      const coverA = 'https://cdn.example.com/projects/p1/a.webp';
      const coverB = 'https://cdn.example.com/projects/p1/b.webp';
      final blur = find.descendant(
        of: find.byKey(const Key('board-header')),
        matching: find.byKey(const Key('board-header-blur')),
      );
      SnapshotController snapshotOf(WidgetTester t) =>
          t.widget<SnapshotWidget>(blur).controller;

      setUp(() {
        covers.clear();
        imageCache.clear();
      });

      Future<void> loadCover(WidgetTester t, String url) async {
        // Ảnh dựng đồng bộ: không `runAsync`, kẻo ảnh nền thật (cache mạng)
        // của ProjectCoverSurface cũng chạy và gọi plugin không có trong test.
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawColor(const Color(0xFF336699), BlendMode.src);
        final image = recorder.endRecording().toImageSync(8, 8);
        covers.putIfAbsent(url, Completer.new).complete(image);
        await t.pump();
        await t.pump();
      }

      testWidgets('mờ bằng ImageFiltered trong SnapshotWidget, KHÔNG '
          'BackdropFilter; chỉ chụp khi ảnh đã có khung đầu', (t) async {
        await pumpBoard(t, size: phone, cover: coverA);
        expect(
          find.descendant(
            of: find.byKey(const Key('board-header')),
            matching: find.byType(BackdropFilter),
          ),
          findsNothing,
        );
        expect(
          find.descendant(of: blur, matching: find.byType(ImageFiltered)),
          findsOneWidget,
        );
        expect(
          snapshotOf(t).allowSnapshotting,
          isFalse,
          reason: 'ảnh chưa tải: chụp lúc này là giữ mãi một tấm trong suốt',
        );

        await loadCover(t, coverA);
        expect(snapshotOf(t).allowSnapshotting, isTrue);
      });

      testWidgets('đổi cover khi bảng đang mở → bỏ ảnh chụp cũ, chờ ảnh mới '
          'rồi chụp lại', (t) async {
        await pumpBoard(t, size: phone, cover: coverA);
        await loadCover(t, coverA);
        expect(snapshotOf(t).allowSnapshotting, isTrue);

        current = planWith(coverB);
        ProviderScope.containerOf(
          t.element(find.byType(PlanBoardPage)),
        ).read(planTick.notifier).state++;
        await t.pump();
        await t.pump();
        expect(snapshotOf(t).allowSnapshotting, isFalse);

        var cleared = 0;
        snapshotOf(t).addListener(() => cleared++);
        await loadCover(t, coverB);
        expect(snapshotOf(t).allowSnapshotting, isTrue);
        expect(cleared, greaterThan(0));
      });

      testWidgets('đổi cỡ nền (xoay, bàn phím) → chụp lại', (t) async {
        await pumpBoard(t, size: phone, cover: coverA);
        await loadCover(t, coverA);
        final snapshot = snapshotOf(t);
        var cleared = 0;
        snapshot.addListener(() => cleared++);

        t.view.physicalSize = const Size(844, 390);
        await t.pump();
        await t.pump();
        expect(cleared, greaterThan(0));
        expect(snapshot.allowSnapshotting, isTrue);
      });
    });

    testWidgets('rời mép rồi nhấc tay giữa lúc snap → thả vào cột dưới ngón '
        'lúc nhấc, không phải đích cũ', (t) async {
      await pumpBoard(t, size: phone);
      final track = trackOf(t);
      final g = await lift(t);
      await g.moveTo(const Offset(385, 300));
      await t.pump();
      await pumpFrames(t, () => track.pixels > BoardMetrics.pitch / 2);
      // Rời mép, ngón về trên cột 0 (cột nguồn). Snap bắt đầu ngay trong sự
      // kiện này, và dải đang trượt thì bỏ qua hit-test: `DragTarget` không
      // nhận ngón, đích chỉ còn nhờ trang dò lại.
      await g.moveTo(const Offset(100, 300));
      await t.pump();

      // Giữa lúc snap: dải đã trôi, dưới ngón giờ là cột 1.
      await t.pump(const Duration(milliseconds: 100));
      final x = track.pixels + 100 - BoardMetrics.inset;
      final under = (x / BoardMetrics.pitch).floor();
      expect(under, 1, reason: 'offset ${track.pixels}');
      expect(dragOf(t).targetColumn, under, reason: 'đích giữa lúc snap');

      await g.up();
      await t.pumpAndSettle();
      expect(api.moves.map((m) => m.$2), ['s$under']);
    });
  });

  group('dữ liệu đổi giữa lượt kéo', () {
    Plan planWith(List<int> order) => Plan.fromJson({
      'id': planId,
      'name': 'Muot',
      'cover': 'plum-1',
      'sections': [
        for (var k = 0; k < order.length; k++)
          {'id': 's${order[k]}', 'name': 'Cot ${order[k]}', 'order': k},
      ],
    });

    Finder cardIn(String column, String title) => find.descendant(
      of: columnNamed(column),
      matching: find.text(title, skipOffstage: false),
    );

    Future<void> reloadPlan(WidgetTester t, Plan next) async {
      current = next;
      ProviderScope.containerOf(
        t.element(find.byType(PlanBoardPage)),
      ).read(planTick.notifier).state++;
      for (var i = 0; i < 5; i++) {
        await t.pump(const Duration(milliseconds: 16));
      }
    }

    const title = 'Viec 0-0 tieu de kha dai de xuong dong';

    testWidgets('nhóm việc đích bị xoá giữa lượt kéo → thả không lỗi', (
      t,
    ) async {
      await pumpBoard(t);
      final g = await lift(t);
      await g.moveTo(const Offset(1100, 120));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(targetOf(t).$1, 3);

      await reloadPlan(t, planWith([0, 1, 2]));
      await g.up();
      await t.pumpAndSettle();

      expect(t.takeException(), isNull);
      expect(api.moves.map((m) => m.$2), ['s3']);
      // Nhóm không còn: thẻ ở chỗ dữ liệu mới đặt nó (việc của nhóm đã xoá rơi
      // về cột đầu), không vẽ lạc quan vào một cột khác.
      expect(cardIn('Cot 0', title), findsOneWidget);
    });

    testWidgets('nhóm việc đổi thứ tự giữa lượt kéo → thẻ vào đúng nhóm đã '
        'thả, không theo chỉ số cột cũ', (t) async {
      await pumpBoard(t);
      final g = await lift(t);
      await g.moveTo(const Offset(650, 120));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Thả vào “Cot 2”'), findsOneWidget);

      await reloadPlan(t, planWith([0, 2, 1, 3]));
      await g.up();
      await t.pumpAndSettle();

      expect(t.takeException(), isNull);
      expect(api.moves.map((m) => m.$2), ['s2']);
      expect(cardIn('Cot 2', title), findsOneWidget);
      expect(cardIn('Cot 1', title), findsNothing);
    });
  });

  testWidgets('cột cuộn xuống đáy rồi về đầu: thẻ đầu dựng lại KHÔNG rise '
      'lại', (t) async {
    await pumpBoard(t, cards: 15);
    final inner = t
        .state<ScrollableState>(
          find.descendant(
            of: columnNamed('Cot 1'),
            matching: find.byType(Scrollable),
          ),
        )
        .position;
    final first = find.byKey(const ValueKey('t1-0'), skipOffstage: false);
    expect(first, findsOneWidget);

    inner.jumpTo(inner.maxScrollExtent);
    await t.pump();
    expect(first, findsNothing, reason: 'thẻ đầu phải rời cây khi cuộn xa');

    inner.jumpTo(0);
    await t.pump();
    final rise = find.descendant(of: first, matching: find.byType(OmniRise));
    expect(t.widget<OmniRise>(rise).animate, isFalse);
    final fade = find.descendant(of: rise, matching: find.byType(Opacity));
    expect(t.widget<Opacity>(fade.first).opacity, 1);
  });

  group('đổi thứ tự trong cùng nhóm', () {
    final card = find.byKey(const ValueKey('t0-2'), skipOffstage: false);
    final above = find.byKey(const ValueKey('t0-1'), skipOffstage: false);
    final below = find.byKey(const ValueKey('t0-3'), skipOffstage: false);
    final placeholder = find.byKey(
      const Key('drop-placeholder'),
      skipOffstage: false,
    );

    /// Nhấc 'Viec 0-2' rồi rê nhẹ trong chính cột 0.
    Future<TestGesture> liftInPlace(WidgetTester t) async {
      final g = await t.startGesture(t.getCenter(card));
      await t.pump(const Duration(milliseconds: 450));
      await t.pump(const Duration(milliseconds: 200));
      await g.moveBy(const Offset(0, 4));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));

      return g;
    }

    testWidgets('bóng mờ gập, đúng một ô chỗ trống tại chỗ cũ, khoảng 8 hai '
        'bên', (t) async {
      await pumpBoard(t);
      final g = await liftInPlace(t);

      expect(targetOf(t), (0, 2));
      expect(placeholder, findsOneWidget);
      final slot = t.getRect(placeholder);
      expect(slot.height, 64);
      expect(slot.top - t.getRect(above).bottom, moreOrLessEquals(8));
      expect(t.getRect(below).top - slot.bottom, moreOrLessEquals(8));

      await g.up();
      await t.pumpAndSettle();
      expect(api.moves, isEmpty, reason: 'thả lại chỗ cũ không gọi API');
    });

    testWidgets('đổi chỗ chèn trong cột nguồn: ≤2 BoardTaskCard, 0 '
        'LongPressDraggable; thả gửi order giữa hai hàng xóm', (t) async {
      await pumpBoard(t);
      final g = await liftInPlace(t);
      final start = targetOf(t);

      final counts = countRebuilds();
      var changes = 0;
      var last = start;
      for (var i = 0; i < 120 && changes < 2; i++) {
        await g.moveBy(const Offset(0, 2));
        await t.pump(const Duration(milliseconds: 16));
        if (targetOf(t) != last) changes++;
        last = targetOf(t);
      }
      debugOnRebuildDirtyWidget = null;

      expect(changes, 2, reason: '$counts');
      expect(last, (0, 4));
      expect(counts['BoardTaskCard'] ?? 0, lessThanOrEqualTo(2 * changes));
      expect(counts['LongPressDraggable<Task>'] ?? 0, 0);
      expect(placeholder, findsOneWidget);

      await g.up();
      await t.pumpAndSettle();
      // Bỏ t0-2 ra: chèn ở 4 là giữa t0-4 (order 4) và t0-5 (order 5).
      expect(api.moves.single, ('t0-2', 's0', 4.5));
    });
  });
}

class _FakePlansApi implements PlansApi {
  _FakePlansApi(this._plan);

  final Plan _plan;

  @override
  Future<Plan> plan(String id) async => _plan;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTasksApi implements TasksApi {
  _FakeTasksApi(this._tasks);

  final List<Task> _tasks;
  final moves = <(String, String, double?)>[];

  @override
  Future<Paged<Task>> list({
    required String projectId,
    String? search,
    TaskArchiveScope archived = TaskArchiveScope.active,
    int page = 1,
    int perPage = 100,
  }) async => Paged(items: _tasks, pagination: const ApiPagination.empty());

  @override
  Future<Task> moveOnBoard(
    String taskId, {
    required String sectionId,
    double? order,
  }) async {
    moves.add((taskId, sectionId, order));

    return _tasks.firstWhere((t) => t.id == taskId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Ảnh cover giả: một khung, có khi [image] hoàn tất.
class _TestCover extends ImageProvider<_TestCover> {
  _TestCover(this.url, this.image);

  final String url;
  final Completer<ui.Image> image;

  @override
  Future<_TestCover> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(_TestCover key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(
        image.future.then((i) => ImageInfo(image: i.clone())),
      );

  @override
  bool operator ==(Object other) => other is _TestCover && other.url == url;

  @override
  int get hashCode => url.hashCode;
}
