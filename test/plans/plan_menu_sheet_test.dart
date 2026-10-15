import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:go_router/go_router.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/plans/application/plans_providers.dart';
import 'package:omni_app/modules/plans/data/plans_api.dart';
import 'package:omni_app/modules/plans/domain/plan.dart';
import 'package:omni_app/modules/plans/domain/team.dart';
import 'package:omni_app/modules/plans/domain/workshop_kpi.dart';
import 'package:omni_app/modules/plans/presentation/archived_tasks_page.dart';
import 'package:omni_app/modules/plans/presentation/plan_board_page.dart';
import 'package:omni_app/modules/plans/presentation/plan_files_page.dart';
import 'package:omni_app/modules/plans/presentation/plan_report_page.dart';
import 'package:omni_app/modules/plans/presentation/widgets/plan_menu_sheet.dart';
import 'package:omni_app/modules/plans/routes.dart';
import 'package:omni_app/modules/settings/application/appearance_providers.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/data/tasks_api.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/domain/task_label.dart';
import 'package:omni_app/modules/tasks/domain/task_permissions.dart';
import 'package:omni_app/modules/team/team.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

import '../support/fixed_background.dart';

/// Menu kế hoạch (`PlanMenu.dc.html` / `Board.dc.html` `isMenu`): popover neo
/// tại nút `…`, chia nhóm theo quyền và các lượt ghi đi đúng khoá.
void main() {
  const planId = 'p1';
  const managerPerms = {'tasks.read', 'tasks.write', 'system_options.read'};
  const workerPerms = {'tasks.read', 'tasks.write', 'system_options.read'};
  const assignerPerms = {
    'tasks.read',
    'tasks.write',
    'tasks.projects.manage.all',
    'system_options.read',
  };

  Map<String, dynamic> planJson({
    String role = 'manager',
    String status = 'active',
  }) => {
    'id': planId,
    'name': 'Bảo hành',
    'team_id': 't1',
    'team_name': 'Tổ kỹ thuật',
    'cover': 'plum-1',
    'status': status,
    'owner_id': 'u-owner',
    'member_ids': ['u-me', 'u-2'],
    'member_roles': {'u-me': role},
    'sections': [
      {'id': 's1', 'name': 'Tiếp nhận', 'order': 0},
    ],
  };

  late _FakePlansApi api;
  late _ArchivedApi tasksApi;

  Future<void> pump(
    WidgetTester tester, {
    String role = 'manager',
    String status = 'active',
    Set<String> perms = managerPerms,
    int archived = 12,
    bool archivedFails = false,
  }) async {
    tasksApi = _ArchivedApi(archived, fail: archivedFails);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    api = _FakePlansApi(Plan.fromJson(planJson(role: role, status: status)));
    final router = GoRouter(
      initialLocation: '/plans/$planId',
      routes: [
        GoRoute(
          path: '/teams',
          name: PlanRoutes.teams,
          builder: (_, _) => const Scaffold(body: Text('tab viec')),
        ),
        GoRoute(
          path: '/plans/:id',
          name: PlanRoutes.board,
          builder: (_, state) =>
              PlanBoardPage(planId: state.pathParameters['id']!),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          plansApiProvider.overrideWithValue(api),
          tasksApiProvider.overrideWithValue(tasksApi),
          planTasksProvider.overrideWith(
            (ref, id) async => (tasks: <Task>[], truncated: false),
          ),
          teamsWithPlansProvider.overrideWith(
            (ref) async => const [
              TeamWithPlans(
                team: Team(id: 't1', name: 'Tổ kỹ thuật'),
                plans: [],
              ),
              TeamWithPlans(
                team: Team(id: 't2', name: 'Tổ sơn'),
                plans: [],
              ),
            ],
          ),
          taskLabelsProvider.overrideWith(
            (ref) async => const [
              TaskLabel(
                id: 'o1',
                code: 'khan_cap',
                label: 'Khẩn cấp',
                color: '#B42318',
              ),
            ],
          ),
          backgroundProvider.overrideWith(FixedBackground.new),
          teamDirectoryProvider.overrideWith(
            (ref) async => const [
              TeamMember(
                membershipId: 'm0',
                userId: 'u-owner',
                name: 'Trung Nguyên',
              ),
            ],
          ),
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
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Tuỳ chọn kế hoạch'));
    await tester.pumpAndSettle();
  }

  testWidgets('hơn 500 việc lưu trữ: số ghi "500+", không phải "500"', (
    tester,
  ) async {
    await pump(tester, archived: 520);
    await openMenu(tester);

    expect(find.text('500+'), findsOneWidget);
    expect(find.text('500'), findsNothing);
  });

  testWidgets('(a) quản lý: menu neo đủ ba nhóm, không mục Nhóm 2', (
    tester,
  ) async {
    await pump(tester);
    await openMenu(tester);

    expect(find.byType(PlanAnchoredMenu), findsOneWidget);
    expect(find.byKey(const Key('plan-actions-menu')), findsOneWidget);
    for (final label in [
      'Sửa tên, mô tả, nền',
      'Thành viên',
      'Nhãn màu',
      'Trường tuỳ chỉnh',
      'Sao chép kế hoạch',
      'Chuyển sang team khác',
      'Việc đã lưu trữ',
      'Tệp đính kèm',
      'Báo cáo kế hoạch',
      'Đóng kế hoạch',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    // Ba mục đọc nằm cuối nhóm 2, sau "Chuyển sang team khác".
    expect(
      find.descendant(
        of: find.byKey(const Key('plan-menu-group-1')),
        matching: find.text('Báo cáo kế hoạch'),
      ),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.text('Việc đã lưu trữ')).dy,
      greaterThan(tester.getTopLeft(find.text('Chuyển sang team khác')).dy),
    );
    // Số việc đã lưu trữ ở bên phải dòng.
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Việc đã lưu trữ'),
          matching: find.byType(InkWell),
        ),
        matching: find.text('12'),
      ),
      findsOneWidget,
    );
    expect(tasksApi.scopes, [TaskArchiveScope.archived]);
    // Số thành viên: chủ + hai người.
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Thành viên'),
          matching: find.byType(InkWell),
        ),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );
    for (final hidden in [
      'Chuyển chủ kế hoạch',
      'Sao chép liên kết',
      'Mở lại kế hoạch',
      'Xoá kế hoạch',
      'Sửa nhóm việc',
    ]) {
      expect(find.text(hidden), findsNothing, reason: hidden);
    }
    expect(find.byKey(const Key('plan-menu-group-0')), findsOneWidget);
    expect(find.byKey(const Key('plan-menu-group-1')), findsOneWidget);
    expect(find.byKey(const Key('plan-menu-group-2')), findsOneWidget);
  });

  testWidgets('(a) cùng mẫu menu + Team: neo tại nút, dòng 52', (tester) async {
    await pump(tester);
    final button = find.byTooltip('Tuỳ chọn kế hoạch');
    final buttonBottom = tester.getBottomRight(button).dy;
    await openMenu(tester);

    final menu = find.byKey(const Key('plan-actions-menu'));
    expect(tester.getTopLeft(menu).dy, greaterThan(buttonBottom));
    expect(tester.getSize(menu).width, 344);
    expect(
      tester
          .getSize(
            find.ancestor(
              of: find.text('Nhãn màu'),
              matching: find.byType(InkWell),
            ),
          )
          .height,
      52,
    );
    final close = tester.widget<Text>(find.text('Đóng kế hoạch'));
    expect(
      close.style?.color,
      Theme.of(tester.element(menu)).colorScheme.error,
    );
    expect(close.style?.fontSize, 15);
    expect(close.style?.fontWeight, FontWeight.w500);
    expect(find.byKey(const Key('sheet-handle')), findsNothing);
    expect(find.byKey(const Key('plan-menu-cover')), findsNothing);
  });

  testWidgets('(a)(d) thợ: "Nhãn màu" chỉ xem cùng ba mục đọc', (tester) async {
    await pump(tester, role: 'member', perms: workerPerms);
    await openMenu(tester);

    for (final label in [
      'Nhãn màu',
      'Việc đã lưu trữ',
      'Tệp đính kèm',
      'Báo cáo kế hoạch',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    for (final hidden in [
      'Sửa tên, mô tả, nền',
      'Thành viên',
      'Trường tuỳ chỉnh',
      'Sao chép kế hoạch',
      'Chuyển sang team khác',
      'Đóng kế hoạch',
    ]) {
      expect(find.text(hidden), findsNothing, reason: hidden);
    }
    expect(find.byKey(const Key('plan-menu-group-1')), findsOneWidget);
    expect(find.byKey(const Key('plan-menu-group-2')), findsNothing);

    await tester.tap(find.text('Nhãn màu'));
    await tester.pumpAndSettle();
    expect(find.text('Khẩn cấp'), findsOneWidget);
    expect(find.text('Nhãn dùng chung cho cả công ty'), findsOneWidget);
    expect(find.bySemanticsLabel('Sửa nhãn Khẩn cấp'), findsNothing);
    expect(find.text('Nhãn mới…'), findsNothing);
  });

  testWidgets('chỉ có tasks.read: vẫn có ⋯ với ba mục đọc', (tester) async {
    await pump(tester, role: 'member', perms: const {'tasks.read'});
    await openMenu(tester);

    for (final label in [
      'Việc đã lưu trữ',
      'Tệp đính kèm',
      'Báo cáo kế hoạch',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Nhãn màu'), findsNothing);
    expect(find.byKey(const Key('plan-menu-group-1')), findsNothing);
  });

  testWidgets('đếm việc lưu trữ lỗi: không số, menu vẫn dùng được', (
    tester,
  ) async {
    await pump(tester, archivedFails: true);
    await openMenu(tester);

    final row = find.ancestor(
      of: find.text('Việc đã lưu trữ'),
      matching: find.byType(InkWell),
    );
    expect(
      find.descendant(of: row, matching: find.byType(Text)),
      findsOneWidget,
    );
    await tester.tap(find.text('Sửa tên, mô tả, nền'));
    await tester.pumpAndSettle();
    expect(find.byType(PlanMenuSheet), findsNothing);
  });

  testWidgets('(a) "Việc đã lưu trữ" mở trang, thành viên có "Khôi phục"', (
    tester,
  ) async {
    await pump(tester, role: 'member', perms: workerPerms, archived: 2);
    await openMenu(tester);
    await tester.tap(find.text('Việc đã lưu trữ'));
    await tester.pumpAndSettle();

    expect(find.byType(ArchivedTasksPage), findsOneWidget);
    expect(find.text('Việc lưu trữ 0'), findsOneWidget);
    expect(find.text('Khôi phục'), findsNWidgets(2));
  });

  testWidgets('(d) người xem kế hoạch: không "Khôi phục", không "Xoá tệp"', (
    tester,
  ) async {
    await pump(tester, role: 'viewer', perms: workerPerms, archived: 2);
    await openMenu(tester);
    await tester.tap(find.text('Việc đã lưu trữ'));
    await tester.pumpAndSettle();

    expect(find.text('Việc lưu trữ 0'), findsOneWidget);
    expect(find.text('Khôi phục'), findsNothing);
    final page = tester.widget<ArchivedTasksPage>(
      find.byType(ArchivedTasksPage),
    );
    expect(page.canRestore, isFalse);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await openMenu(tester);
    await tester.tap(find.text('Tệp đính kèm'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<PlanFilesPage>(find.byType(PlanFilesPage)).canDelete,
      isFalse,
    );
  });

  testWidgets('"Tệp đính kèm" và "Báo cáo kế hoạch" mở đúng trang', (
    tester,
  ) async {
    await pump(tester);
    await openMenu(tester);
    await tester.tap(find.text('Tệp đính kèm'));
    await tester.pumpAndSettle();
    expect(find.byType(PlanFilesPage), findsOneWidget);
    expect(
      tester.widget<PlanFilesPage>(find.byType(PlanFilesPage)).canDelete,
      isTrue,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    await openMenu(tester);
    await tester.tap(find.text('Báo cáo kế hoạch'));
    await tester.pumpAndSettle();
    expect(find.byType(PlanReportPage), findsOneWidget);
    expect(api.kpis.toSet(), {planId});
  });

  testWidgets('(g) đóng kế hoạch: hỏi lại, gửi status done, về tab Việc', (
    tester,
  ) async {
    await pump(tester);
    await openMenu(tester);
    await tester.tap(find.text('Đóng kế hoạch'));
    await tester.pumpAndSettle();

    expect(find.text('Đóng kế hoạch “Bảo hành”?'), findsOneWidget);
    expect(api.patches, isEmpty);
    await tester.tap(find.widgetWithText(TextButton, 'Đóng kế hoạch'));
    await tester.pumpAndSettle();

    expect(api.patches.single.toJson(), {'status': 'done'});
    expect(find.text('tab viec'), findsOneWidget);
  });

  testWidgets('kế hoạch đã đóng: "Mở lại kế hoạch" gửi status active', (
    tester,
  ) async {
    await pump(tester, status: 'done');
    await openMenu(tester);

    expect(find.text('Đóng kế hoạch'), findsNothing);
    await tester.tap(find.text('Mở lại kế hoạch'));
    await tester.pumpAndSettle();

    expect(api.patches.single.toJson(), {'status': 'active'});
  });

  testWidgets('(f) sao chép: gọi /copy đúng khoá rồi mở bảng mới', (
    tester,
  ) async {
    await pump(tester);
    await openMenu(tester);
    await tester.tap(find.text('Sao chép kế hoạch'));
    await tester.pumpAndSettle();

    expect(find.text('Bản sao của Bảo hành'), findsOneWidget);
    await tester.tap(find.text('Lưu làm mẫu'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Sao chép'));
    await tester.pumpAndSettle();

    expect(api.copies.single, (
      planId: planId,
      name: 'Bản sao của Bảo hành',
      copyTasks: true,
      asTemplate: true,
    ));
    // Mẫu không mở được trong app: ở lại bảng, nói rõ chỗ dùng mẫu.
    expect(find.text('Bản sao mới'), findsNothing);
    expect(find.text('Bảo hành'), findsWidgets);
    expect(find.text('Đã lưu làm mẫu. Dùng mẫu trên web.'), findsOneWidget);
  });

  testWidgets('sao chép thường (không làm mẫu) mở bảng mới', (tester) async {
    await pump(tester);
    await openMenu(tester);
    await tester.tap(find.text('Sao chép kế hoạch'));
    await tester.pumpAndSettle();

    expect(find.text('Mẫu chỉ dùng được trên web.'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Sao chép'));
    await tester.pumpAndSettle();

    expect(api.copies.single.asTemplate, isFalse);
    expect(find.text('Bản sao mới'), findsOneWidget);
  });

  testWidgets('kế hoạch đã đóng: dải "Kế hoạch đã đóng · Mở lại" cho quản lý', (
    tester,
  ) async {
    await pump(tester, status: 'done');

    expect(find.text('Kế hoạch đã đóng'), findsOneWidget);
    final reopen = find.widgetWithText(TextButton, 'Mở lại');
    expect(reopen, findsOneWidget);
    expect(tester.getSize(reopen).height, greaterThanOrEqualTo(44));
    await tester.tap(reopen);
    await tester.pumpAndSettle();

    expect(api.patches.single.toJson(), {'status': 'active'});
    expect(find.text('Kế hoạch đã đóng'), findsNothing);
  });

  testWidgets('kế hoạch đã đóng: thợ thấy dải nhưng không có "Mở lại"', (
    tester,
  ) async {
    await pump(tester, status: 'archived', role: 'member', perms: workerPerms);

    expect(find.text('Kế hoạch đã lưu trữ'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Mở lại'), findsNothing);
  });

  testWidgets('chuyển team: chọn team khác gửi team_id', (tester) async {
    await pump(tester);
    await openMenu(tester);
    await tester.tap(find.text('Chuyển sang team khác'));
    await tester.pumpAndSettle();

    expect(find.text('Không team'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Tổ kỹ thuật.*đang chọn')), findsOne);
    await tester.tap(find.text('Tổ sơn'));
    await tester.pumpAndSettle();

    expect(api.patches.single.toJson(), {'team_id': 't2'});
  });

  testWidgets('chuyển team: "Không team" gửi team_id null (clearTeam)', (
    tester,
  ) async {
    await pump(tester);
    await openMenu(tester);
    await tester.tap(find.text('Chuyển sang team khác'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Không team'));
    await tester.pumpAndSettle();

    final sent = api.patches.single;
    expect(sent.clearTeam, isTrue);
    expect(sent.toJson(), {'team_id': null});
  });

  testWidgets('người giao việc: "Xoá kế hoạch" cuối nhóm 3, đỏ, hỏi lại', (
    tester,
  ) async {
    await pump(tester, role: 'member', perms: assignerPerms);
    await openMenu(tester);

    final group = find.byKey(const Key('plan-menu-group-2'));
    expect(
      find.descendant(of: group, matching: find.text('Xoá kế hoạch')),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.text('Xoá kế hoạch')).dy,
      greaterThan(tester.getTopLeft(find.text('Đóng kế hoạch')).dy),
    );
    await tester.tap(find.text('Xoá kế hoạch'));
    await tester.pumpAndSettle();
    expect(find.text('Xoá kế hoạch “Bảo hành”?'), findsOneWidget);
    expect(
      find.textContaining(
        'Khôi phục được (kèm công việc) từ thùng rác trên web',
      ),
      findsOneWidget,
    );
  });

  testWidgets('(i) không còn PopupMenuButton trên bảng', (tester) async {
    await pump(tester);
    expect(find.byType(PopupMenuButton), findsNothing);
    await openMenu(tester);
    expect(find.byType(PopupMenuButton), findsNothing);
  });

  testWidgets('chế độ tối: nền sheet theo scaffold, nhóm theo surface', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final plan = Plan.fromJson(planJson());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          teamDirectoryProvider.overrideWith(
            (ref) async => const <TeamMember>[],
          ),
          archivedTasksProvider.overrideWith(
            (ref, id) async => (tasks: const <Task>[], truncated: false),
          ),
        ],
        child: MaterialApp(
          theme: OmniTheme.dark(TargetPlatform.android),
          home: Scaffold(
            body: PlanMenuSheet(
              plan: plan,
              groups: planMenuGroups(
                plan,
                canManage: true,
                canDelete: false,
                canViewLabels: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final ctx = tester.element(find.byType(PlanMenuSheet));
    final group = tester.widget<Container>(
      find.byKey(const Key('plan-menu-group-0')),
    );
    expect(
      (group.decoration! as BoxDecoration).color,
      Theme.of(ctx).colorScheme.surface,
    );
    expect(find.text('Tổ kỹ thuật'), findsOneWidget);
  });
}

typedef _Copy = ({String planId, String name, bool copyTasks, bool asTemplate});

class _FakePlansApi implements PlansApi {
  _FakePlansApi(this._plan);

  Plan _plan;
  final patches = <PlanPatch>[];
  final copies = <_Copy>[];
  final kpis = <String?>[];

  @override
  Future<WorkshopKpi> kpi({String? planId, DateTime? month}) async {
    kpis.add(planId);
    return WorkshopKpi.fromJson(const {});
  }

  @override
  Future<Plan> plan(String id) async =>
      id == _plan.id ? _plan : Plan.fromJson({'id': id, 'name': 'Bản sao mới'});

  @override
  Future<Plan> updatePlan(String planId, PlanPatch patch) async {
    patches.add(patch);
    _plan = _plan.copyWith(status: patch.status?.name, teamId: patch.teamId);
    return _plan;
  }

  @override
  Future<Plan> copyPlan(
    String planId, {
    required String name,
    bool copyTasks = true,
    bool asTemplate = false,
    DateTime? startDate,
  }) async {
    copies.add((
      planId: planId,
      name: name,
      copyTasks: copyTasks,
      asTemplate: asTemplate,
    ));
    return Plan.fromJson({'id': 'p9', 'name': 'Bản sao mới'});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ArchivedApi implements TasksApi {
  _ArchivedApi(this._count, {this.fail = false});

  final int _count;
  final bool fail;
  final scopes = <TaskArchiveScope>[];

  @override
  Future<Paged<Task>> list({
    required String projectId,
    String? search,
    TaskArchiveScope archived = TaskArchiveScope.active,
    int page = 1,
    int perPage = 100,
  }) async {
    scopes.add(archived);
    if (fail) throw const ServerException('Lỗi máy chủ');
    final start = (page - 1) * perPage;
    final end = (start + perPage).clamp(0, _count);
    return Paged(
      items: [
        for (var i = start; i < end; i++)
          Task.fromJson({
            'id': 'a$i',
            'title': 'Việc lưu trữ $i',
            'archived': true,
          }),
      ],
      pagination: const ApiPagination.empty(),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
