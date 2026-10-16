import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
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
  final tasks = [
    for (var s = 0; s < 4; s++)
      for (var i = 0; i < 10; i++)
        Task.fromJson({
          'id': 't$s-$i',
          'title': 'Viec $s-$i tieu de kha dai de xuong dong',
          'section_id': 's$s',
          'order': i.toDouble(),
          'due_date': '2026-10-20',
          'comment_count': 2,
        }),
  ];

  Future<void> pumpBoard(WidgetTester t, {bool reduceMotion = false}) async {
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
    t.view.physicalSize = const Size(1300, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          planProvider(planId).overrideWith((ref) async => plan),
          planTasksProvider(
            planId,
          ).overrideWith((ref) async => (tasks: tasks, truncated: false)),
          backgroundProvider.overrideWith(FixedBackground.new),
          teamDirectoryProvider.overrideWith(
            (ref) async => const <TeamMember>[],
          ),
          plansApiProvider.overrideWithValue(_FakePlansApi(plan)),
          tasksApiProvider.overrideWithValue(_FakeTasksApi(tasks)),
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
      // ignore: avoid_print
      print(
        '[smooth] changes=$changes '
        'BoardTaskCard=${counts['BoardTaskCard'] ?? 0} '
        'LongPressDraggable=${counts['LongPressDraggable<Task>'] ?? 0} '
        '_ColumnDropBuilder=${counts['_ColumnDropBuilder'] ?? 0} '
        'ListenableBuilder=${counts['ListenableBuilder'] ?? 0} '
        'perChange=${(total / changes).toStringAsFixed(1)}',
      );

      expect(changes, greaterThanOrEqualTo(4));
      expect(counts['BoardTaskCard'] ?? 0, lessThanOrEqualTo(2 * changes));
      expect(counts['LongPressDraggable<Task>'] ?? 0, 0);
      expect(counts['_ColumnDropBuilder'] ?? 0, lessThanOrEqualTo(2 * changes));
      // Mức cột cũ: `ListenableBuilder` nghe cả bộ điều khiển ở MỌI cột.
      expect(counts['ListenableBuilder'] ?? 0, lessThanOrEqualTo(changes));
      expect(total, lessThanOrEqualTo(60 * changes));

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
    // ignore: avoid_print
    print('[smooth] boundary y=$y flips±1=$flips flips±5=$flips5 (/60)');
    expect(flips, 0);
    expect(flips5, 0);

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
    // ignore: avoid_print
    print('[smooth] slide after 16ms: Δ=${moved.toStringAsFixed(1)}');
    expect(moved, greaterThan(0));
    expect(moved, lessThan(72));

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
  }) async => _tasks.firstWhere((t) => t.id == taskId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
