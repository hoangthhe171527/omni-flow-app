import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/plans/application/plans_providers.dart';
import 'package:omni_app/modules/plans/data/plans_api.dart';
import 'package:omni_app/modules/plans/domain/plan.dart';
import 'package:omni_app/modules/plans/domain/team.dart';
import 'package:omni_app/modules/plans/presentation/widgets/quick_create_sheets.dart';
import 'package:omni_app/modules/team/application/team_providers.dart';
import 'package:omni_app/modules/team/domain/team_member.dart';

/// Tạo nhanh ở tab Việc (viec-quick-create-uiux.html): sheet ngay trên màn,
/// team chọn bằng danh sách dọc (không cuộn ngang), team xong nối sang kế
/// hoạch đầu tiên.
void main() {
  late _RecordingApi api;
  QuickCreated? result;
  var resolved = false;

  setUp(() {
    api = _RecordingApi();
    result = null;
    resolved = false;
  });

  void phone(WidgetTester t) {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
  }

  Widget host(
    Future<QuickCreated?> Function(BuildContext) open, {
    List<TeamWithPlans> groups = const [],
  }) => ProviderScope(
    overrides: [
      plansApiProvider.overrideWithValue(api),
      teamsWithPlansProvider.overrideWith((ref) async => groups),
      teamMembersProvider.overrideWith(
        (ref) async => const [
          TeamMember(membershipId: 'm1', userId: 'u1', name: 'Duy Đức'),
          TeamMember(membershipId: 'm2', userId: 'u2', name: 'Hằng Ni'),
        ],
      ),
      teamMemberByIdProvider.overrideWithValue(const {
        'u1': TeamMember(membershipId: 'm1', userId: 'u1', name: 'Duy Đức'),
        'u2': TeamMember(membershipId: 'm2', userId: 'u2', name: 'Hằng Ni'),
      }),
    ],
    child: MaterialApp(
      theme: OmniTheme.light(TargetPlatform.android),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                result = await open(context);
                resolved = true;
              },
              child: const Text('mở'),
            ),
          ),
        ),
      ),
    ),
  );

  final teams = [
    TeamWithPlans(
      team: Team(id: 't-kt', name: 'Tổ kỹ thuật'),
      plans: const [],
    ),
    TeamWithPlans(
      team: Team(id: 't-kd', name: 'Kinh doanh'),
      plans: const [],
    ),
  ];

  testWidgets('kế hoạch: gõ tên, chọn team trong danh sách dọc, tạo', (
    t,
  ) async {
    phone(t);
    await t.pumpWidget(host(showQuickCreatePlan, groups: teams));
    await t.tap(find.text('mở'));
    await t.pumpAndSettle();

    expect(find.byKey(const Key('quick-create-plan')), findsOneWidget);
    // Nút tạo chờ có tên.
    expect(
      t
          .widget<FilledButton>(find.byKey(const Key('quick-plan-save')))
          .onPressed,
      isNull,
    );
    // Không có dải chip cuộn ngang.
    expect(
      find.byWidgetPredicate(
        (w) => w is ListView && w.scrollDirection == Axis.horizontal,
      ),
      findsNothing,
    );

    await t.enterText(find.byKey(const Key('quick-plan-name')), 'Đàn cơ');
    await t.tap(find.byKey(const Key('quick-plan-team')));
    await t.pumpAndSettle();
    await t.tap(find.text('Kinh doanh'));
    await t.pumpAndSettle();
    // Chọn xong tự gập, dòng hiện tên team.
    expect(find.text('Tổ kỹ thuật'), findsNothing);
    expect(find.text('Kinh doanh'), findsOneWidget);

    await t.tap(find.byKey(const Key('quick-plan-save')));
    await t.pumpAndSettle();

    expect(api.createdName, 'Đàn cơ');
    expect(api.createdTeamId, 't-kd');
    expect(api.createdSections, ['Cần làm', 'Đang làm', 'Chờ duyệt', 'Xong']);
    expect(resolved, isTrue);
    expect(result, (id: 'p1', name: 'Đàn cơ', isTeam: false));
  });

  testWidgets('kế hoạch: bỏ và thêm nhóm việc ngay trong sheet', (t) async {
    phone(t);
    await t.pumpWidget(host(showQuickCreatePlan));
    await t.tap(find.text('mở'));
    await t.pumpAndSettle();

    await t.enterText(find.byKey(const Key('quick-plan-name')), 'Sofa');
    await t.tap(find.byKey(const Key('quick-plan-sections')));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Bỏ nhóm Chờ duyệt'));
    await t.pumpAndSettle();
    await t.enterText(
      find.byKey(const Key('quick-plan-new-section')),
      'Giao hàng',
    );
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('quick-plan-save')));
    await t.pumpAndSettle();

    expect(api.createdSections, ['Cần làm', 'Đang làm', 'Xong', 'Giao hàng']);
  });

  testWidgets('team: tạo xong chuyển sang kế hoạch đầu tiên, team chọn sẵn', (
    t,
  ) async {
    phone(t);
    await t.pumpWidget(host(showQuickCreateTeam));
    await t.tap(find.text('mở'));
    await t.pumpAndSettle();

    await t.enterText(find.byKey(const Key('quick-team-name')), 'Tổ lắp đặt');
    await t.tap(find.byKey(const Key('quick-team-members')));
    await t.pumpAndSettle();
    await t.tap(find.text('Hằng Ni'));
    await t.pumpAndSettle();
    expect(find.text('1 người'), findsOneWidget);

    await t.tap(find.byKey(const Key('quick-team-save')));
    await t.pumpAndSettle();
    expect(api.createdTeamName, 'Tổ lắp đặt');
    expect(api.createdMemberIds, {'u2'});

    // Cùng sheet, bước kế hoạch: không có dòng chọn team, có "Để sau".
    expect(find.byKey(const Key('quick-team-created')), findsOneWidget);
    expect(find.byKey(const Key('quick-plan-team')), findsNothing);
    expect(find.text('Để sau'), findsOneWidget);

    await t.enterText(find.byKey(const Key('quick-plan-name')), 'Lắp tủ');
    await t.ensureVisible(find.byKey(const Key('quick-plan-save')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('quick-plan-save')));
    await t.pumpAndSettle();
    expect(api.createdTeamId, 't1');
    expect(result, (id: 'p1', name: 'Lắp tủ', isTeam: false));
  });

  testWidgets('team: "Để sau" trả về team, không tạo kế hoạch', (t) async {
    phone(t);
    await t.pumpWidget(host(showQuickCreateTeam));
    await t.tap(find.text('mở'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('quick-team-name')), 'Tổ sơn');
    await t.pump();
    await t.tap(find.byKey(const Key('quick-team-save')));
    await t.pumpAndSettle();
    expect(api.createdTeamName, 'Tổ sơn');
    expect(find.byKey(const Key('quick-create-plan')), findsOneWidget);
    await t.ensureVisible(find.text('Để sau'));
    await t.pumpAndSettle();
    await t.tap(find.text('Để sau'));
    await t.pumpAndSettle();

    expect(api.createPlanCalls, 0);
    expect(result, (id: 't1', name: 'Tổ sơn', isTeam: true));
  });
}

/// Ghi lại lần gọi tạo, không đi mạng.
class _RecordingApi implements PlansApi {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  String? createdName;
  String? createdTeamId;
  List<String>? createdSections;
  int createPlanCalls = 0;
  String? createdTeamName;
  Set<String>? createdMemberIds;

  @override
  Future<Plan> createPlan({
    required String name,
    String? teamId,
    List<String> sectionNames = const [],
    Set<String> gatedSectionNames = const {},
    String? cover,
  }) async {
    createPlanCalls++;
    createdName = name;
    createdTeamId = teamId;
    createdSections = sectionNames;
    return Plan.fromJson({'id': 'p1', 'name': name});
  }

  @override
  Future<Team> createTeam({
    required String name,
    String? description,
    Set<String> memberIds = const {},
  }) async {
    createdTeamName = name;
    createdMemberIds = memberIds;
    return Team.fromJson({'id': 't1', 'name': name});
  }
}
