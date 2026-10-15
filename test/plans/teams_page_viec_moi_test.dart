import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/design/tokens/tokens.dart';
import 'package:omni_app/modules/plans/application/plans_providers.dart';
import 'package:omni_app/modules/plans/data/plans_api.dart';
import 'package:omni_app/modules/plans/domain/plan.dart';
import 'package:omni_app/modules/plans/domain/team.dart';
import 'package:omni_app/modules/plans/domain/workshop_kpi.dart';
import 'package:omni_app/modules/plans/presentation/create_plan_page.dart';
import 'package:omni_app/modules/plans/presentation/create_team_page.dart';
import 'package:omni_app/modules/plans/presentation/teams_page.dart';
import 'package:omni_app/modules/plans/presentation/widgets/plan_tile.dart';
import 'package:omni_app/modules/plans/presentation/widgets/project_cover.dart';
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
    String? teamId,
    String? ownerId,
  }) => Plan.fromJson({
    'id': 'id-$name',
    'name': name,
    'cover': ?cover,
    'status': ?status,
    'team_id': ?teamId,
    'owner_id': ?ownerId,
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
    bool canDeleteTeam = false,
    int kpiDelivered = 0,
    bool kpiError = false,
    bool reduceMotion = false,
    bool dark = false,
    PlansApi? plansApi,
  }) {
    final permissions = <String>{
      ...(assigner ? assignerPerms : worker),
      if (canCreateTeam) 'organization.org_units.create',
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
          path: '/timeline',
          name: PlanRoutes.timeline,
          builder: (_, _) {
            lastPushedRoute = PlanRoutes.timeline;
            return const Scaffold(body: Text('trang dong viec'));
          },
        ),
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
        teamsWithPlansProvider.overrideWith((ref) async => groups ?? const []),
        workshopKpiProvider.overrideWith((ref) async {
          if (kpiError) throw Exception('kpi hỏng');

          return WorkshopKpi(
            delivered: kpiDelivered,
            reachedBonus: 0,
            daysLeft: 10,
            tiers: const [],
            isConfigured: true,
          );
        }),
        taskAccessProvider.overrideWithValue(TaskAccess.of(policy)),
        accessProvider.overrideWithValue(policy),
        if (plansApi != null) plansApiProvider.overrideWithValue(plansApi),
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
    expect(find.text('Bảo hành'), findsOneWidget);
    expect(find.text('9 việc đang mở'), findsOneWidget);
    expect(find.text('2 trễ'), findsOneWidget);
    expect(find.text('6 việc đang mở'), findsOneWidget);
    expect(find.text('7 việc đang mở'), findsOneWidget);
    // Chỉ một dòng có việc trễ.
    expect(find.textContaining('trễ'), findsOneWidget);
    // Ô tìm ở hàng thứ hai của header.
    expect(find.byType(TeamsSearchRow), findsOneWidget);
    expect(find.text('Tìm team, kế hoạch'), findsOneWidget);
  });

  testWidgets('bố cục đúng bản mẫu: team không avatar, dự án có dấu 12', (
    t,
  ) async {
    phone(t);
    await t.pumpWidget(host(groups: twoTeams, assigner: true));
    await t.pumpAndSettle();
    expect(t.getSize(find.byType(PlanTile).first).height, 48);
    final tile = t.getSize(find.byKey(const Key('plan-tile-swatch')).first);
    expect(tile, const Size(12, 12));
    expect(find.byKey(const Key('team-group-swatch')), findsNothing);
    expect(t.getSize(header('Tổ kỹ thuật')).height, 48);
    expect(t.getSize(find.byKey(const Key('teams-search-box'))).height, 40);
    expect(
      t.getSize(find.byKey(const Key('teams-add-face'))),
      const Size(44, 40),
    );
    // Dự án mang dấu cover nhỏ, không giả làm avatar chữ cái.
    expect(
      t.widget<ProjectCoverMarker>(find.byType(ProjectCoverMarker).first).cover,
      'teal-1',
    );
    // Các nhóm cách nhau 10.
    final first = t.getRect(find.byType(TeamGroup).at(0));
    final second = t.getRect(find.byType(TeamGroup).at(1));
    expect(second.top - first.bottom, 10);
    expect(first.left, 16);
  });

  testWidgets('quản lý giữ dự án rồi thả sang team khác → cập nhật team_id', (
    t,
  ) async {
    phone(t);
    final api = _MovePlansApi();
    await t.pumpWidget(
      host(
        groups: [
          group(
            'Team A',
            id: 'ta',
            plans: [plan('Dự án A', teamId: 'ta', ownerId: 'u1')],
          ),
          group('Team B', id: 'tb'),
        ],
        assigner: true,
        plansApi: api,
      ),
    );
    await t.pumpAndSettle();

    final gesture = await t.startGesture(t.getCenter(find.text('Dự án A')));
    await t.pump(const Duration(milliseconds: 450));
    await gesture.moveTo(t.getCenter(find.text('Team B')));
    await t.pump();
    await gesture.up();
    await t.pumpAndSettle();

    expect(api.moves, [('id-Dự án A', 'tb')]);
  });

  // (b)
  testWidgets('chạm đầu nhóm: kế hoạch ẩn, expanded đổi, mũi tên xoay', (
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
    expect(find.text('Sự kiện tháng 10'), findsOneWidget);
    expect(turns(), 0);
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
    // Gập trước: có query thì nhóm phải tự mở.
    await t.tap(header('Tổ kỹ thuật'));
    await t.pumpAndSettle();
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

    // Xoá query: về lại trạng thái gập đã chọn.
    await t.enterText(find.byType(TextField), '');
    await t.pumpAndSettle();
    expect(find.text('Bảo hành'), findsNothing);
    expect(find.text('Sự kiện tháng 10'), findsOneWidget);
  });

  testWidgets('chạm dòng kế hoạch mở bảng kế hoạch đó', (t) async {
    phone(t);
    await t.pumpWidget(host(groups: twoTeams));
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

  testWidgets('nút + đổi nền mực và xoay 45° khi menu mở, về lại khi đóng', (
    t,
  ) async {
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
    Color faceColor() =>
        (t
                    .widget<AnimatedContainer>(
                      find.byKey(const Key('teams-add-face')),
                    )
                    .decoration!
                as BoxDecoration)
            .color!;
    final scheme = Theme.of(t.element(find.byType(TeamsPage))).colorScheme;
    expect(turns(), 0);
    expect(faceColor(), scheme.primary);

    await t.tap(plus());
    await t.pumpAndSettle();
    expect(turns(), 0.125);
    expect(faceColor(), OmniColors.ink);

    // Chạm lớp phủ để đóng.
    await t.tapAt(const Offset(60, 600));
    await t.pumpAndSettle();
    expect(find.text('Tạo kế hoạch'), findsNothing);
    expect(turns(), 0);
    expect(faceColor(), scheme.primary);
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

  // (e)
  testWidgets('thẻ Dòng việc ở cuối, hiện KPI và mở /timeline', (t) async {
    phone(t);
    await t.pumpWidget(host(groups: twoTeams, kpiDelivered: 64));
    await t.pumpAndSettle();
    expect(find.text('KPI tháng · 64 việc xong'), findsOneWidget);
    final last = t.getRect(find.byType(TeamGroup).last);
    expect(t.getRect(find.text('Dòng việc')).top, greaterThan(last.bottom));
    await t.tap(find.text('Dòng việc'));
    await t.pumpAndSettle();
    expect(lastPushedRoute, PlanRoutes.timeline);
  });

  testWidgets('KPI lỗi: phụ đề trung tính, danh sách vẫn hiện', (t) async {
    phone(t);
    await t.pumpWidget(host(groups: twoTeams, kpiError: true));
    await t.pumpAndSettle();
    expect(find.text('KPI tháng · feed 7 ngày'), findsOneWidget);
    expect(find.text('Bảo hành'), findsOneWidget);
  });

  // (f)
  testWidgets('bấm giữ đầu nhóm: sheet có "Xoá team" khi có quyền', (t) async {
    phone(t);
    await t.pumpWidget(host(groups: [group('Tổ mới')], canDeleteTeam: true));
    await t.pumpAndSettle();
    await t.longPress(header('Tổ mới'));
    await t.pumpAndSettle();
    expect(find.text('Xoá team'), findsOneWidget);
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

class _MovePlansApi implements PlansApi {
  final moves = <(String, String?)>[];

  @override
  Future<Plan> updatePlan(String planId, PlanPatch patch) async {
    final body = patch.toJson();
    moves.add((planId, body['team_id'] as String?));

    return Plan.fromJson({
      'id': planId,
      'name': planId,
      'team_id': body['team_id'],
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
