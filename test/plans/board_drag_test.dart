import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/design/tokens/tokens.dart';
import 'package:omni_app/modules/plans/application/plans_providers.dart';
import 'package:omni_app/modules/plans/data/plans_api.dart';
import 'package:omni_app/modules/plans/domain/plan.dart';
import 'package:omni_app/modules/plans/presentation/plan_board_page.dart';
import 'package:omni_app/modules/plans/presentation/widgets/board_column.dart';
import 'package:omni_app/modules/plans/presentation/widgets/board_zoom.dart';
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

/// Giữ thẻ ~400ms để kéo sang cột khác (`AppBoard.dc.html`).
void main() {
  const planId = 'p1';
  const worker = {'tasks.read', 'tasks.write'};

  Plan makePlan([Map<String, Object?> extra = const {}]) => Plan.fromJson({
    'id': planId,
    'name': 'Bảo hành',
    'cover': 'plum-1',
    'sections': [
      {'id': 's1', 'name': 'Tiếp nhận', 'order': 0},
      {'id': 's2', 'name': 'Đang xử lý', 'order': 1},
      {'id': 's3', 'name': 'Chờ linh kiện', 'order': 2},
    ],
    ...extra,
  });

  Task task(
    String id,
    String title,
    String section,
    double order, {
    bool locked = false,
    bool unordered = false,
  }) => Task.fromJson({
    'id': id,
    'title': title,
    'section_id': section,
    // Việc tạo từ app: server không có khoá `order`.
    if (!unordered) 'order': order,
    'locked': locked,
  });

  late _FakeTasksApi tasksApi;
  late List<Task> tasks;

  /// Tăng để mô phỏng một lượt tải lại (realtime) của danh sách việc.
  final reloadTick = StateProvider<int>((_) => 0);

  Future<void> pumpBoard(
    WidgetTester tester, {
    Set<String> perms = worker,
    Plan? plan,
    bool reduceMotion = false,
    bool lockT1 = false,
    bool lockedMiddle = false,
    bool hiddenMiddle = false,
    bool unorderedColumn2 = false,
  }) async {
    tasks = [
      task('t1', 'Bảo hành W106', 's1', 1, locked: lockT1),
      task('t2', 'Kiểm tra đàn Kawai ND21', 's1', 2),
      task('t3', 'Bảo hành Ux kẹt cờ', 's2', 1, unordered: unorderedColumn2),
      // Thẻ khoá nằm GIỮA hai thẻ kéo được.
      if (lockedMiddle) task('t5', 'Thẻ khoá giữa', 's2', 1.5, locked: true),
      // Thẻ không khớp tìm kiếm "à" nằm giữa hai thẻ khớp.
      if (hiddenMiddle) task('t6', 'Chờ linh kiện ẩn', 's2', 1.5),
      task('t4', 'Làm phím CLP920', 's2', 2, unordered: unorderedColumn2),
    ];
    tasksApi = _FakeTasksApi(tasks);
    final thePlan = plan ?? makePlan();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const PlanBoardPage(planId: planId),
        ),
        GoRoute(
          path: '/tasks/:id',
          name: TaskRoutes.detail,
          builder: (_, state) =>
              Scaffold(body: Text('chi tiet ${state.pathParameters['id']}')),
        ),
      ],
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          planProvider(planId).overrideWith((ref) async => thePlan),
          planTasksProvider(planId).overrideWith((ref) async {
            ref.watch(reloadTick);
            return (tasks: tasks, truncated: false);
          }),
          backgroundProvider.overrideWith(FixedBackground.new),
          teamDirectoryProvider.overrideWith(
            (ref) async => const <TeamMember>[],
          ),
          plansApiProvider.overrideWithValue(_FakePlansApi(thePlan)),
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
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder column(String name) => find.byWidgetPredicate(
    (w) => w is BoardColumn && w.section.name == name,
    skipOffstage: false,
  );

  Future<TestGesture> lift(WidgetTester t, String title) async {
    final g = await t.startGesture(t.getCenter(find.text(title)));
    await t.pump(const Duration(milliseconds: 450));
    return g;
  }

  /// Y của dòng tên cột (mọi cột cùng một hàng).
  double headerY(WidgetTester t) => t.getCenter(find.text('Tiếp nhận')).dy;

  Color borderOf(WidgetTester t, String name) =>
      (t
                  .widget<AnimatedContainer>(
                    find.descendant(
                      of: column(name),
                      matching: find.byKey(const Key('column-drop-border')),
                    ),
                  )
                  .decoration!
              as BoxDecoration)
          .border!
          .top
          .color;

  /// Chỉ cột [name] sáng viền đích.
  void expectHot(WidgetTester t, String name) {
    final primary = Theme.of(t.element(column(name))).colorScheme.primary;
    for (final other in ['Tiếp nhận', 'Đang xử lý', 'Chờ linh kiện']) {
      expect(
        borderOf(t, other),
        other == name ? primary : Colors.transparent,
        reason: other,
      );
    }
  }

  Offset aboveFirstOfColumn2(WidgetTester t) =>
      Offset(340, t.getTopLeft(find.text('Bảo hành Ux kẹt cờ')).dy - 10);

  testWidgets(
    'giữ 450ms rồi kéo sang cột 2 phía trên thẻ đầu → PUT {section_id: s2, order: 0}',
    (t) async {
      await pumpBoard(t);
      final g = await lift(t, 'Bảo hành W106');
      await g.moveTo(aboveFirstOfColumn2(t));
      await t.pump();
      expect(find.text('Thả vào “Đang xử lý”'), findsOneWidget);
      await g.up();
      await t.pumpAndSettle();

      expect(tasksApi.moves.single, ('t1', 's2', 0.0));
    },
  );

  testWidgets('thả giữa hai thẻ cột 2 → order là trung bình', (t) async {
    await pumpBoard(t);
    final g = await lift(t, 'Bảo hành W106');
    final a = t.getCenter(find.text('Bảo hành Ux kẹt cờ')).dy;
    final b = t.getCenter(find.text('Làm phím CLP920')).dy;
    await g.moveTo(Offset(340, (a + b) / 2));
    await t.pump();
    await g.up();
    await t.pumpAndSettle();

    expect(tasksApi.moves.single, ('t1', 's2', 1.5));
  });

  testWidgets('hàng xóm chưa có order trên server (việc tạo từ app) → chỉ gửi '
      'section_id', (t) async {
    await pumpBoard(t, unorderedColumn2: true);
    final g = await lift(t, 'Bảo hành W106');
    final a = t.getCenter(find.text('Bảo hành Ux kẹt cờ')).dy;
    final b = t.getCenter(find.text('Làm phím CLP920')).dy;
    await g.moveTo(Offset(340, (a + b) / 2));
    await t.pump();
    await g.up();
    await t.pumpAndSettle();

    expect(tasksApi.moves.single, ('t1', 's2', null));
  });

  testWidgets('cột đang rê có viền primary 2px + đúng một ô chỗ trống', (
    t,
  ) async {
    await pumpBoard(t);
    final g = await lift(t, 'Bảo hành W106');

    // Cùng-cột cũng có ô chỗ trống để cho biết vị trí sắp xếp mới.
    await g.moveBy(const Offset(0, 8));
    await t.pump(const Duration(milliseconds: 250));
    expect(find.byKey(const Key('drop-placeholder')), findsOneWidget);

    await g.moveTo(aboveFirstOfColumn2(t));
    await t.pump(const Duration(milliseconds: 250));
    expect(find.byKey(const Key('drop-placeholder')), findsOneWidget);
    expect(t.getSize(find.byKey(const Key('drop-placeholder'))).height, 64);
    final scheme = Theme.of(t.element(column('Đang xử lý'))).colorScheme;
    final border =
        (t
                    .widget<AnimatedContainer>(
                      find.descendant(
                        of: column('Đang xử lý'),
                        matching: find.byKey(const Key('column-drop-border')),
                      ),
                    )
                    .decoration!
                as BoxDecoration)
            .border!
            .top;
    expect(border.width, 2);
    expect(border.color, scheme.primary);
    final fill =
        (t
                    .widget<AnimatedContainer>(
                      find
                          .descendant(
                            of: column('Đang xử lý'),
                            matching: find.byType(AnimatedContainer),
                          )
                          .first,
                    )
                    .decoration!
                as BoxDecoration)
            .color;
    expect(
      fill,
      OmniTaskTones.of(t.element(column('Đang xử lý'))).today.background,
    );

    // Cột gốc đã thôi sáng.
    final source =
        (t
                    .widget<AnimatedContainer>(
                      find.descendant(
                        of: column('Tiếp nhận'),
                        matching: find.byKey(const Key('column-drop-border')),
                      ),
                    )
                    .decoration!
                as BoxDecoration)
            .border!
            .top;
    expect(source.color, Colors.transparent);
    expect(
      find.descendant(
        of: column('Tiếp nhận'),
        matching: find.byKey(const Key('drop-placeholder')),
      ),
      findsNothing,
    );
    await g.up();
    await t.pumpAndSettle();
  });

  testWidgets('thả xuống vị trí khác trong cùng nhóm → cập nhật order', (
    t,
  ) async {
    await pumpBoard(t);
    final g = await lift(t, 'Bảo hành W106');
    await g.moveTo(
      t.getCenter(find.text('Kiểm tra đàn Kawai ND21')) + const Offset(0, 30),
    );
    await t.pump();
    await g.up();
    await t.pumpAndSettle();

    expect(tasksApi.moves.single, ('t1', 's1', 3.0));
  });

  testWidgets('thả lại đúng vị trí cũ → không gọi API', (t) async {
    await pumpBoard(t);
    final g = await lift(t, 'Bảo hành W106');
    await g.moveTo(
      t.getCenter(find.text('Kiểm tra đàn Kawai ND21')) - const Offset(0, 80),
    );
    await t.pump();
    await g.up();
    await t.pumpAndSettle();

    expect(tasksApi.moves, isEmpty);
  });

  testWidgets('thả ra ngoài mọi cột → không gọi API, hết viền', (t) async {
    await pumpBoard(t);
    final g = await lift(t, 'Bảo hành W106');
    await g.moveTo(const Offset(150, 800));
    await t.pump();
    await g.up();
    await t.pumpAndSettle();

    expect(tasksApi.moves, isEmpty);
    expect(find.byKey(const Key('drag-feedback')), findsNothing);
  });

  testWidgets('chạm nhanh (không giữ) vẫn mở chi tiết', (t) async {
    await pumpBoard(t);
    await t.tap(find.text('Bảo hành W106'));
    await t.pumpAndSettle();

    expect(find.text('chi tiet t1'), findsOneWidget);
  });

  testWidgets('giữ < 400ms rồi kéo ngang → dải cuộn, không nhấc thẻ', (
    t,
  ) async {
    await pumpBoard(t);
    final track = find.byKey(const Key('board-track'));
    final controller = t.widget<ListView>(track).controller!;
    expect(controller.offset, 0);

    final g = await t.startGesture(t.getCenter(find.text('Bảo hành W106')));
    await t.pump(const Duration(milliseconds: 200));
    for (var i = 0; i < 8; i++) {
      await g.moveBy(const Offset(-30, 0));
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(find.byKey(const Key('drag-feedback')), findsNothing);
    expect(controller.offset, greaterThan(0));
    await g.up();
    await t.pumpAndSettle();
  });

  testWidgets('giữ ở mép phải 750ms → dải sang cột 2 (offset = '
      'BoardSnapPhysics.offsetOf(1)); đích đổi sang cột đang dưới ngón, thả → '
      'thẻ vào cột đó', (t) async {
    await pumpBoard(t);
    final controller = t
        .widget<ListView>(find.byKey(const Key('board-track')))
        .controller!;
    final g = await lift(t, 'Bảo hành W106');
    // Ngang đầu cột: cột nào ở dưới ngón cũng chứa điểm này (kể cả cột rỗng).
    await g.moveTo(Offset(385, headerY(t)));
    await t.pump();
    expect(find.text('Thả vào “Đang xử lý”'), findsOneWidget);
    final glow = t.widget<AnimatedOpacity>(
      find.byKey(const Key('edge-glow-right')),
    );
    expect(glow.opacity, 1);
    expect(
      t
          .widget<AnimatedOpacity>(find.byKey(const Key('edge-glow-left')))
          .opacity,
      0,
    );

    await t.pump(const Duration(milliseconds: 750));
    await t.pump(const Duration(milliseconds: 400));

    expect(
      controller.offset,
      moreOrLessEquals(BoardSnapPhysics.offsetOf(1, controller.position)),
    );
    // Ngón đứng yên nhưng dải đã trượt: dưới ngón giờ là "Chờ linh kiện".
    await t.pump();
    expect(find.text('Thả vào “Chờ linh kiện”'), findsOneWidget);
    expectHot(t, 'Chờ linh kiện');
    await g.up();
    await t.pumpAndSettle();
    // Cột rỗng: không hàng xóm → chỉ section_id.
    expect(tasksApi.moves.single, ('t1', 's3', null));
  });

  testWidgets('rời vùng mép trước 700ms → không tự trượt', (t) async {
    await pumpBoard(t);
    final controller = t
        .widget<ListView>(find.byKey(const Key('board-track')))
        .controller!;
    final g = await lift(t, 'Bảo hành W106');
    await g.moveTo(const Offset(385, 400));
    await t.pump(const Duration(milliseconds: 500));
    await g.moveTo(const Offset(200, 400));
    await t.pump(const Duration(milliseconds: 1500));

    expect(controller.offset, 0);
    await g.up();
    await t.pumpAndSettle();
  });

  testWidgets('lạc quan: sau khi thả thẻ ở cột 2 ngay; API ném 422 "Chưa qua '
      'được QC" → thẻ về cột 1 + SnackBar', (t) async {
    await pumpBoard(t);
    tasksApi.gate = Completer<void>();
    final g = await lift(t, 'Bảo hành W106');
    await g.moveTo(aboveFirstOfColumn2(t));
    await t.pump();
    await g.up();
    await t.pump();
    await t.pump();

    Finder inColumn(String name) => find.descendant(
      of: column(name),
      matching: find.text('Bảo hành W106'),
      skipOffstage: false,
    );
    expect(inColumn('Đang xử lý'), findsOneWidget);
    expect(inColumn('Tiếp nhận'), findsNothing);

    tasksApi.gate!.completeError(const ValidationException('Chưa qua được QC'));
    await t.pumpAndSettle();

    expect(inColumn('Tiếp nhận'), findsOneWidget);
    expect(inColumn('Đang xử lý'), findsNothing);
    expect(find.text('Chưa qua được QC'), findsOneWidget);
  });

  testWidgets('423 việc bị khoá → SnackBar câu server', (t) async {
    await pumpBoard(t);
    tasksApi.error = const RequestRejectedException(
      'Việc đang bị khoá, không chuyển được.',
      code: '423',
    );
    final g = await lift(t, 'Bảo hành W106');
    await g.moveTo(aboveFirstOfColumn2(t));
    await t.pump();
    await g.up();
    await t.pumpAndSettle();

    expect(find.text('Việc đang bị khoá, không chuyển được.'), findsOneWidget);
  });

  testWidgets('thành công → thẻ ở lại cột 2 (không bật về)', (t) async {
    await pumpBoard(t);
    final g = await lift(t, 'Bảo hành W106');
    await g.moveTo(aboveFirstOfColumn2(t));
    await t.pump();
    await g.up();
    await t.pumpAndSettle();

    expect(
      find.descendant(
        of: column('Đang xử lý'),
        matching: find.text('Bảo hành W106'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
  });

  group('không kéo được', () {
    Future<void> expectNoLift(WidgetTester t, String title) async {
      final g = await lift(t, title);
      await g.moveTo(const Offset(340, 300));
      await t.pump();
      expect(find.byKey(const Key('drag-feedback')), findsNothing);
      await g.up();
      await t.pumpAndSettle();
      expect(tasksApi.moves, isEmpty);
    }

    testWidgets('việc locked', (t) async {
      await pumpBoard(t, lockT1: true);
      await expectNoLift(t, 'Bảo hành W106');
      // Thẻ khác trong cùng bảng vẫn kéo được.
      expect(find.byType(LongPressDraggable<Task>), findsWidgets);
    });

    testWidgets('chỉ tasks.read', (t) async {
      await pumpBoard(t, perms: const {'tasks.read'});
      expect(find.byType(LongPressDraggable<Task>), findsNothing);
      await expectNoLift(t, 'Bảo hành W106');
    });

    testWidgets('vai viewer ghi rõ (member_roles {u-me: viewer})', (t) async {
      await pumpBoard(
        t,
        plan: makePlan(const {
          'member_ids': ['u-me'],
          'member_roles': {'u-me': 'viewer'},
        }),
      );
      expect(find.byType(LongPressDraggable<Task>), findsNothing);
      await expectNoLift(t, 'Bảo hành W106');
    });
  });

  testWidgets(
    'người ngoài danh sách thành viên (không vai) vẫn kéo được (R2)',
    (t) async {
      await pumpBoard(
        t,
        plan: makePlan(const {
          'owner_id': 'u-other',
          'member_ids': ['u-other'],
          'member_roles': {'u-other': 'owner'},
        }),
      );
      expect(find.byType(LongPressDraggable<Task>), findsWidgets);
      final g = await lift(t, 'Bảo hành W106');
      await g.moveTo(aboveFirstOfColumn2(t));
      await t.pump();
      await g.up();
      await t.pumpAndSettle();

      expect(tasksApi.moves.single, ('t1', 's2', 0.0));
    },
  );

  testWidgets(
    'cột đích có thẻ khoá ở giữa: thả dưới thẻ cuối → order = cuối + 1',
    (t) async {
      await pumpBoard(t, lockedMiddle: true);
      final g = await lift(t, 'Bảo hành W106');
      await g.moveTo(
        Offset(340, t.getCenter(find.text('Làm phím CLP920')).dy + 60),
      );
      await t.pump();
      await g.up();
      await t.pumpAndSettle();

      expect(tasksApi.moves.single, ('t1', 's2', 3.0));
    },
  );

  testWidgets('cột đích có thẻ khoá ở giữa: thả trên thẻ khoá → order giữa thẻ '
      'trước và thẻ khoá', (t) async {
    await pumpBoard(t, lockedMiddle: true);
    final g = await lift(t, 'Bảo hành W106');
    // Trên tâm thẻ khoá, dưới tâm thẻ đầu.
    await g.moveTo(
      Offset(340, t.getCenter(find.text('Thẻ khoá giữa')).dy - 10),
    );
    await t.pump();
    await g.up();
    await t.pumpAndSettle();

    expect(tasksApi.moves.single, ('t1', 's2', 1.25));
  });

  testWidgets('đang tìm: order tính trên cả cột đích, ngay sau thẻ thấy được '
      'phía trên', (t) async {
    await pumpBoard(t, hiddenMiddle: true);
    await t.tap(find.byTooltip('Tìm trong kế hoạch'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'à');
    await t.pump(const Duration(milliseconds: 350));
    await t.pumpAndSettle();
    expect(find.text('Chờ linh kiện ẩn'), findsNothing);

    final g = await lift(t, 'Bảo hành W106');
    final a = t.getCenter(find.text('Bảo hành Ux kẹt cờ')).dy;
    final b = t.getCenter(find.text('Làm phím CLP920')).dy;
    await g.moveTo(Offset(340, (a + b) / 2));
    await t.pump();
    await g.up();
    await t.pumpAndSettle();

    // Giữa t3 (1) và thẻ ẩn kế tiếp (1.5), không phải giữa t3 và t4 (1.5 trùng
    // thẻ ẩn).
    expect(tasksApi.moves.single, ('t1', 's2', 1.25));
  });

  testWidgets('ngón thứ hai nhấc lên không kết thúc lượt kéo', (t) async {
    await pumpBoard(t);
    final g = await lift(t, 'Bảo hành W106');
    await g.moveTo(aboveFirstOfColumn2(t));
    await t.pump();
    expect(find.byKey(const Key('drop-placeholder')), findsOneWidget);

    final second = await t.startGesture(const Offset(200, 760), pointer: 7);
    await second.up();
    await t.pump();
    expect(find.byKey(const Key('drag-feedback')), findsOneWidget);
    expect(find.byKey(const Key('drop-placeholder')), findsOneWidget);

    await g.up();
    await t.pumpAndSettle();

    expect(tasksApi.moves.single, ('t1', 's2', 0.0));
  });

  testWidgets('lượt tải lại đến trước khi PUT xong (thẻ còn ở nhóm cũ) không '
      'làm thẻ bật về', (t) async {
    await pumpBoard(t);
    tasksApi.gate = Completer<void>();
    final g = await lift(t, 'Bảo hành W106');
    await g.moveTo(aboveFirstOfColumn2(t));
    await t.pump();
    await g.up();
    await t.pump();

    Finder inColumn(String name) => find.descendant(
      of: column(name),
      matching: find.text('Bảo hành W106'),
      skipOffstage: false,
    );
    expect(inColumn('Đang xử lý'), findsOneWidget);

    // Realtime tải lại: server chưa kịp ghi, thẻ vẫn ở s1.
    ProviderScope.containerOf(
      t.element(find.byType(PlanBoardPage)),
    ).read(reloadTick.notifier).state++;
    await t.pump();
    await t.pump();
    expect(inColumn('Đang xử lý'), findsOneWidget);
    expect(inColumn('Tiếp nhận'), findsNothing);

    tasksApi.gate!.complete();
    await t.pumpAndSettle();
  });

  testWidgets('ô tích vẫn tích được trong LongPressDraggable, không nhấc thẻ', (
    t,
  ) async {
    await pumpBoard(t);
    expect(find.byType(LongPressDraggable<Task>), findsWidgets);

    await t.tap(find.byKey(const ValueKey('tick-target')).first);
    await t.pumpAndSettle();

    expect(tasksApi.statuses, [('t1', 'done')]);
    expect(find.byKey(const Key('drag-feedback')), findsNothing);
    expect(find.text('chi tiet t1'), findsNothing);
  });

  testWidgets('chế độ thu nhỏ: không có LongPressDraggable', (t) async {
    await pumpBoard(t);
    expect(find.byType(LongPressDraggable<Task>), findsWidgets);
    await t.tap(find.byType(BoardZoomButton));
    await t.pumpAndSettle();

    expect(find.byType(LongPressDraggable<Task>), findsNothing);
  });

  testWidgets('bản nổi: dòng 1 là tên việc, rộng 268, nghiêng và phóng', (
    t,
  ) async {
    await pumpBoard(t);
    final g = await lift(t, 'Bảo hành W106');
    await g.moveTo(const Offset(150, 400));
    await t.pump(const Duration(milliseconds: 250));

    final feedback = find.byKey(const Key('drag-feedback'));
    expect(t.getSize(feedback).width, 268);
    // Ngón tay nằm ở (134, 30) trong bản nổi: bản nổi lệch (−134, −30).
    expect(t.getTopLeft(feedback), const Offset(150 - 134, 400 - 30));
    expect(
      find.descendant(of: feedback, matching: find.text('Bảo hành W106')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: feedback, matching: find.byType(Transform)),
      findsWidgets,
    );
    await g.up();
    await t.pumpAndSettle();
  });

  testWidgets('giảm chuyển động: bản nổi không Transform xoay/phóng; tự trượt '
      'dùng jumpTo (không còn khung sau một pump)', (t) async {
    await pumpBoard(t, reduceMotion: true);
    final controller = t
        .widget<ListView>(find.byKey(const Key('board-track')))
        .controller!;
    final g = await lift(t, 'Bảo hành W106');
    await g.moveTo(Offset(385, headerY(t)));
    await t.pump();

    expect(
      find.descendant(
        of: find.byKey(const Key('drag-feedback')),
        matching: find.byType(Transform),
      ),
      findsNothing,
    );

    await t.pump(const Duration(milliseconds: 750));
    expect(
      controller.offset,
      moreOrLessEquals(BoardSnapPhysics.offsetOf(1, controller.position)),
    );
    // jumpTo cũng phải dò lại cột dưới ngón.
    await t.pump();
    expect(find.text('Thả vào “Chờ linh kiện”'), findsOneWidget);
    expectHot(t, 'Chờ linh kiện');
    await g.up();
    await t.pumpAndSettle();
    expect(tasksApi.moves.single, ('t1', 's3', null));
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
  final statuses = <(String, String)>[];

  @override
  Future<Paged<Task>> list({
    required String projectId,
    String? search,
    TaskArchiveScope archived = TaskArchiveScope.active,
    int page = 1,
    int perPage = 100,
  }) async {
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
  Future<Task> setStatus(String taskId, String status) async {
    statuses.add((taskId, status));

    return _tasks.firstWhere((t) => t.id == taskId);
  }

  /// Có thì `moveOnBoard` chờ nó (và ném lỗi nếu nó hoàn tất bằng lỗi).
  Completer<void>? gate;

  /// Có thì `moveOnBoard` ném nó.
  AppException? error;

  @override
  Future<Task> moveOnBoard(
    String taskId, {
    required String sectionId,
    double? order,
  }) async {
    moves.add((taskId, sectionId, order));
    if (gate case final g?) await g.future;
    if (error case final e?) throw e;

    return _tasks.firstWhere((t) => t.id == taskId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
