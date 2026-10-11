import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/plans/application/plans_providers.dart';
import 'package:omni_app/modules/plans/data/plans_api.dart';
import 'package:omni_app/modules/plans/domain/plan.dart';
import 'package:omni_app/modules/plans/presentation/plan_board_page.dart';
import 'package:omni_app/modules/plans/presentation/widgets/board_column.dart';
import 'package:omni_app/modules/settings/application/appearance_providers.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/data/tasks_api.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/domain/task_permissions.dart';
import 'package:omni_app/modules/team/team.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

import '../support/fixed_background.dart';

/// Bản sửa sau rà soát Task 4: đếm khi xoá nhóm, id nhóm mới, tìm nhiều
/// trang, giữ kết quả cũ khi đang tìm, snap biết số cột.
void main() {
  const planId = 'p1';
  const assigner = {'tasks.read', 'tasks.write', 'tasks.projects.manage.all'};

  final plan = Plan.fromJson(const {
    'id': planId,
    'name': 'Bảo hành',
    'sections': [
      {'id': 's1', 'name': 'Tiếp nhận', 'order': 0},
      {'id': 's2', 'name': 'Đang xử lý', 'order': 1, 'counts_for_kpi': true},
      {
        'id': 's3',
        'name': 'Chờ linh kiện',
        'order': 2,
        'requires_checklist': true,
      },
      {'id': 's4', 'name': 'Xong', 'order': 3},
    ],
  });

  Task task(String id, String title, String? section) =>
      Task.fromJson({'id': id, 'title': title, 'section_id': ?section});

  final tasks = [
    task('t1', 'Bảo hành W106', 's1'),
    task('t2', 'Kiểm tra đàn Kawai ND21', 's1'),
    task('t3', 'Bảo hành Ux kẹt cờ', 's2'),
    task('t4', 'Làm phím CLP920', 's2'),
    // Việc trỏ vào nhóm đã xoá: bảng dồn về cột đầu, nhưng nó không THUỘC s1.
    task('t9', 'Việc mồ côi', 'gone'),
  ];

  late _FakePlansApi plansApi;
  late _FakeTasksApi tasksApi;

  Future<void> pumpBoard(
    WidgetTester tester, {
    bool truncated = false,
    List<Override> extra = const [],
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    plansApi = _FakePlansApi(plan);
    tasksApi = _FakeTasksApi(tasks);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          planProvider(planId).overrideWith((ref) async => plan),
          planTasksProvider(
            planId,
          ).overrideWith((ref) async => (tasks: tasks, truncated: truncated)),
          backgroundProvider.overrideWith(FixedBackground.new),
          teamDirectoryProvider.overrideWith(
            (ref) async => const <TeamMember>[],
          ),
          plansApiProvider.overrideWithValue(plansApi),
          tasksApiProvider.overrideWithValue(tasksApi),
          sessionProvider.overrideWithValue(
            const Session(
              status: SessionStatus.authenticated,
              user: SessionUser(id: 'u-me', fullName: 'Tôi', email: 'me@x.vn'),
            ),
          ),
          taskAccessProvider.overrideWithValue(
            TaskAccess.of(AccessPolicy(assigner)),
          ),
          ...extra,
        ],
        child: MaterialApp(
          theme: OmniTheme.light(TargetPlatform.android),
          home: const PlanBoardPage(planId: planId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder column(String name) => find.byWidgetPredicate(
    (w) => w is BoardColumn && w.section.name == name,
    skipOffstage: false,
  );

  Future<void> search(WidgetTester tester, String q) async {
    if (find.byType(TextField).evaluate().isEmpty) {
      await tester.tap(find.byTooltip('Tìm trong kế hoạch'));
      await tester.pumpAndSettle();
    }
    await tester.enterText(find.byType(TextField), q);
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<String> removeMessage(WidgetTester tester, String section) async {
    await tester.ensureVisible(column(section));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: column(section),
        matching: find.byTooltip('Tuỳ chọn nhóm việc'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xoá nhóm'));
    await tester.pumpAndSettle();
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join('\n');
    return texts;
  }

  group('I1 xoá nhóm', () {
    testWidgets('đếm trên CẢ kế hoạch, không trên bảng đang tìm', (
      tester,
    ) async {
      await pumpBoard(tester);
      await search(tester, 'kawai');
      await tester.pumpAndSettle();
      expect(find.text('Làm phím CLP920'), findsNothing);

      final text = await removeMessage(tester, 'Đang xử lý');
      expect(text, contains('2 việc trong nhóm này sẽ thành chưa xếp nhóm'));
      expect(text, contains('KPI'));
    });

    testWidgets('việc mồ côi ở cột đầu không tính cho nhóm đầu', (
      tester,
    ) async {
      await pumpBoard(tester);
      final text = await removeMessage(tester, 'Tiếp nhận');
      expect(text, contains('2 việc trong nhóm này'));
    });

    testWidgets('danh sách bị cắt thì nói "ít nhất"', (tester) async {
      await pumpBoard(tester, truncated: true);
      final text = await removeMessage(tester, 'Đang xử lý');
      expect(text, contains('Ít nhất 2 việc'));
    });

    testWidgets('nhóm bắt buộc việc con: cảnh báo', (tester) async {
      await pumpBoard(tester);
      final text = await removeMessage(tester, 'Chờ linh kiện');
      expect(text, contains('bắt buộc'));
      expect(text, isNot(contains('KPI')));
    });
  });

  testWidgets('I2 nhóm mới có id ngẫu nhiên, không dạng sN', (tester) async {
    await pumpBoard(tester);
    final tile = find.text('Thêm nhóm việc');
    await tester.dragUntilVisible(
      tile,
      find.byKey(const Key('board-track')),
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Giao khách');
    await tester.pump();
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    final id = plansApi.sentSections.single.last.id;
    expect(id, isNot(matches(RegExp(r'^s\d+$'))));
    expect(id.length, lessThanOrEqualTo(64), reason: 'sections.*.id max:64');
    expect(id.length, greaterThan(16));
  });

  group('I3 tìm nhiều trang', () {
    test('đi hết các trang tới khi trang thiếu', () async {
      final api = _PagingTasksApi(total: 150);
      final container = ProviderContainer(
        overrides: [tasksApiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        planTaskSearchProvider((planId: planId, query: 'x')).future,
      );
      expect(api.pages, [1, 2]);
      expect(result.ids, hasLength(150));
      expect(result.capped, isFalse);
    });

    test('dừng ở trần kMaxTasksOnBoard và báo capped', () async {
      final api = _PagingTasksApi(total: 10000);
      final container = ProviderContainer(
        overrides: [tasksApiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        planTaskSearchProvider((planId: planId, query: 'x')).future,
      );
      expect(api.pages, [1, 2, 3, 4, 5]);
      expect(result.ids, hasLength(kMaxTasksOnBoard));
      expect(result.capped, isTrue);
    });

    test('vừa đúng trần mà hết dữ liệu thì không capped', () async {
      final api = _PagingTasksApi(total: 450);
      final container = ProviderContainer(
        overrides: [tasksApiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
      final result = await container.read(
        planTaskSearchProvider((planId: planId, query: 'x')).future,
      );
      expect(result.capped, isFalse);
    });

    testWidgets('chạm trần thì hiện "Đang hiện N kết quả đầu"', (tester) async {
      await pumpBoard(
        tester,
        extra: [
          planTaskSearchProvider.overrideWith(
            (ref, key) async => (ids: {'t1', 't2'}, capped: true),
          ),
        ],
      );
      await search(tester, 'bảo');
      await tester.pumpAndSettle();
      expect(find.text('Đang hiện 2 kết quả đầu'), findsOneWidget);
    });
  });

  testWidgets('M3 tìm tiếp: giữ kết quả cũ, không quay toàn màn', (
    tester,
  ) async {
    await pumpBoard(tester);
    await search(tester, 'kawai');
    await tester.pumpAndSettle();
    expect(find.text('Kiểm tra đàn Kawai ND21'), findsOneWidget);

    final gate = Completer<void>();
    tasksApi.gate = gate;
    await search(tester, 'w106');
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Kiểm tra đàn Kawai ND21'), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Bảo hành W106'), findsOneWidget);
    expect(find.text('Kiểm tra đàn Kawai ND21'), findsNothing);
  });

  test('M2 snap: không vượt cột cuối dù tầm cuộn ước lượng dư', () {
    const physics = BoardSnapPhysics(count: 4);
    // Ước lượng sai: tầm cuộn như thể có 8 cột.
    final at3 = BoardSnapPhysics.offsetOf(
      3,
      FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 2200,
        pixels: 0,
        viewportDimension: 390,
        axisDirection: AxisDirection.right,
        devicePixelRatio: 1,
      ),
    );
    final metrics = FixedScrollMetrics(
      minScrollExtent: 0,
      maxScrollExtent: 2200,
      pixels: at3,
      viewportDimension: 390,
      axisDirection: AxisDirection.right,
      devicePixelRatio: 1,
    );
    expect(physics.targetFor(metrics, 2000), at3);
  });
}

class _FakePlansApi implements PlansApi {
  _FakePlansApi(this._plan);

  final Plan _plan;
  final sentSections = <List<PlanSection>>[];

  @override
  Future<Plan> updateSections(String planId, List<PlanSection> sections) async {
    sentSections.add(sections);
    return _plan;
  }

  @override
  Future<Plan> plan(String id) async => _plan;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTasksApi implements TasksApi {
  _FakeTasksApi(this._tasks);

  final List<Task> _tasks;
  Completer<void>? gate;

  @override
  Future<Paged<Task>> list({
    required String projectId,
    String? search,
    TaskArchiveScope archived = TaskArchiveScope.active,
    int page = 1,
    int perPage = 100,
  }) async {
    await gate?.future;
    final q = (search ?? '').toLowerCase();
    return Paged(
      items: [
        for (final t in _tasks)
          if (t.title.toLowerCase().contains(q)) t,
      ],
      pagination: const ApiPagination.empty(),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Trả [total] việc, chia trang theo `perPage`.
class _PagingTasksApi implements TasksApi {
  _PagingTasksApi({required this.total});

  final int total;
  final pages = <int>[];

  @override
  Future<Paged<Task>> list({
    required String projectId,
    String? search,
    TaskArchiveScope archived = TaskArchiveScope.active,
    int page = 1,
    int perPage = 100,
  }) async {
    pages.add(page);
    final start = (page - 1) * perPage;
    final end = (start + perPage).clamp(0, total);
    return Paged(
      items: [
        for (var i = start; i < end; i++)
          Task.fromJson({'id': 't$i', 'title': 'x $i'}),
      ],
      pagination: const ApiPagination.empty(),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
