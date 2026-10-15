import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/plans/application/plans_providers.dart';
import 'package:omni_app/modules/plans/domain/plan.dart';
import 'package:omni_app/modules/plans/domain/team.dart';
import 'package:omni_app/modules/plans/domain/workshop_kpi.dart';
import 'package:omni_app/modules/plans/presentation/teams_page.dart';
import 'package:omni_app/modules/plans/presentation/widgets/plan_tile.dart';
import 'package:omni_app/modules/plans/presentation/widgets/team_group.dart';
import 'package:omni_app/modules/settings/application/appearance_providers.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/domain/task_permissions.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session_controller.dart';

import '../support/fixed_background.dart';

/// Bản sửa sau rà soát Task 3: rise không phát lại khi cuộn, nhấn-co huỷ khi
/// cuộn, icon phân cấp, khoá nhóm theo id, ngữ nghĩa menu Tạo mới.
void main() {
  const assigner = {'tasks.read', 'tasks.write', 'tasks.projects.manage.all'};

  TeamWithPlans teamOf(int i, {String? name, bool synthetic = false}) =>
      TeamWithPlans(
        team: Team(id: synthetic ? '' : 'team-$i', name: name ?? 'Team $i'),
        plans: [
          Plan.fromJson({
            'id': 'plan-$i',
            'name': 'Kế hoạch $i',
            'stats': {'total': 3, 'done': 1, 'overdue': 0},
          }),
        ],
        synthetic: synthetic,
      );

  Widget host(StateProvider<List<TeamWithPlans>> source) {
    final policy = const AccessPolicy(assigner);

    return ProviderScope(
      overrides: [
        backgroundProvider.overrideWith(FixedBackground.new),
        teamsWithPlansProvider.overrideWith((ref) async => ref.watch(source)),
        workshopKpiProvider.overrideWith(
          (ref) async => const WorkshopKpi(
            delivered: 0,
            reachedBonus: 0,
            daysLeft: 10,
            tiers: [],
            isConfigured: true,
          ),
        ),
        taskAccessProvider.overrideWithValue(TaskAccess.of(policy)),
        accessProvider.overrideWithValue(policy),
      ],
      child: MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        home: const TeamsPage(),
      ),
    );
  }

  Future<ProviderContainer> pumpTeams(
    WidgetTester tester,
    List<TeamWithPlans> groups, {
    StateProvider<List<TeamWithPlans>>? provider,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final source =
        provider ?? StateProvider<List<TeamWithPlans>>((_) => groups);
    await tester.pumpWidget(host(source));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TeamsPage)),
    );
    return container;
  }

  double riseOpacity(WidgetTester tester, String teamName) {
    final rise = find.ancestor(
      of: find.text(teamName),
      matching: find.byType(OmniRise),
    );
    final opacity = tester.widget<Opacity>(
      find.descendant(of: rise, matching: find.byType(Opacity)).first,
    );
    return opacity.opacity;
  }

  group('rise', () {
    testWidgets('độ trễ trần ở 6 bước', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: OmniTheme.light(TargetPlatform.android),
          home: Scaffold(
            body: TeamGroup(
              group: teamOf(1),
              plans: teamOf(1).plans,
              open: false,
              onToggle: () {},
              onOpenPlan: (_) {},
              index: 9,
            ),
          ),
        ),
      );
      expect(
        tester.widget<OmniRise>(find.byType(OmniRise)).delay,
        OmniRise.step * 6,
      );
    });

    testWidgets('cuộn xuống rồi lên: nhóm không phát lại rise', (tester) async {
      await pumpTeams(tester, [for (var i = 0; i < 14; i++) teamOf(i)]);
      final list = find.byType(Scrollable).first;

      await tester.drag(list, const Offset(0, -3000));
      await tester.pump();
      // Nhóm ở xa hiện lần đầu khi cuộn tới: hiện ngay, không chờ trễ.
      expect(riseOpacity(tester, 'Team 13'), 1);
      await tester.pumpAndSettle();

      await tester.drag(list, const Offset(0, 3000));
      await tester.pump();
      expect(riseOpacity(tester, 'Team 0'), 1);
      expect(riseOpacity(tester, 'Team 1'), 1);
    });

    testWidgets('lần dựng đầu vẫn rise', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final source = StateProvider<List<TeamWithPlans>>(
        (_) => [teamOf(0), teamOf(1)],
      );
      await tester.pumpWidget(host(source));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      expect(riseOpacity(tester, 'Team 0'), lessThan(1));
      await tester.pumpAndSettle();
    });
  });

  testWidgets('nhấn co .97, kéo cuộn thì huỷ co', (tester) async {
    await pumpTeams(tester, [for (var i = 0; i < 6; i++) teamOf(i)]);

    final teamHeader = find
        .ancestor(of: find.text('Team 1'), matching: find.byType(InkWell))
        .first;
    await tester.tap(teamHeader);
    await tester.pumpAndSettle();

    double scaleOf(Finder tile) => tester
        .widget<AnimatedScale>(
          find.descendant(of: tile, matching: find.byType(AnimatedScale)),
        )
        .scale;

    final tile = find.widgetWithText(PlanTile, 'Kế hoạch 1');
    final gesture = await tester.startGesture(tester.getCenter(tile));
    await tester.pump(const Duration(milliseconds: 150));
    expect(scaleOf(tile), .97);

    await gesture.moveBy(const Offset(0, -40));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -40));
    await tester.pump();
    expect(scaleOf(tile), 1, reason: 'cuộn danh sách huỷ trạng thái nhấn');
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('team dùng icon, kế hoạch dùng dấu cover, không còn vạch màu', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        home: Scaffold(
          body: TeamGroup(
            group: teamOf(1),
            plans: teamOf(1).plans,
            open: true,
            onToggle: () {},
            onOpenPlan: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<Icon>(find.byKey(const Key('team-group-icon'))).icon,
      Icons.groups_2_outlined,
    );
    expect(find.byKey(const Key('plan-tile-swatch')), findsOneWidget);
    expect(find.byKey(const Key('team-group-marker')), findsNothing);
    expect(find.byKey(const Key('plan-tile-marker')), findsNothing);
  });

  testWidgets('nhóm khoá theo id: đổi tên không dựng lại nhóm', (tester) async {
    final source = StateProvider<List<TeamWithPlans>>(
      (_) => [teamOf(1), teamOf(9, name: 'Chưa xếp team', synthetic: true)],
    );
    final container = await pumpTeams(tester, const [], provider: source);
    expect(find.byKey(const ValueKey('team-team-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('team-synthetic')), findsOneWidget);

    final before = tester.element(find.byKey(const ValueKey('team-team-1')));
    container.read(source.notifier).state = [
      teamOf(1, name: 'Team một'),
      teamOf(9, name: 'Chưa xếp team', synthetic: true),
    ];
    await tester.pumpAndSettle();
    expect(find.text('Team một'), findsOneWidget);
    expect(
      identical(
        tester.element(find.byKey(const ValueKey('team-team-1'))),
        before,
      ),
      isTrue,
    );
  });

  testWidgets('menu Tạo mới: namesRoute + nhãn "Tạo mới"', (tester) async {
    await pumpTeams(tester, [teamOf(1)]);
    await tester.tap(find.bySemanticsLabel('Tạo mới'));
    await tester.pumpAndSettle();

    final menu = find.byWidgetPredicate(
      (w) =>
          w is Semantics &&
          w.properties.namesRoute == true &&
          w.properties.label == 'Tạo mới',
    );
    expect(menu, findsOneWidget);
    expect(find.text('Tạo kế hoạch'), findsOneWidget);
  });
}
