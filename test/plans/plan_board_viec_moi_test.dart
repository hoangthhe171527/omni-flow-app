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
import 'package:omni_app/modules/plans/presentation/edit_sections_page.dart';
import 'package:omni_app/modules/plans/presentation/plan_board_page.dart';
import 'package:omni_app/modules/plans/presentation/section_order_page.dart';
import 'package:omni_app/modules/plans/presentation/widgets/board_column.dart';
import 'package:omni_app/modules/settings/application/appearance_providers.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/data/tasks_api.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/domain/task_permissions.dart';
import 'package:omni_app/modules/tasks/routes.dart';
import 'package:omni_app/modules/tasks/tasks.dart';
import 'package:omni_app/modules/team/team.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

import '../support/fixed_background.dart';

/// Bảng kế hoạch mới (`Board.dc.html`): nền cover, header kính tối, dải cột
/// 300 kéo ngang có snap, "Thêm công việc" theo cột, ô "Thêm nhóm việc".
void main() {
  const planId = 'p1';
  const worker = {'tasks.read', 'tasks.write'};
  const assigner = {'tasks.read', 'tasks.write', 'tasks.projects.manage.all'};

  final plan = Plan.fromJson(const {
    'id': planId,
    'name': 'Bảo hành',
    'team_name': 'Tổ kỹ thuật',
    'cover': 'plum-1',
    'sections': [
      {'id': 's1', 'name': 'Tiếp nhận', 'order': 0},
      {'id': 's2', 'name': 'Đang xử lý', 'order': 1, 'counts_for_kpi': true},
      {'id': 's3', 'name': 'Chờ linh kiện', 'order': 2},
      {'id': 's4', 'name': 'Xong', 'order': 3},
    ],
  });

  Task task(String id, String title, String section) =>
      Task.fromJson({'id': id, 'title': title, 'section_id': section});

  final tasks = [
    task('t1', 'Bảo hành W106', 's1'),
    task('t2', 'Kiểm tra đàn Kawai ND21', 's1'),
    task('t3', 'Bảo hành Ux kẹt cờ', 's2'),
    task('t4', 'Làm phím CLP920', 's2'),
    task('t5', 'Thay khung phím CLP950', 's3'),
    task('t6', 'Xử lý phím CA49', 's3'),
    task('t7', 'Bảo hành 2 cây', 's4'),
  ];

  late _FakePlansApi plansApi;
  late _FakeTasksApi tasksApi;
  CreateTaskArgs? createdWith;

  Widget host({Set<String> perms = assigner, bool reduceMotion = false}) {
    plansApi = _FakePlansApi(plan);
    tasksApi = _FakeTasksApi(tasks);
    createdWith = null;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const PlanBoardPage(planId: planId),
        ),
        GoRoute(
          path: '/tasks/new',
          name: TaskRoutes.create,
          builder: (_, state) {
            createdWith = state.extra as CreateTaskArgs?;
            return const Scaffold(body: Text('trang tao viec'));
          },
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        planProvider(planId).overrideWith((ref) async => plan),
        planTasksProvider(
          planId,
        ).overrideWith((ref) async => (tasks: tasks, truncated: false)),
        backgroundProvider.overrideWith(FixedBackground.new),
        teamDirectoryProvider.overrideWith((ref) async => const <TeamMember>[]),
        plansApiProvider.overrideWithValue(plansApi),
        tasksApiProvider.overrideWithValue(tasksApi),
        sessionProvider.overrideWithValue(
          const Session(
            status: SessionStatus.authenticated,
            user: SessionUser(id: 'u-me', fullName: 'Tôi', email: 'me@x.vn'),
          ),
        ),
        taskAccessProvider.overrideWithValue(
          TaskAccess.of(AccessPolicy(perms)),
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
    );
  }

  Future<void> pumpBoard(
    WidgetTester tester, {
    Set<String> perms = assigner,
    bool reduceMotion = false,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(perms: perms, reduceMotion: reduceMotion));
    await tester.pumpAndSettle();
  }

  Finder column(String name) => find.byWidgetPredicate(
    (w) => w is BoardColumn && w.section.name == name,
    skipOffstage: false,
  );

  testWidgets('(a) cột 300, thấy một phần cột hai, khoảng cách 10', (
    tester,
  ) async {
    await pumpBoard(tester);

    expect(tester.getSize(column('Tiếp nhận')).width, 300);
    final first = tester.getRect(column('Tiếp nhận'));
    final second = tester.getRect(column('Đang xử lý'));
    expect(first.left, 16);
    expect(second.left - first.right, 10);
    expect(second.left, lessThan(390), reason: 'hé cột hai');
    expect(second.right, greaterThan(390));
    // Đệm trên 12 dưới header.
    final header = tester.getRect(find.byKey(const Key('board-header')));
    expect(first.top - header.bottom, 12);
  });

  testWidgets('(b) vuốt nửa cột rồi thả: dừng ở cột kế, căn giữa (snap)', (
    tester,
  ) async {
    await pumpBoard(tester);

    await tester.drag(
      find.byKey(const Key('board-track')),
      const Offset(-160, 0),
    );
    await tester.pumpAndSettle();

    final second = tester.getRect(column('Đang xử lý'));
    expect(second.center.dx, moreOrLessEquals(195, epsilon: 0.5));
  });

  testWidgets('(b) vuốt ít thì về lại cột đầu', (tester) async {
    await pumpBoard(tester);

    await tester.drag(
      find.byKey(const Key('board-track')),
      const Offset(-60, 0),
    );
    await tester.pumpAndSettle();

    expect(tester.getRect(column('Tiếp nhận')).left, 16);
  });

  testWidgets('(b) giảm chuyển động: snap tới nơi sau một khung', (
    tester,
  ) async {
    await pumpBoard(tester, reduceMotion: true);

    await tester.drag(
      find.byKey(const Key('board-track')),
      const Offset(-160, 0),
    );
    await tester.pump();
    await tester.pump();

    expect(
      tester.getRect(column('Đang xử lý')).center.dx,
      moreOrLessEquals(195, epsilon: 0.5),
    );
  });

  testWidgets('đầu cột: tên, viên đếm 20, ⋯ 44 "Tuỳ chọn nhóm việc"', (
    tester,
  ) async {
    await pumpBoard(tester);

    final head = find.descendant(
      of: column('Tiếp nhận'),
      matching: find.byKey(const Key('column-count')),
    );
    expect(tester.getSize(head).height, 20);
    expect(find.descendant(of: head, matching: find.text('2')), findsOneWidget);
    final more = find.descendant(
      of: column('Tiếp nhận'),
      matching: find.byTooltip('Tuỳ chọn nhóm việc'),
    );
    expect(tester.getSize(more), const Size(44, 44));
    // Nền rãnh cột.
    final groove = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: column('Tiếp nhận'),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final deco = groove.decoration as BoxDecoration;
    expect(deco.color, const Color(0xFFEEF1F5));
    expect(deco.borderRadius, BorderRadius.circular(8));
  });

  testWidgets('(c) "Thêm công việc" mở trang tạo với nhóm của cột', (
    tester,
  ) async {
    await pumpBoard(tester, perms: worker);

    final add = find.descendant(
      of: column('Tiếp nhận'),
      matching: find.text('Thêm công việc'),
    );
    expect(add, findsOneWidget);
    expect(
      tester
          .getSize(find.ancestor(of: add, matching: find.byType(InkWell)).first)
          .height,
      greaterThanOrEqualTo(44),
    );
    await tester.tap(add);
    await tester.pumpAndSettle();

    expect(find.text('trang tao viec'), findsOneWidget);
    expect(createdWith?.planId, planId);
    expect(createdWith?.sectionId, 's1');
    expect(createdWith?.sections.map((s) => s.id), ['s1', 's2', 's3', 's4']);
  });

  testWidgets('(c) cột hai gửi đúng nhóm của cột hai', (tester) async {
    await pumpBoard(tester);
    await tester.drag(
      find.byKey(const Key('board-track')),
      const Offset(-160, 0),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: column('Đang xử lý'),
        matching: find.text('Thêm công việc'),
      ),
    );
    await tester.pumpAndSettle();
    expect(createdWith?.sectionId, 's2');
  });

  testWidgets('chỉ đọc: không "Thêm công việc", không FAB "Việc mới"', (
    tester,
  ) async {
    await pumpBoard(tester, perms: const {'tasks.read'});

    expect(find.text('Thêm công việc', skipOffstage: false), findsNothing);
    expect(find.text('Việc mới'), findsNothing);
  });

  testWidgets('(d) người sửa nhóm việc thấy ô "Thêm nhóm việc" ở cuối', (
    tester,
  ) async {
    await pumpBoard(tester);

    final tile = find.text('Thêm nhóm việc');
    await tester.dragUntilVisible(
      tile,
      find.byKey(const Key('board-track')),
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();
    final box = find.byKey(const Key('add-section-tile'));
    expect(tester.getSize(box), const Size(300, 52));

    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.text('Tên nhóm việc'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Giao khách');
    await tester.pump();
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    final sent = plansApi.sentSections.single;
    expect(sent.map((s) => s.name), [
      'Tiếp nhận',
      'Đang xử lý',
      'Chờ linh kiện',
      'Xong',
      'Giao khách',
    ]);
    expect(sent.map((s) => s.id).toSet(), hasLength(5));
    expect(sent.take(4).map((s) => s.id), ['s1', 's2', 's3', 's4']);
    expect(sent[1].countsForKpi, isTrue, reason: 'cờ KPI phải đi theo');
  });

  testWidgets('(d) thợ không có ô "Thêm nhóm việc" và không có ⋯ cột', (
    tester,
  ) async {
    await pumpBoard(tester, perms: worker);

    // Cuộn tới cuối dải: ô này nằm sau cột cuối.
    _scrollTrackToEnd(tester);
    await tester.pumpAndSettle();
    expect(find.text('Xong'), findsOneWidget);
    expect(find.text('Thêm nhóm việc', skipOffstage: false), findsNothing);
    expect(
      find.byTooltip('Tuỳ chọn nhóm việc', skipOffstage: false),
      findsNothing,
    );
  });

  testWidgets('⋯ cột: đổi tên nhóm giữ id và cờ', (tester) async {
    await pumpBoard(tester);

    await tester.tap(
      find.descendant(
        of: column('Tiếp nhận'),
        matching: find.byTooltip('Tuỳ chọn nhóm việc'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Đổi tên nhóm'), findsOneWidget);
    expect(find.text('Xoá nhóm'), findsOneWidget);
    expect(find.text('Sắp xếp nhóm việc'), findsOneWidget);

    await tester.tap(find.text('Đổi tên nhóm'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Nhận đàn');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    final sent = plansApi.sentSections.single;
    expect(sent.map((s) => s.id), ['s1', 's2', 's3', 's4']);
    expect(sent.first.name, 'Nhận đàn');
    expect(sent[1].countsForKpi, isTrue);
  });

  testWidgets('⋯ cột: xoá nhóm hỏi lại rồi gửi mảng thiếu nhóm đó', (
    tester,
  ) async {
    await pumpBoard(tester);

    await tester.tap(
      find.descendant(
        of: column('Tiếp nhận'),
        matching: find.byTooltip('Tuỳ chọn nhóm việc'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xoá nhóm'));
    await tester.pumpAndSettle();
    expect(find.text('Xoá nhóm “Tiếp nhận”?'), findsOneWidget);
    await tester.tap(find.text('Xoá nhóm').last);
    await tester.pumpAndSettle();

    expect(plansApi.sentSections.single.map((s) => s.id), ['s2', 's3', 's4']);
  });

  testWidgets(
    '⋯ cột → "Sắp xếp nhóm việc" mở SectionOrderPage (không phải EditSectionsPage)',
    (tester) async {
      await pumpBoard(tester);

      await tester.tap(
        find.descendant(
          of: column('Tiếp nhận'),
          matching: find.byTooltip('Tuỳ chọn nhóm việc'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sắp xếp nhóm việc'));
      await tester.pumpAndSettle();

      expect(find.byType(SectionOrderPage), findsOneWidget);
      expect(find.byType(EditSectionsPage), findsNothing);
    },
  );

  testWidgets(
    '⋯ cột có cả "Sắp xếp nhóm việc" và "Sửa nhóm việc"; "Sửa nhóm việc" mở EditSectionsPage',
    (tester) async {
      await pumpBoard(tester);

      Future<void> openSheet() async {
        await tester.tap(
          find.descendant(
            of: column('Tiếp nhận'),
            matching: find.byTooltip('Tuỳ chọn nhóm việc'),
          ),
        );
        await tester.pumpAndSettle();
      }

      await openSheet();
      expect(find.text('Sắp xếp nhóm việc'), findsOneWidget);
      expect(find.text('Sửa nhóm việc'), findsOneWidget);

      await tester.tap(find.text('Sửa nhóm việc'));
      await tester.pumpAndSettle();

      expect(find.byType(EditSectionsPage), findsOneWidget);
      expect(find.byType(SectionOrderPage), findsNothing);
    },
  );

  testWidgets('(e) tìm "kawai" gọi search=kawai và chỉ còn thẻ khớp', (
    tester,
  ) async {
    await pumpBoard(tester);

    await tester.tap(find.byTooltip('Tìm trong kế hoạch'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'kawai');
    await tester.pump(const Duration(milliseconds: 299));
    expect(tasksApi.searches, isEmpty, reason: 'debounce 300ms');
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();

    expect(tasksApi.searches, [(planId, 'kawai')]);
    expect(find.text('Kiểm tra đàn Kawai ND21'), findsOneWidget);
    expect(find.text('Bảo hành W106'), findsNothing);
    // Cột rỗng vẫn hiện số 0.
    final count = find.descendant(
      of: column('Đang xử lý'),
      matching: find.byKey(const Key('column-count')),
    );
    expect(find.descendant(of: count, matching: find.text('0')), findsOne);

    await tester.tap(find.byTooltip('Đóng tìm kiếm'));
    await tester.pumpAndSettle();
    expect(find.text('Bảo hành W106'), findsOneWidget);
    expect(find.text('Bảo Hành'), findsNothing);
    expect(find.text('Bảo hành'), findsOneWidget);
  });

  testWidgets('(f) header: tên, "Tổ kỹ thuật · 7 việc", nút 44', (
    tester,
  ) async {
    await pumpBoard(tester);

    expect(find.text('Bảo hành'), findsOneWidget);
    expect(find.text('Tổ kỹ thuật · 7 việc'), findsOneWidget);
    for (final label in [
      'Quay lại',
      'Tìm trong kế hoạch',
      'Lọc theo người',
      'Tuỳ chọn kế hoạch',
    ]) {
      expect(tester.getSize(find.byTooltip(label)), const Size(44, 44));
    }
    final title = tester.widget<Text>(find.text('Bảo hành'));
    expect(title.style?.color, Colors.white);
    expect(title.style?.fontSize, 16);
    expect(title.style?.fontWeight, FontWeight.w600);
  });

  testWidgets('header kính tối: glass, KHÔNG BackdropFilter', (tester) async {
    await pumpBoard(tester);

    // Bỏ blur (kéo thả mượt, K2): dưới header chỉ là gradient tĩnh, blur 20
    // nhìn như nhau mà dựng lại lớp mờ mỗi khung khi dải trượt.
    final header = find.byKey(const Key('board-header'));
    expect(
      find.descendant(of: header, matching: find.byType(BackdropFilter)),
      findsNothing,
    );
    final glass = tester.widget<ColoredBox>(
      find.descendant(of: header, matching: find.byType(ColoredBox)).first,
    );
    expect(glass.color, OmniCovers.glass);
    // Header = safe area (0 trong test) + 44 + 6.
    expect(tester.getSize(header).height, 50);
  });

  testWidgets('(g) nền là gradient của cover', (tester) async {
    await pumpBoard(tester);

    final bg = tester.widget<DecoratedBox>(
      find.byKey(const Key('board-background')),
    );
    expect(
      (bg.decoration as BoxDecoration).gradient,
      OmniCovers.gradientOf('plum-1'),
    );
  });

  testWidgets('(h) không còn PageView một cột mỗi trang', (tester) async {
    await pumpBoard(tester);
    expect(find.byType(PageView), findsNothing);
  });

  testWidgets('cột dài cuộn dọc trong cột, không kéo cả dải', (tester) async {
    final many = [for (var i = 0; i < 20; i++) task('m$i', 'Cây số $i', 's1')];
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          planProvider(planId).overrideWith((ref) async => plan),
          planTasksProvider(
            planId,
          ).overrideWith((ref) async => (tasks: many, truncated: false)),
          backgroundProvider.overrideWith(FixedBackground.new),
          teamDirectoryProvider.overrideWith(
            (ref) async => const <TeamMember>[],
          ),
        ],
        child: MaterialApp(
          theme: OmniTheme.light(TargetPlatform.android),
          home: const PlanBoardPage(planId: planId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final col = tester.getRect(column('Tiếp nhận'));
    expect(col.bottom, lessThanOrEqualTo(844 - 120 + 0.5));
    await tester.drag(find.text('Cây số 2'), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('Cây số 2'), findsNothing);
    expect(tester.getRect(column('Tiếp nhận')).left, 16);
  });

  testWidgets('thẻ chỉ "rise" lần đầu, đổi lọc không phát lại', (tester) async {
    await pumpBoard(tester);

    Iterable<double> opacitiesOf(String title) => tester
        .widgetList<Opacity>(
          find.ancestor(of: find.text(title), matching: find.byType(Opacity)),
        )
        .map((o) => o.opacity);

    await tester.tap(find.byTooltip('Lọc theo người'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chưa giao ai'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(opacitiesOf('Kiểm tra đàn Kawai ND21').every((o) => o == 1), isTrue);
  });

  testWidgets('cột ở xa cuộn tới sau khung đầu: thẻ hiện ngay, không rise', (
    tester,
  ) async {
    await pumpBoard(tester);
    expect(find.text('Bảo hành 2 cây'), findsNothing, reason: 'chưa dựng');

    _scrollTrackToEnd(tester);
    await tester.pump();

    final opacities = tester
        .widgetList<Opacity>(
          find.ancestor(
            of: find.text('Bảo hành 2 cây'),
            matching: find.byType(Opacity),
          ),
        )
        .map((o) => o.opacity);
    expect(opacities.every((o) => o == 1), isTrue);
    await tester.pumpAndSettle();
  });

  testWidgets('⋯ kế hoạch: Sửa kế hoạch + Xoá kế hoạch cho người giao', (
    tester,
  ) async {
    await pumpBoard(tester);

    await tester.tap(find.byTooltip('Tuỳ chọn kế hoạch'));
    await tester.pumpAndSettle();
    expect(find.text('Sửa tên, mô tả, nền'), findsOneWidget);
    await tester.tap(find.text('Xoá kế hoạch'));
    await tester.pumpAndSettle();
    expect(find.text('Xoá kế hoạch “Bảo hành”?'), findsOneWidget);
  });

  testWidgets('snap biết số ô: vuốt mạnh tới cuối dừng đúng ô cuối', (
    tester,
  ) async {
    await pumpBoard(tester);

    final list = tester.widget<ListView>(find.byKey(const Key('board-track')));
    // Bốn cột + ô "Thêm nhóm việc".
    expect((list.physics! as BoardSnapPhysics).count, 5);

    await tester.fling(
      find.byKey(const Key('board-track')),
      const Offset(-2000, 0),
      8000,
    );
    await tester.pumpAndSettle();
    final position = list.controller!.position;
    expect(position.pixels, position.maxScrollExtent);
    expect(find.text('Thêm nhóm việc'), findsOneWidget);
  });

  testWidgets('snap của thợ: chỉ đếm cột (không có ô thêm nhóm)', (
    tester,
  ) async {
    await pumpBoard(tester, perms: worker);
    final list = tester.widget<ListView>(find.byKey(const Key('board-track')));
    expect((list.physics! as BoardSnapPhysics).count, 4);
  });

  testWidgets('thợ: ⋯ kế hoạch chỉ có ba mục đọc', (tester) async {
    await pumpBoard(tester, perms: worker);
    await tester.tap(find.byTooltip('Tuỳ chọn kế hoạch'));
    await tester.pumpAndSettle();
    expect(find.text('Việc đã lưu trữ'), findsOneWidget);
    expect(find.text('Báo cáo kế hoạch'), findsOneWidget);
    expect(find.text('Sửa tên, mô tả, nền'), findsNothing);
  });

  testWidgets('chế độ tối: rãnh cột theo theme, nền vẫn gradient', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
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
        ],
        child: MaterialApp(
          theme: OmniTheme.dark(TargetPlatform.android),
          home: const PlanBoardPage(planId: planId),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final ctx = tester.element(column('Tiếp nhận'));
    final groove = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: column('Tiếp nhận'),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect(
      (groove.decoration as BoxDecoration).color,
      Theme.of(ctx).colorScheme.surfaceContainerHighest,
    );
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
  final searches = <(String, String?)>[];

  @override
  Future<Paged<Task>> list({
    required String projectId,
    String? search,
    TaskArchiveScope archived = TaskArchiveScope.active,
    int page = 1,
    int perPage = 100,
  }) async {
    searches.add((projectId, search));
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

void _scrollTrackToEnd(WidgetTester tester) {
  final list = tester.widget<ListView>(find.byKey(const Key('board-track')));
  final controller = list.controller!;
  controller.jumpTo(controller.position.maxScrollExtent);
}
