import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/plans/application/plans_providers.dart';
import 'package:omni_app/modules/plans/domain/plan.dart';
import 'package:omni_app/modules/plans/domain/team.dart';
import 'package:omni_app/modules/plans/domain/workshop_kpi.dart';
import 'package:omni_app/modules/plans/presentation/create_plan_page.dart';
import 'package:omni_app/modules/plans/presentation/create_team_page.dart';
import 'package:omni_app/modules/plans/presentation/teams_page.dart';
import 'package:omni_app/modules/plans/presentation/widgets/create_choice_sheet.dart';
import 'package:omni_app/modules/plans/presentation/widgets/plan_row.dart';
import 'package:omni_app/modules/plans/routes.dart';
import 'package:omni_app/modules/settings/application/appearance_providers.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/domain/task_permissions.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session_controller.dart';

import '../support/fixed_background.dart';

/// Gốc tab Việc: dự án xếp theo team, nút + vuông chỉ biểu tượng, thẻ Dòng việc.
/// Ranh giới giữa người thợ và người giao việc là QUYỀN, không phải tên vai.
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
    int sections = 0,
    int total = 10,
    int done = 4,
    int overdue = 0,
  }) => Plan.fromJson({
    'id': 'id-$name',
    'name': name,
    'sections': [
      for (var i = 0; i < sections; i++) {'id': 's$i', 'name': 'N$i'},
    ],
    // Hình dạng thật của API: ba con số nằm trong `stats`.
    'stats': {'total': total, 'done': done, 'overdue': overdue},
  });

  TeamWithPlans group(
    String name, {
    int members = 0,
    List<Plan> plans = const [],
    bool synthetic = false,
    String? id,
  }) => TeamWithPlans(
    team: Team(
      id: id ?? 'team-$name',
      name: name,
      memberIds: [for (var i = 0; i < members; i++) 'u$i'],
    ),
    plans: plans,
    synthetic: synthetic,
  );

  Widget host({
    List<TeamWithPlans>? groups,
    bool assigner = false,
    bool canCreateTeam = false,
    bool canDeleteTeam = false,
    int kpiDelivered = 0,
    bool kpiError = false,
    bool reduceMotion = false,
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
            lastPushedRoute = PlanRoutes.board;
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

  setUp(() => lastPushedRoute = null);

  void phone(WidgetTester t) {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
  }

  testWidgets('nhóm dự án theo team, meta và Trễ N, không ô tìm', (t) async {
    phone(t);
    await t.pumpWidget(
      host(
        groups: [
          group(
            'Tổ kỹ thuật',
            members: 6,
            plans: [
              plan('Sửa chữa đàn', sections: 4, total: 18, done: 5, overdue: 2),
            ],
          ),
        ],
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('TỔ KỸ THUẬT'), findsOneWidget);
    expect(find.text('6 người'), findsOneWidget);
    expect(find.text('4 nhóm việc · 18 việc'), findsOneWidget);
    expect(find.text('Trễ 2'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Hôm nay'), findsNothing);
  });

  testWidgets('chạm dòng dự án mở bảng dự án', (t) async {
    phone(t);
    await t.pumpWidget(
      host(
        groups: [
          group('A', plans: [plan('P')]),
        ],
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('P'));
    await t.pumpAndSettle();
    expect(lastPushedRoute, PlanRoutes.board);
  });

  testWidgets('thẻ Dòng việc hiện số KPI và mở /timeline', (t) async {
    phone(t);
    await t.pumpWidget(host(groups: [], kpiDelivered: 64));
    await t.pumpAndSettle();
    expect(find.text('KPI tháng · 64 việc xong'), findsOneWidget);
    await t.tap(find.text('Dòng việc'));
    await t.pumpAndSettle();
    expect(lastPushedRoute, PlanRoutes.timeline);
  });

  testWidgets('KPI lỗi: phụ đề trung tính, danh sách vẫn hiện', (t) async {
    phone(t);
    await t.pumpWidget(
      host(
        groups: [
          group('A', plans: [plan('P')]),
        ],
        kpiError: true,
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('KPI tháng · feed 7 ngày'), findsOneWidget);
    expect(find.text('P'), findsOneWidget);
  });

  testWidgets('nút + vuông chỉ biểu tượng, mở Tạo mới với 2 lựa chọn', (
    t,
  ) async {
    phone(t);
    await t.pumpWidget(host(assigner: true, canCreateTeam: true));
    await t.pumpAndSettle();
    final plus = find.bySemanticsLabel('Tạo team hoặc dự án');
    expect(plus, findsOneWidget);
    expect(t.getSize(find.byType(CreateSquareButton)), const Size(52, 52));
    expect(find.text('Tạo mới'), findsNothing); // không có chữ trên nút
    await t.tap(plus);
    await t.pumpAndSettle();
    expect(find.text('Tạo team'), findsOneWidget);
    expect(find.text('Tạo dự án'), findsOneWidget);
  });

  testWidgets('nút + xoay thành × khi sheet mở và về lại khi đóng', (t) async {
    phone(t);
    await t.pumpWidget(host(assigner: true, canCreateTeam: true));
    await t.pumpAndSettle();
    double turns() =>
        t.widget<AnimatedRotation>(find.byType(AnimatedRotation)).turns;
    expect(turns(), 0);
    await t.tap(find.bySemanticsLabel('Tạo team hoặc dự án'));
    await t.pumpAndSettle();
    expect(turns(), 0.125);
    await t.tapAt(const Offset(195, 60)); // chạm nền mờ để đóng sheet
    await t.pumpAndSettle();
    expect(find.text('Tạo dự án'), findsNothing);
    expect(turns(), 0);
  });

  testWidgets("chọn Tạo team / Tạo dự án mở đúng trang tạo có sẵn", (t) async {
    phone(t);
    await t.pumpWidget(host(assigner: true, canCreateTeam: true));
    await t.pumpAndSettle();
    await t.tap(find.bySemanticsLabel("Tạo team hoặc dự án"));
    await t.pumpAndSettle();
    await t.tap(find.text("Tạo team"));
    await t.pumpAndSettle();
    expect(find.byType(CreateTeamPage), findsOneWidget);

    Navigator.of(t.element(find.byType(CreateTeamPage))).pop();
    await t.pumpAndSettle();
    await t.tap(find.bySemanticsLabel("Tạo team hoặc dự án"));
    await t.pumpAndSettle();
    await t.tap(find.text("Tạo dự án"));
    await t.pumpAndSettle();
    expect(find.byType(CreatePlanPage), findsOneWidget);
  });

  testWidgets('thiếu quyền org: sheet chỉ có Tạo dự án', (t) async {
    phone(t);
    await t.pumpWidget(host(assigner: true, canCreateTeam: false));
    await t.pumpAndSettle();
    await t.tap(find.bySemanticsLabel('Tạo team hoặc dự án'));
    await t.pumpAndSettle();
    expect(find.text('Tạo team'), findsNothing);
    expect(find.text('Tạo dự án'), findsOneWidget);
  });

  testWidgets('người thợ: không có nút +', (t) async {
    phone(t);
    await t.pumpWidget(host(assigner: false));
    await t.pumpAndSettle();
    expect(find.bySemanticsLabel('Tạo team hoặc dự án'), findsNothing);
    expect(find.byType(CreateSquareButton), findsNothing);
  });

  testWidgets('giảm chuyển động: mở sheet không còn hoạt ảnh sau một pump', (
    t,
  ) async {
    phone(t);
    await t.pumpWidget(host(assigner: true, reduceMotion: true));
    await t.pumpAndSettle();
    await t.tap(find.bySemanticsLabel('Tạo team hoặc dự án'));
    await t.pump();
    await t.pump();
    expect(t.hasRunningAnimations, isFalse);
  });

  testWidgets('dòng dự án và nút ⋯ team có vùng chạm ≥ 44', (t) async {
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
    expect(t.getSize(find.byType(PlanRow)).height, greaterThanOrEqualTo(44));
    final more = t.getSize(find.byTooltip('Tuỳ chọn team'));
    expect(more.height, greaterThanOrEqualTo(44));
    expect(more.width, greaterThanOrEqualTo(44));
  });

  testWidgets('nút ⋯ ẩn với team tổng hợp hoặc khi thiếu quyền xoá', (t) async {
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
    expect(find.byTooltip('Tuỳ chọn team'), findsNothing);

    await t.pumpWidget(
      host(
        groups: [
          group('A', plans: [plan('P')]),
        ],
      ),
    );
    await t.pumpAndSettle();
    expect(find.byTooltip('Tuỳ chọn team'), findsNothing);
  });

  testWidgets('team rỗng nói rõ là rỗng, không phải một khoảng trắng', (
    t,
  ) async {
    phone(t);
    await t.pumpWidget(host(groups: [group('Tổ mới')]));
    await t.pumpAndSettle();
    expect(find.text('Team này chưa có dự án nào.'), findsOneWidget);
  });

  testWidgets('chưa có team nào thì lời nhắn khác nhau theo vai', (t) async {
    phone(t);
    await t.pumpWidget(host(groups: const []));
    await t.pumpAndSettle();
    expect(find.textContaining('sẽ hiện ở đây'), findsOneWidget);

    await t.pumpWidget(host(groups: const [], assigner: true));
    await t.pumpAndSettle();
    expect(find.textContaining('Tạo một team'), findsOneWidget);
  });

  testWidgets('dự án chưa thuộc team nào vẫn hiện, ở khối riêng', (t) async {
    phone(t);
    await t.pumpWidget(
      host(
        groups: [
          group(
            'Chưa thuộc team nào',
            id: '',
            synthetic: true,
            plans: [plan('Dự án cũ')],
          ),
        ],
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('CHƯA THUỘC TEAM NÀO'), findsOneWidget);
    expect(find.text('Dự án cũ'), findsOneWidget);
  });
}
