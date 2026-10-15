import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/design/tokens/tokens.dart';
import 'package:omni_app/modules/plans/application/plans_providers.dart';
import 'package:omni_app/modules/plans/data/plans_api.dart';
import 'package:omni_app/modules/plans/domain/plan.dart';
import 'package:omni_app/modules/plans/domain/team.dart';
import 'package:omni_app/modules/plans/presentation/create_plan_page.dart';
import 'package:omni_app/modules/plans/presentation/create_team_page.dart';
import 'package:omni_app/modules/plans/presentation/teams_page.dart';
import 'package:omni_app/modules/plans/presentation/widgets/plan_tile.dart';
import 'package:omni_app/modules/plans/presentation/widgets/team_group.dart';
import 'package:omni_app/modules/plans/presentation/widgets/teams_search_row.dart';
import 'package:omni_app/modules/plans/routes.dart';
import 'package:omni_app/modules/settings/application/appearance_providers.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/domain/task_permissions.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session_controller.dart';

import '../support/fixed_background.dart';

/// Tab Việc mới (`Main.dc.html`, `TeamsAdd.dc.html`): team gập/mở, ô tìm và
/// nút + ở hàng thứ hai của header, menu + bật xuống.
void main() {
  const worker = {'tasks.read', 'tasks.write'};
  const assignerPerms = {
    'tasks.read',
    'tasks.write',
    'tasks.projects.manage.all',
  };

  String? lastPushedRoute;

  Plan plan(
    String name, {
    int total = 10,
    int done = 4,
    int overdue = 0,
    String? cover,
    String? status,
  }) => Plan.fromJson({
    'id': 'id-$name',
    'name': name,
    'cover': ?cover,
    'status': ?status,
    'stats': {'total': total, 'done': done, 'overdue': overdue},
  });

  TeamWithPlans group(
    String name, {
    List<Plan> plans = const [],
    List<Plan> closed = const [],
    bool synthetic = false,
    String? id,
    String? color,
  }) => TeamWithPlans(
    team: Team(id: id ?? 'team-$name', name: name, color: color),
    plans: plans,
    closedPlans: closed,
    synthetic: synthetic,
  );

  final twoTeams = [
    group(
      'Tổ kỹ thuật',
      color: '#0B1A33',
      plans: [
        plan('Bảo hành', total: 12, done: 3, overdue: 2, cover: 'teal-1'),
        plan('Sửa chữa tại nhà', total: 6, done: 0),
      ],
    ),
    group('Kinh doanh', plans: [plan('Sự kiện tháng 10', total: 7, done: 0)]),
  ];

  Widget host({
    List<TeamWithPlans>? groups,
    bool assigner = false,
    bool canCreateTeam = false,
    bool canUpdateTeam = false,
    bool canDeleteTeam = false,
    PlansApi? plansApi,
    bool reduceMotion = false,
    bool dark = false,
  }) {
    final permissions = <String>{
      ...(assigner ? assignerPerms : worker),
      if (canCreateTeam) 'organization.org_units.create',
      if (canUpdateTeam) 'organization.org_units.update',
      if (canDeleteTeam) ...[
        'tasks.projects.delete',
        'organization.org_units.delete',
      ],
    };
    final policy = AccessPolicy(permissions);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const TeamsPage()),
        GoRoute(
          path: '/plans/:id',
          name: PlanRoutes.board,
          builder: (_, state) {
            lastPushedRoute =
                '${PlanRoutes.board}:${state.pathParameters['id']}';
            return const Scaffold(body: Text('trang bang'));
          },
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        backgroundProvider.overrideWith(FixedBackground.new),
        if (plansApi != null) plansApiProvider.overrideWithValue(plansApi),
        teamsWithPlansProvider.overrideWith((ref) async => groups ?? const []),
        taskAccessProvider.overrideWithValue(TaskAccess.of(policy)),
        accessProvider.overrideWithValue(policy),
      ],
      child: MaterialApp.router(
        theme: dark
            ? OmniTheme.dark(TargetPlatform.android)
            : OmniTheme.light(TargetPlatform.android),
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

  setUp(() => lastPushedRoute = null);

  void phone(WidgetTester t) {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
  }

  Finder plus() => find.bySemanticsLabel('Tạo mới');

  Finder header(String team) =>
      find.ancestor(of: find.text(team), matching: find.byType(InkWell)).first;

  // (a)
  testWidgets('team, kế hoạch, "N việc đang mở", "N trễ", "N kế hoạch"', (
    t,
  ) async {
    phone(t);
    await t.pumpWidget(host(groups: twoTeams));
    await t.pumpAndSettle();
    expect(find.text('Tổ kỹ thuật'), findsOneWidget);
    expect(find.text('Kinh doanh'), findsOneWidget);
    expect(find.text('2 kế hoạch'), findsOneWidget);
    expect(find.text('1 kế hoạch'), findsOneWidget);
    // Màn chỉ hiện cấp team lúc vào; kế hoạch không tự bung.
    expect(find.byType(PlanTile), findsNothing);
    await t.tap(header('Tổ kỹ thuật'));
    await t.pumpAndSettle();
    expect(find.text('Bảo hành'), findsOneWidget);
    expect(find.text('9 việc đang mở'), findsOneWidget);
    expect(find.text('2 trễ'), findsOneWidget);
    expect(find.text('6 việc đang mở'), findsOneWidget);
    await t.tap(header('Kinh doanh'));
    await t.pumpAndSettle();
    expect(find.text('7 việc đang mở'), findsOneWidget);
    // Chỉ một dòng có việc trễ.
    expect(find.textContaining('trễ'), findsOneWidget);
    // Ô tìm ở hàng thứ hai của header.
    expect(find.byType(TeamsSearchRow), findsOneWidget);
    expect(find.text('Tìm team, kế hoạch'), findsOneWidget);
  });

  testWidgets(
    'bố cục phân cấp: icon ngữ nghĩa, không avatar/vạch màu/đường cây',
    (t) async {
      phone(t);
      await t.pumpWidget(host(groups: twoTeams, assigner: true));
      await t.pumpAndSettle();
      await t.tap(header('Tổ kỹ thuật'));
      await t.pumpAndSettle();
      expect(t.getSize(find.byType(PlanTile).first).height, 48);
      expect(find.byKey(const Key('plan-tile-icon')), findsWidgets);
      expect(find.byKey(const Key('team-group-icon')), findsNWidgets(2));
      expect(find.byKey(const Key('plan-tile-marker')), findsNothing);
      expect(find.byKey(const Key('team-group-marker')), findsNothing);
      expect(t.getSize(header('Tổ kỹ thuật')).height, 48);
      expect(find.byKey(const Key('plan-tree-rail')), findsNothing);
      expect(
        t.getTopLeft(find.byKey(const Key('plan-tile-icon')).first).dx,
        greaterThan(
          t.getTopLeft(find.byKey(const Key('team-group-icon')).first).dx + 16,
        ),
      );
      expect(t.getSize(find.byKey(const Key('teams-search-box'))).height, 40);
      expect(
        t.getSize(find.byKey(const Key('teams-add-face'))),
        const Size(44, 40),
      );
      expect(
        t.widget<Icon>(find.byKey(const Key('team-group-icon')).first).icon,
        Icons.groups_2_outlined,
      );
      expect(
        t.widget<Icon>(find.byKey(const Key('plan-tile-icon')).first).icon,
        Icons.folder_outlined,
      );
      // Section phẳng sát mép; đường chia tạo nhịp 17 giữa các nhóm.
      final first = t.getRect(find.byType(TeamGroup).at(0));
      final second = t.getRect(find.byType(TeamGroup).at(1));
      expect(second.top - first.bottom, 17);
      expect(first.left, 0);
      final groupMaterial = t.widget<Material>(
        find
            .descendant(
              of: find.byType(TeamGroup).first,
              matching: find.byType(Material),
            )
            .first,
      );
      expect(groupMaterial.shape, isNull);
    },
  );

  // (b)
  testWidgets('mặc định đóng; chạm đầu nhóm mở/đóng và cập nhật semantics', (
    t,
  ) async {
    phone(t);
    final handle = t.ensureSemantics();
    await t.pumpWidget(host(groups: twoTeams));
    await t.pumpAndSettle();
    double turns() => t
        .widget<AnimatedRotation>(
          find.descendant(
            of: header('Tổ kỹ thuật'),
            matching: find.byType(AnimatedRotation),
          ),
        )
        .turns;
    expect(turns(), 0);
    expect(find.text('Bảo hành'), findsNothing);
    expect(
      t.getSemantics(header('Tổ kỹ thuật')),
      matchesSemantics(
        isButton: true,
        hasExpandedState: true,
        isExpanded: false,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
        label: 'Tổ kỹ thuật\n2 kế hoạch',
      ),
    );

    await t.tap(header('Tổ kỹ thuật'));
    await t.pumpAndSettle();
    expect(find.text('Bảo hành'), findsOneWidget);
    expect(find.text('Sự kiện tháng 10'), findsNothing);
    expect(turns(), 0.5);
    expect(
      t.getSemantics(header('Tổ kỹ thuật')),
      matchesSemantics(
        isButton: true,
        hasExpandedState: true,
        isExpanded: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
        label: 'Tổ kỹ thuật\n2 kế hoạch',
      ),
    );

    await t.tap(header('Tổ kỹ thuật'));
    await t.pumpAndSettle();
    expect(find.text('Bảo hành'), findsNothing);
    handle.dispose();
  });

  testWidgets('mũi tên xoay trong 300ms', (t) async {
    phone(t);
    await t.pumpWidget(host(groups: twoTeams));
    await t.pumpAndSettle();
    final rotation = t.widget<AnimatedRotation>(
      find.descendant(
        of: header('Tổ kỹ thuật'),
        matching: find.byType(AnimatedRotation),
      ),
    );
    expect(rotation.duration, const Duration(milliseconds: 300));
    expect(rotation.curve, OmniCurves.standard);
  });

  // (c)
  testWidgets('tìm: chỉ còn kế hoạch khớp, nhóm tự mở; không thấy gì', (
    t,
  ) async {
    phone(t);
    await t.pumpWidget(host(groups: twoTeams));
    await t.pumpAndSettle();
    // Mặc định gập; có query thì nhóm phải tự mở.
    expect(find.text('Bảo hành'), findsNothing);

    await t.enterText(find.byType(TextField), 'bảo');
    await t.pumpAndSettle();
    expect(find.text('Bảo hành'), findsOneWidget);
    expect(find.text('Sửa chữa tại nhà'), findsNothing);
    expect(find.text('Kinh doanh'), findsNothing);
    // Đếm "N kế hoạch" vẫn là tổng của team.
    expect(find.text('2 kế hoạch'), findsOneWidget);

    // Khớp tên team thì hiện mọi kế hoạch của team đó.
    await t.enterText(find.byType(TextField), 'kinh');
    await t.pumpAndSettle();
    expect(find.text('Sự kiện tháng 10'), findsOneWidget);
    expect(find.text('Tổ kỹ thuật'), findsNothing);

    await t.enterText(find.byType(TextField), 'zzz');
    await t.pumpAndSettle();
    expect(find.text('Không thấy “zzz”'), findsOneWidget);
    expect(find.text('Thử tên team hoặc tên kế hoạch khác.'), findsOneWidget);
    expect(find.byType(TeamGroup), findsNothing);

    // Xoá query: về lại trạng thái gập mặc định.
    await t.enterText(find.byType(TextField), '');
    await t.pumpAndSettle();
    expect(find.text('Bảo hành'), findsNothing);
    expect(find.text('Sự kiện tháng 10'), findsNothing);
  });

  testWidgets('chạm dòng kế hoạch mở bảng kế hoạch đó', (t) async {
    phone(t);
    await t.pumpWidget(host(groups: twoTeams));
    await t.pumpAndSettle();
    await t.tap(header('Tổ kỹ thuật'));
    await t.pumpAndSettle();
    await t.tap(find.text('Sửa chữa tại nhà'));
    await t.pumpAndSettle();
    expect(lastPushedRoute, '${PlanRoutes.board}:id-Sửa chữa tại nhà');
  });

  // (d)
  testWidgets('nút + mở menu Tạo team / Tạo kế hoạch; mỗi mục mở đúng trang', (
    t,
  ) async {
    phone(t);
    await t.pumpWidget(host(assigner: true, canCreateTeam: true));
    await t.pumpAndSettle();
    expect(plus(), findsOneWidget);
    await t.tap(plus());
    await t.pumpAndSettle();
    expect(find.text('Tạo team'), findsOneWidget);
    expect(find.text('Tạo kế hoạch'), findsOneWidget);
    await t.tap(find.text('Tạo team'));
    await t.pumpAndSettle();
    expect(find.byType(CreateTeamPage), findsOneWidget);

    Navigator.of(t.element(find.byType(CreateTeamPage))).pop();
    await t.pumpAndSettle();
    await t.tap(plus());
    await t.pumpAndSettle();
    await t.tap(find.text('Tạo kế hoạch'));
    await t.pumpAndSettle();
    expect(find.byType(CreatePlanPage), findsOneWidget);
  });

  testWidgets('menu +: hộp 220 bo 8 neo phải 16 ngay dưới nút, dòng 52', (
    t,
  ) async {
    phone(t);
    await t.pumpWidget(host(assigner: true, canCreateTeam: true));
    await t.pumpAndSettle();
    final face = t.getRect(find.byKey(const Key('teams-add-face')));
    await t.tap(plus());
    await t.pumpAndSettle();
    final menu = t.getRect(find.byKey(const Key('create-menu')));
    expect(menu.width, 220);
    expect(menu.right, 390 - 16);
    expect(menu.right, face.right);
    expect(menu.top, face.bottom + 6);
    final row = find.ancestor(
      of: find.text('Tạo team'),
      matching: find.byType(InkWell),
    );
    expect(t.getSize(row.first).height, greaterThanOrEqualTo(52));
  });

  testWidgets('nút + phẳng màu chữ và xoay 45° khi menu mở', (t) async {
    phone(t);
    await t.pumpWidget(host(assigner: true, canCreateTeam: true));
    await t.pumpAndSettle();
    double turns() => t
        .widget<AnimatedRotation>(
          find.descendant(
            of: find.byType(TeamsSearchRow),
            matching: find.byType(AnimatedRotation),
          ),
        )
        .turns;
    final scheme = Theme.of(t.element(find.byType(TeamsPage))).colorScheme;
    expect(turns(), 0);
    expect(
      t.widget<Icon>(find.byKey(const Key('teams-add-icon'))).color,
      scheme.onSurface,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('teams-add-face')),
        matching: find.byType(DecoratedBox),
      ),
      findsNothing,
    );

    await t.tap(plus());
    await t.pumpAndSettle();
    expect(turns(), 0.125);
    expect(
      t.widget<Icon>(find.byKey(const Key('teams-add-icon'))).color,
      scheme.onSurface,
    );

    // Chạm lớp phủ để đóng.
    await t.tapAt(const Offset(60, 600));
    await t.pumpAndSettle();
    expect(find.text('Tạo kế hoạch'), findsNothing);
    expect(turns(), 0);
  });

  testWidgets('menu + bật xuống 280ms (pop), không tắt chuyển động', (t) async {
    phone(t);
    await t.pumpWidget(host(assigner: true));
    await t.pumpAndSettle();
    await t.tap(plus());
    await t.pump();
    double opacity() => t
        .widget<Opacity>(
          find
              .ancestor(
                of: find.byKey(const Key('create-menu')),
                matching: find.byType(Opacity),
              )
              .first,
        )
        .opacity;
    await t.pump(const Duration(milliseconds: 100));
    expect(opacity(), inExclusiveRange(0, 1));
    await t.pump(const Duration(milliseconds: 180));
    expect(opacity(), 1);
  });

  testWidgets('thiếu org_units.create: menu chỉ có Tạo kế hoạch', (t) async {
    phone(t);
    await t.pumpWidget(host(assigner: true, canCreateTeam: false));
    await t.pumpAndSettle();
    await t.tap(plus());
    await t.pumpAndSettle();
    expect(find.text('Tạo team'), findsNothing);
    expect(find.text('Tạo kế hoạch'), findsOneWidget);
  });

  testWidgets('người thợ: không có nút +', (t) async {
    phone(t);
    await t.pumpWidget(host(groups: twoTeams));
    await t.pumpAndSettle();
    expect(plus(), findsNothing);
    expect(find.byKey(const Key('teams-add-face')), findsNothing);
  });

  testWidgets('vùng chạm nút + ≥ 44×44 dù hình vẽ 44×40', (t) async {
    phone(t);
    await t.pumpWidget(host(assigner: true));
    await t.pumpAndSettle();
    final hit = t.getSize(find.byKey(const Key('teams-add-hit')));
    expect(hit.width, greaterThanOrEqualTo(44));
    expect(hit.height, greaterThanOrEqualTo(44));
  });

  testWidgets('không lặp Dòng việc trong tab Việc', (t) async {
    phone(t);
    await t.pumpWidget(host(groups: twoTeams));
    await t.pumpAndSettle();
    expect(find.text('Dòng việc'), findsNothing);
    expect(find.textContaining('KPI tháng'), findsNothing);
    expect(find.text('Tổ kỹ thuật'), findsOneWidget);
  });

  // (e)
  testWidgets('bấm giữ team mở thẳng Sửa tên / Xoá theo quyền', (t) async {
    phone(t);
    await t.pumpWidget(
      host(groups: [group('Tổ mới')], canUpdateTeam: true, canDeleteTeam: true),
    );
    await t.pumpAndSettle();
    await t.longPress(header('Tổ mới'));
    await t.pumpAndSettle();
    expect(find.text('Sửa tên team'), findsOneWidget);
    expect(find.text('Xoá team'), findsOneWidget);
    expect(find.byKey(const Key('work-list-action-edit')), findsOneWidget);
    expect(find.byKey(const Key('work-list-action-delete')), findsOneWidget);
    // `showOmniSheet` tự vẽ thanh kéo trên iOS; nội dung không được vẽ thêm
    // một thanh nữa, nếu không menu sẽ có hai gạch chồng nhau.
    expect(find.byKey(const Key('sheet-handle')), findsNothing);
  });

  testWidgets('sửa tên team gọi PUT thật qua PlansApi rồi báo thành công', (
    t,
  ) async {
    phone(t);
    final api = _FakePlansApi();
    await t.pumpWidget(
      host(groups: [group('Tổ cũ')], canUpdateTeam: true, plansApi: api),
    );
    await t.pumpAndSettle();

    await t.longPress(header('Tổ cũ'));
    await t.pumpAndSettle();
    await t.tap(find.text('Sửa tên team'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).last, 'Tổ hoàn thiện');
    await t.pumpAndSettle();
    await t.tap(find.text('Lưu'));
    await t.pumpAndSettle();

    expect(api.updatedTeams, [('team-Tổ cũ', 'Tổ hoàn thiện')]);
    expect(find.text('Đã đổi tên team.'), findsOneWidget);
  });

  testWidgets('bấm giữ: không có gì khi thiếu quyền hoặc team tổng hợp', (
    t,
  ) async {
    phone(t);
    await t.pumpWidget(
      host(
        groups: [
          group('A', plans: [plan('P')]),
        ],
      ),
    );
    await t.pumpAndSettle();
    await t.longPress(header('A'));
    await t.pumpAndSettle();
    expect(find.text('Xoá team'), findsNothing);
  });

  testWidgets('bấm giữ kế hoạch mở thẳng Sửa / Xoá, không chọn lại', (t) async {
    phone(t);
    await t.pumpWidget(
      host(
        groups: [
          group('A', plans: [plan('P')]),
        ],
        assigner: true,
      ),
    );
    await t.pumpAndSettle();
    await t.tap(header('A'));
    await t.pumpAndSettle();
    await t.longPress(find.text('P'));
    await t.pumpAndSettle();

    expect(find.text('Sửa kế hoạch'), findsOneWidget);
    expect(find.text('Xoá kế hoạch'), findsOneWidget);
    expect(find.textContaining('Chọn kế hoạch'), findsNothing);
  });

  testWidgets('xoá kế hoạch xác nhận phá huỷ rồi gọi API', (t) async {
    phone(t);
    final api = _FakePlansApi();
    await t.pumpWidget(
      host(
        groups: [
          group('A', plans: [plan('P')]),
        ],
        assigner: true,
        plansApi: api,
      ),
    );
    await t.pumpAndSettle();
    await t.tap(header('A'));
    await t.pumpAndSettle();
    await t.longPress(find.text('P'));
    await t.pumpAndSettle();
    await t.tap(find.text('Xoá kế hoạch'));
    await t.pumpAndSettle();
    expect(find.text('Xoá kế hoạch “P”?'), findsOneWidget);
    await t.tap(find.text('Xoá kế hoạch'));
    await t.pumpAndSettle();

    expect(api.deletedPlans, ['id-P']);
    expect(find.text('Đã xoá kế hoạch.'), findsOneWidget);
  });

  testWidgets('bấm giữ: không có gì với team tổng hợp', (t) async {
    phone(t);
    await t.pumpWidget(
      host(
        groups: [
          group('Mồ côi', id: '', synthetic: true, plans: [plan('P')]),
        ],
        canDeleteTeam: true,
      ),
    );
    await t.pumpAndSettle();
    await t.longPress(header('Mồ côi'));
    await t.pumpAndSettle();
    expect(find.text('Xoá team'), findsNothing);
  });

  testWidgets('team còn kế hoạch: Xoá team báo chuyển kế hoạch trước', (
    t,
  ) async {
    phone(t);
    await t.pumpWidget(
      host(
        groups: [
          group('A', plans: [plan('P')]),
        ],
        canDeleteTeam: true,
      ),
    );
    await t.pumpAndSettle();
    await t.longPress(header('A'));
    await t.pumpAndSettle();
    await t.tap(find.text('Xoá team'));
    await t.pumpAndSettle();
    expect(
      find.text(
        'Team còn 1 kế hoạch. Hãy chuyển các kế hoạch sang team khác trước.',
      ),
      findsOneWidget,
    );
  });

  // (g)
  testWidgets('giảm chuyển động: nhóm, mũi tên, menu + không còn khung chờ', (
    t,
  ) async {
    phone(t);
    await t.pumpWidget(
      host(groups: twoTeams, assigner: true, reduceMotion: true),
    );
    await t.pump();
    await t.pump();
    expect(t.hasRunningAnimations, isFalse);

    // Mũi tên: Duration.zero, đổi ngay sau một pump. (Gợn mực của InkWell là
    // phản hồi chạm của Material, không phải hoạt ảnh của màn, nên chờ nó.)
    await t.tap(header('Tổ kỹ thuật'));
    await t.pump();
    expect(
      t
          .widget<AnimatedRotation>(
            find.descendant(
              of: header('Tổ kỹ thuật'),
              matching: find.byType(AnimatedRotation),
            ),
          )
          .duration,
      Duration.zero,
    );
    await t.pumpAndSettle();

    await t.tap(plus());
    await t.pump();
    await t.pump();
    expect(t.hasRunningAnimations, isFalse);
    expect(find.text('Tạo kế hoạch'), findsOneWidget);
  });

  testWidgets('nhóm hiện bằng rise 350ms, lệch 50ms mỗi nhóm', (t) async {
    phone(t);
    await t.pumpWidget(host(groups: twoTeams));
    await t.pump();
    await t.pump();
    expect(t.hasRunningAnimations, isTrue);
    Opacity riseOf(int i) => t.widget<Opacity>(
      find
          .descendant(
            of: find.byType(TeamGroup).at(i),
            matching: find.byType(Opacity),
          )
          .first,
    );
    // Ở 30ms nhóm đầu đã bắt đầu, nhóm thứ hai chưa.
    await t.pump(const Duration(milliseconds: 30));
    expect(riseOf(0).opacity, greaterThan(0));
    expect(riseOf(1).opacity, 0);
    await t.pump(const Duration(milliseconds: 400));
    expect(riseOf(0).opacity, 1);
    expect(riseOf(1).opacity, 1);
    expect(t.hasRunningAnimations, isFalse);
  });

  // (h)
  testWidgets('theme tối: dựng được, nền nhóm là surface tối', (t) async {
    phone(t);
    await t.pumpWidget(host(groups: twoTeams, assigner: true, dark: true));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    final scheme = Theme.of(t.element(find.byType(TeamsPage))).colorScheme;
    expect(scheme.brightness, Brightness.dark);
    final material = t.widget<Material>(
      find
          .descendant(
            of: find.byType(TeamGroup).first,
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.color, scheme.surface);
    await t.tap(plus());
    await t.pumpAndSettle();
    expect(find.text('Tạo kế hoạch'), findsOneWidget);
  });

  // (i)
  testWidgets('không còn chữ "dự án" ở đâu trên màn', (t) async {
    phone(t);
    await t.pumpWidget(
      host(groups: [...twoTeams, group('Tổ mới')], assigner: true),
    );
    await t.pumpAndSettle();
    expect(find.textContaining('dự án'), findsNothing);
    expect(find.textContaining('Dự án'), findsNothing);
    await t.tap(plus());
    await t.pumpAndSettle();
    expect(find.textContaining('dự án'), findsNothing);
  });

  testWidgets('team rỗng nói rõ là rỗng', (t) async {
    phone(t);
    await t.pumpWidget(host(groups: [group('Tổ mới')]));
    await t.pumpAndSettle();
    expect(find.text('Team này chưa có kế hoạch nào.'), findsNothing);
    await t.tap(header('Tổ mới'));
    await t.pumpAndSettle();
    expect(find.text('Team này chưa có kế hoạch nào.'), findsOneWidget);
  });

  testWidgets('chưa có team nào: lời nhắn theo vai, chữ "kế hoạch"', (t) async {
    phone(t);
    await t.pumpWidget(host(groups: const []));
    await t.pumpAndSettle();
    expect(
      find.text('Khi bạn được thêm vào một kế hoạch, nó sẽ hiện ở đây.'),
      findsOneWidget,
    );

    await t.pumpWidget(host(groups: const [], assigner: true));
    await t.pumpAndSettle();
    expect(find.text('Tạo một team để nhóm các kế hoạch lại.'), findsOneWidget);
  });

  testWidgets('kế hoạch chưa thuộc team nào vẫn hiện, ở nhóm riêng', (t) async {
    phone(t);
    await t.pumpWidget(
      host(
        groups: [
          group(
            'Chưa thuộc team nào',
            id: '',
            synthetic: true,
            plans: [plan('Kế hoạch cũ')],
          ),
        ],
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Chưa thuộc team nào'), findsOneWidget);
    expect(find.text('Kế hoạch cũ'), findsNothing);
    await t.tap(header('Chưa thuộc team nào'));
    await t.pumpAndSettle();
    expect(find.text('Kế hoạch cũ'), findsOneWidget);
  });

  testWidgets('kéo xuống làm mới vẫn có', (t) async {
    phone(t);
    await t.pumpWidget(host(groups: twoTeams));
    await t.pumpAndSettle();
    expect(find.byType(RefreshIndicator), findsOneWidget);
  });

  // Kế hoạch đã đóng / lưu trữ.
  {
    final withClosed = [
      group(
        'Tổ kỹ thuật',
        plans: [plan('Bảo hành')],
        closed: [
          plan('Đợt 1 đã xong', status: 'done'),
          plan('Kho cũ', status: 'archived'),
        ],
      ),
    ];

    testWidgets('"Đã đóng (N)" gập mặc định, mở ra kế hoạch mờ có nhãn', (
      t,
    ) async {
      phone(t);
      await t.pumpWidget(host(groups: withClosed));
      await t.pumpAndSettle();

      await t.tap(header('Tổ kỹ thuật'));
      await t.pumpAndSettle();
      expect(find.text('Đã đóng (2)'), findsOneWidget);
      expect(find.text('Đợt 1 đã xong'), findsNothing);
      // "N kế hoạch" vẫn chỉ đếm kế hoạch đang chạy.
      expect(find.text('1 kế hoạch'), findsOneWidget);

      await t.tap(find.text('Đã đóng (2)'));
      await t.pumpAndSettle();
      expect(find.text('Đợt 1 đã xong'), findsOneWidget);
      expect(find.text('Kho cũ'), findsOneWidget);
      final done = find.ancestor(
        of: find.text('Đợt 1 đã xong'),
        matching: find.byType(PlanTile),
      );
      expect(
        find.descendant(of: done, matching: find.text('Đã đóng')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: done, matching: find.byType(Opacity)),
        findsWidgets,
      );
      final archived = find.ancestor(
        of: find.text('Kho cũ'),
        matching: find.byType(PlanTile),
      );
      expect(
        find.descendant(of: archived, matching: find.text('Lưu trữ')),
        findsOneWidget,
      );

      await t.tap(find.text('Đợt 1 đã xong'));
      await t.pumpAndSettle();
      expect(lastPushedRoute, '${PlanRoutes.board}:id-Đợt 1 đã xong');
    });

    testWidgets('tìm cũng ra kế hoạch đã đóng, có nhãn', (t) async {
      phone(t);
      await t.pumpWidget(host(groups: withClosed));
      await t.pumpAndSettle();

      await t.enterText(find.byType(TextField), 'kho');
      await t.pumpAndSettle();
      expect(find.text('Kho cũ'), findsOneWidget);
      expect(find.text('Lưu trữ'), findsOneWidget);
      expect(find.text('Bảo hành'), findsNothing);
    });

    testWidgets(
      'đang tìm: "Đã đóng" luôn mở, chạm không gập (không nút chết)',
      (t) async {
        phone(t);
        await t.pumpWidget(host(groups: withClosed));
        await t.pumpAndSettle();

        await t.enterText(find.byType(TextField), 'kho');
        await t.pumpAndSettle();
        final toggle = t.widget<InkWell>(
          find
              .ancestor(
                of: find.byKey(const Key('team-closed-toggle')).first,
                matching: find.byType(InkWell),
              )
              .first,
        );
        expect(toggle.onTap, isNull);
        await t.tap(
          find.byKey(const Key('team-closed-toggle')).first,
          warnIfMissed: false,
        );
        await t.pumpAndSettle();
        expect(find.text('Kho cũ'), findsOneWidget);
      },
    );

    testWidgets('team chỉ còn kế hoạch đã đóng: KHÔNG xoá được', (t) async {
      phone(t);
      await t.pumpWidget(
        host(
          groups: [
            group('A', closed: [plan('P', status: 'done')]),
          ],
          canDeleteTeam: true,
        ),
      );
      await t.pumpAndSettle();
      await t.tap(header('A'));
      await t.pumpAndSettle();
      // Không nói "chưa có kế hoạch nào" khi còn kế hoạch đã đóng.
      expect(find.text('Team này chưa có kế hoạch nào.'), findsNothing);
      expect(find.text('Đã đóng (1)'), findsOneWidget);

      await t.longPress(header('A'));
      await t.pumpAndSettle();
      await t.tap(find.text('Xoá team'));
      await t.pumpAndSettle();
      expect(
        find.text(
          'Team còn 1 kế hoạch (1 đã đóng). Hãy chuyển các kế hoạch sang '
          'team khác trước.',
        ),
        findsOneWidget,
      );
      expect(find.text('Xoá team “A”?'), findsNothing);
    });
  }
}

class _FakePlansApi extends PlansApi {
  _FakePlansApi() : super(ApiClient(Dio()));

  final updatedTeams = <(String, String)>[];
  final deletedPlans = <String>[];

  @override
  Future<Team> updateTeam(String teamId, {required String name}) async {
    updatedTeams.add((teamId, name));
    return Team(id: teamId, name: name);
  }

  @override
  Future<void> deletePlan(String planId) async {
    deletedPlans.add(planId);
  }
}
