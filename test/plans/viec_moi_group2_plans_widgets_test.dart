import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/design/theme/omni_theme.dart';

import 'package:omni_app/modules/plans/application/plans_providers.dart';
import 'package:omni_app/modules/plans/data/plans_api.dart';
import 'package:omni_app/modules/plans/domain/plan.dart';
import 'package:omni_app/modules/plans/domain/team.dart';
import 'package:omni_app/modules/plans/domain/workshop_kpi.dart';
import 'package:omni_app/modules/plans/presentation/plan_board_page.dart';
import 'package:omni_app/modules/plans/presentation/teams_page.dart';
import 'package:omni_app/modules/plans/presentation/widgets/plan_menu_sheet.dart';
import 'package:omni_app/modules/plans/routes.dart';
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

/// Nhóm 2 phía kế hoạch (Task 10), cặp đôi "thiếu khoá → không có nút /
/// có khoá → có nút và gửi đúng":
///  * sao Yêu thích trên dòng kế hoạch và mục "Yêu thích" đầu tab Việc;
///  * "Chuyển chủ kế hoạch" trong menu kế hoạch.
void main() {
  const worker = {'tasks.read', 'tasks.write'};
  const assigner = {'tasks.read', 'tasks.write', 'tasks.projects.manage.all'};

  Plan plan(String name, {bool? favorite, int total = 6, int done = 2}) =>
      Plan.fromJson({
        'id': 'id-$name',
        'name': name,
        'stats': {'total': total, 'done': done, 'overdue': 0},
        'is_favorite': ?favorite,
      });

  group('tab Việc — Yêu thích', () {
    late _FavoriteApi api;

    Future<void> pump(
      WidgetTester t,
      List<TeamWithPlans> groups, {
      bool fail = false,
    }) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      api = _FavoriteApi(fail: fail);
      final policy = AccessPolicy(worker);
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const TeamsPage()),
          GoRoute(
            path: '/plans/:id',
            name: PlanRoutes.board,
            builder: (_, _) => const Scaffold(body: Text('trang bang')),
          ),
          GoRoute(
            path: '/timeline',
            name: PlanRoutes.timeline,
            builder: (_, _) => const Scaffold(),
          ),
        ],
      );
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            backgroundProvider.overrideWith(FixedBackground.new),
            plansApiProvider.overrideWithValue(api),
            teamsWithPlansProvider.overrideWith((ref) async => groups),
            workshopKpiProvider.overrideWith(
              (ref) async => WorkshopKpi.fromJson(const {}),
            ),
            taskAccessProvider.overrideWithValue(TaskAccess.of(policy)),
            accessProvider.overrideWithValue(policy),
          ],
          child: MaterialApp.router(
            theme: OmniTheme.light(TargetPlatform.android),
            routerConfig: router,
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    TeamWithPlans team(List<Plan> plans) => TeamWithPlans(
      team: const Team(id: 't1', name: 'Tổ kỹ thuật'),
      plans: plans,
    );

    testWidgets('API cũ (không is_favorite): không sao, không mục Yêu thích', (
      t,
    ) async {
      await pump(t, [
        team([plan('Bảo hành'), plan('Sửa tại nhà')]),
      ]);
      expect(find.bySemanticsLabel('Thêm vào yêu thích'), findsNothing);
      expect(find.bySemanticsLabel('Bỏ khỏi yêu thích'), findsNothing);
      expect(find.text('Yêu thích'), findsNothing);
      expect(
        find.byIcon(Icons.chevron_right_rounded),
        findsNWidgets(3),
      ); // 2 dòng + thẻ Dòng việc
    });

    testWidgets('API mới: sao trên mỗi dòng; mục Yêu thích có số, "Team · N '
        'việc", ›', (t) async {
      await pump(t, [
        team([plan('Bảo hành', favorite: true), plan('Sửa', favorite: false)]),
      ]);
      expect(find.bySemanticsLabel('Bỏ khỏi yêu thích'), findsOneWidget);
      expect(find.bySemanticsLabel('Thêm vào yêu thích'), findsOneWidget);
      expect(find.text('Yêu thích'), findsOneWidget);
      expect(find.text('Tổ kỹ thuật · 4 việc'), findsOneWidget);
      // Sao bật màu `star` 19, sao tắt viền `faint`.
      final on = t.widget<Icon>(find.byIcon(Icons.star_rounded).last);
      expect(on.size, 19);
      expect(on.color, const Color(0xFFE8890C));
      final off = t.widget<Icon>(find.byIcon(Icons.star_outline_rounded));
      expect(off.color, const Color(0xFF9AA5B8));
      // Vùng chạm 44.
      expect(
        t.getSize(find.byKey(const Key('plan-favorite-id-Sửa'))),
        const Size(44, 44),
      );
    });

    testWidgets('bấm sao: POST favorite, mục Yêu thích hiện ngay; bấm lại '
        'DELETE', (t) async {
      await pump(t, [
        team([plan('Sửa', favorite: false)]),
      ]);
      expect(find.text('Yêu thích'), findsNothing);
      await t.tap(find.byKey(const Key('plan-favorite-id-Sửa')));
      await t.pumpAndSettle();
      expect(api.calls, [('id-Sửa', true)]);
      expect(find.text('Yêu thích'), findsOneWidget);
      expect(find.bySemanticsLabel('Bỏ khỏi yêu thích'), findsOneWidget);

      await t.tap(find.byKey(const Key('plan-favorite-id-Sửa')));
      await t.pumpAndSettle();
      expect(api.calls.last, ('id-Sửa', false));
      expect(find.text('Yêu thích'), findsNothing);
    });

    testWidgets('lỗi: hoàn tác sao và báo', (t) async {
      await pump(t, [
        team([plan('Sửa', favorite: false)]),
      ], fail: true);
      await t.tap(find.byKey(const Key('plan-favorite-id-Sửa')));
      await t.pumpAndSettle();
      expect(find.bySemanticsLabel('Thêm vào yêu thích'), findsOneWidget);
      expect(find.text('Yêu thích'), findsNothing);
      expect(find.text('Không có quyền.'), findsOneWidget);
    });

    testWidgets('gập mục Yêu thích; tìm cũng lọc mục này', (t) async {
      await pump(t, [
        team([
          plan('Bảo hành', favorite: true),
          plan('Sự kiện', favorite: true),
        ]),
      ]);
      expect(find.byKey(const ValueKey('favorite-id-Bảo hành')), findsOne);
      await t.tap(find.byKey(const Key('favorites-header')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('favorite-id-Bảo hành')), findsNothing);
      await t.tap(find.byKey(const Key('favorites-header')));
      await t.pumpAndSettle();

      await t.enterText(find.byType(TextField), 'su kien');
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('favorite-id-Sự kiện')), findsOne);
      expect(find.byKey(const ValueKey('favorite-id-Bảo hành')), findsNothing);
    });
  });

  group('menu kế hoạch — Chuyển chủ', () {
    test('planMenuGroups: chỉ có khi canTransferOwner, ở đầu nhóm 3', () {
      final p = plan('X', favorite: false);
      final without = planMenuGroups(
        p,
        canManage: true,
        canDelete: false,
        canViewLabels: false,
      );
      expect(
        without.expand((g) => g),
        isNot(contains(PlanMenuAction.transferOwner)),
      );
      final withIt = planMenuGroups(
        p,
        canManage: true,
        canDelete: false,
        canViewLabels: false,
        canTransferOwner: true,
      );
      expect(withIt.last.first, PlanMenuAction.transferOwner);
    });

    late _OwnerApi api;

    Future<void> pump(
      WidgetTester t, {
      required bool newApi,
      required String me,
      Set<String> perms = worker,
    }) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      api = _OwnerApi(
        Plan.fromJson({
          'id': 'p1',
          'name': 'Bảo hành',
          'owner_id': 'u-owner',
          'member_ids': ['u-mgr', 'u-2'],
          'member_roles': {'u-mgr': 'manager'},
          'sections': [
            {'id': 's1', 'name': 'Tiếp nhận', 'order': 0},
          ],
          'is_favorite': ?(newApi ? false : null),
        }),
      );
      final router = GoRouter(
        initialLocation: '/plans/p1',
        routes: [
          GoRoute(
            path: '/teams',
            name: PlanRoutes.teams,
            builder: (_, _) => const Scaffold(),
          ),
          GoRoute(
            path: '/plans/:id',
            name: PlanRoutes.board,
            builder: (_, state) =>
                PlanBoardPage(planId: state.pathParameters['id']!),
          ),
        ],
      );
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            plansApiProvider.overrideWithValue(api),
            tasksApiProvider.overrideWithValue(_NoArchivedApi()),
            planTasksProvider.overrideWith(
              (ref, id) async => (tasks: <Task>[], truncated: false),
            ),
            teamsWithPlansProvider.overrideWith((ref) async => const []),
            taskLabelsProvider.overrideWith((ref) async => const []),
            backgroundProvider.overrideWith(FixedBackground.new),
            teamDirectoryProvider.overrideWith(
              (ref) async => const [
                TeamMember(
                  membershipId: 'm0',
                  userId: 'u-owner',
                  name: 'Trung Nguyên',
                ),
                TeamMember(membershipId: 'm2', userId: 'u-2', name: 'Khánh'),
              ],
            ),
            sessionProvider.overrideWithValue(
              Session(
                status: SessionStatus.authenticated,
                user: SessionUser(id: me, fullName: 'Tôi', email: 'me@x.vn'),
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
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Tuỳ chọn kế hoạch'));
      await t.pumpAndSettle();
    }

    testWidgets('API cũ: chủ kế hoạch cũng không thấy "Chuyển chủ"', (t) async {
      await pump(t, newApi: false, me: 'u-owner');
      expect(find.text('Chuyển chủ kế hoạch'), findsNothing);
    });

    testWidgets('API mới: quản lý kế hoạch (không phải chủ) không thấy', (
      t,
    ) async {
      await pump(t, newApi: true, me: 'u-mgr');
      expect(find.text('Sửa tên, mô tả, nền'), findsOneWidget);
      expect(find.text('Chuyển chủ kế hoạch'), findsNothing);
    });

    testWidgets('API mới, manage.all: thấy', (t) async {
      await pump(t, newApi: true, me: 'u-x', perms: assigner);
      expect(find.text('Chuyển chủ kế hoạch'), findsOneWidget);
    });

    testWidgets('API mới, chủ: chọn Khánh, hỏi lại, gửi owner_id', (t) async {
      await pump(t, newApi: true, me: 'u-owner');
      await t.tap(find.text('Chuyển chủ kế hoạch'));
      await t.pumpAndSettle();
      // Chủ hiện tại không nằm trong danh sách chọn.
      expect(find.byKey(const ValueKey('owner-u-owner')), findsNothing);
      await t.tap(find.text('Khánh'));
      await t.pumpAndSettle();
      expect(find.text('Chuyển chủ cho Khánh?'), findsOneWidget);
      await t.tap(find.text('Chuyển chủ'));
      await t.pumpAndSettle();
      expect(api.transfers, [('p1', 'u-2')]);
      expect(find.text('Đã chuyển chủ cho Khánh.'), findsOneWidget);
    });
  });
}

class _FavoriteApi implements PlansApi {
  _FavoriteApi({this.fail = false});

  final bool fail;
  final calls = <(String, bool)>[];

  @override
  Future<bool> setFavorite(String planId, bool favorite) async {
    calls.add((planId, favorite));
    if (fail) throw const ForbiddenException('Không có quyền.');
    return favorite;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _OwnerApi implements PlansApi {
  _OwnerApi(this._plan);

  final Plan _plan;
  final transfers = <(String, String)>[];

  @override
  Future<Plan> plan(String id) async => _plan;

  @override
  Future<WorkshopKpi> kpi({String? planId, DateTime? month}) async =>
      WorkshopKpi.fromJson(const {});

  @override
  Future<Plan> transferOwner(
    String planId, {
    required String ownerId,
    PlanRole? previousOwnerRole,
  }) async {
    transfers.add((planId, ownerId));
    return _plan;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoArchivedApi implements TasksApi {
  @override
  Future<Paged<Task>> list({
    required String projectId,
    String? search,
    TaskArchiveScope archived = TaskArchiveScope.active,
    int page = 1,
    int perPage = 100,
  }) async => const Paged(items: [], pagination: ApiPagination.empty());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
