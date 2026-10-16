import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omni_app/core/network/api_envelope.dart';
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
  final plan = Plan.fromJson({
    'id': planId,
    'name': 'Muot',
    'cover': 'plum-1',
    'sections': [
      for (var s = 0; s < 4; s++) {'id': 's$s', 'name': 'Cot $s', 'order': s},
    ],
  });
  List<Map<String, Object?>> seed() => [
    for (var s = 0; s < 4; s++)
      for (var i = 0; i < 10; i++)
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

  const phone = Size(390, 844);

  Future<void> pumpBoard(
    WidgetTester t, {
    bool reduceMotion = false,
    Size size = const Size(1300, 844),
  }) async {
    raw = seed();
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
          planProvider(planId).overrideWith((ref) async => plan),
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
    expect(t.hasRunningAnimations, isFalse);

    final (_, slot) = targetOf(t);
    final next = find.byKey(ValueKey('t1-$slot'));
    final y0 = t.getTopLeft(next).dy;
    await g.moveTo(Offset(480, t.getCenter(next).dy - 72 + 30));
    await t.pump();
    expect(y0 - t.getTopLeft(next).dy, moreOrLessEquals(72));
    expect(t.hasRunningAnimations, isFalse);

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
      expect(t.hasRunningAnimations, isFalse);
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
