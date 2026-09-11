import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/plans/data/plans_api.dart';
import 'package:omni_app/modules/plans/domain/plan.dart';
import 'package:omni_app/modules/plans/domain/team.dart';
import 'package:omni_app/modules/plans/domain/workshop_kpi.dart';
import 'package:omni_app/modules/plans/presentation/create_plan_page.dart';
import 'package:omni_app/modules/plans/presentation/create_team_page.dart';
import 'package:omni_app/modules/team/application/team_providers.dart';
import 'package:omni_app/modules/team/domain/team_member.dart';

/// Tạo team xong không được rơi vào hư không.
///
/// Trước bản này màn "Team mới" chỉ có tên + mô tả rồi `pop`. Người vừa tạo
/// quay lại một danh sách, và cái team vừa tạo TRỐNG RỖNG: không người, không
/// dự án. Muốn dùng được nó họ phải tự đoán ra hai bước tiếp theo và tự đi tìm
/// hai màn khác.
void main() {
  Future<_FakePlansApi> pump(WidgetTester tester) async {
    final api = _FakePlansApi();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          plansApiProvider.overrideWithValue(api),
          teamMembersProvider.overrideWith(
            (ref) async => [
              TeamMember.fromJson(
                const {'id': 'm-1', 'user_id': 'u-1'},
                const {'full_name': 'Hằng Ni'},
              ),
              TeamMember.fromJson(
                const {'id': 'm-2', 'user_id': 'u-2'},
                const {'full_name': 'Tuấn'},
              ),
            ],
          ),
        ],
        child: MaterialApp(
          theme: OmniTheme.light(TargetPlatform.android),
          home: const CreateTeamPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    return api;
  }

  Future<void> nameAndSave(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).first, 'Tổ phục chế');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Tạo team'));
    await tester.pumpAndSettle();
  }

  testWidgets('ô Thành viên nói rõ bỏ qua được', (tester) async {
    await pump(tester);

    expect(find.text('Chưa chọn ai — thêm sau cũng được'), findsOneWidget);
  });

  testWidgets('bỏ qua thành viên vẫn tạo được team', (tester) async {
    final api = await pump(tester);
    await nameAndSave(tester);

    expect(api.createdTeamName, 'Tổ phục chế');
    // Không chọn ai thì gửi một tập RỖNG, và PlansApi sẽ bỏ khoá đi.
    expect(api.createdMemberIds, isEmpty);
  });

  testWidgets('tạo team xong đi thẳng sang màn tạo dự án', (tester) async {
    await pump(tester);
    await nameAndSave(tester);

    expect(find.byType(CreatePlanPage), findsOneWidget);
  });

  testWidgets('màn dự án nhận sẵn team vừa tạo', (tester) async {
    await pump(tester);
    await nameAndSave(tester);

    final page = tester.widget<CreatePlanPage>(find.byType(CreatePlanPage));

    expect(page.teamId, 'team-1');
  });

  testWidgets('Back từ màn dự án KHÔNG quay lại form tạo team', (tester) async {
    // pushReplacement, không push: quay lại một form đã dùng xong rồi bấm
    // "Tạo team" lần nữa là tạo một team trùng tên mà người dùng không định.
    await pump(tester);
    await nameAndSave(tester);

    expect(find.byType(CreateTeamPage), findsNothing);
  });

  testWidgets('chọn người rồi thì ô hiện số lượng', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Chưa chọn ai — thêm sau cũng được'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hằng Ni'));
    await tester.pump();
    await tester.tap(find.textContaining('Xong ('));
    await tester.pumpAndSettle();

    expect(find.text('1 người'), findsOneWidget);
  });

  testWidgets('người đã chọn ĐI THEO tới lượt gọi API', (tester) async {
    // Mối nối dễ đứt nhất của tính năng này: API nhận `member_ids` từ lâu, app
    // chỉ chưa bao giờ gửi. Chọn trên màn mà không tới server thì im lặng.
    final api = await pump(tester);

    await tester.tap(find.text('Chưa chọn ai — thêm sau cũng được'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hằng Ni'));
    await tester.pump();
    await tester.tap(find.textContaining('Xong ('));
    await tester.pumpAndSettle();

    await nameAndSave(tester);

    expect(api.createdMemberIds, contains('u-1'));
  });
}

class _FakePlansApi implements PlansApi {
  String? createdTeamName;
  Set<String>? createdMemberIds;

  @override
  Future<Team> createTeam({
    required String name,
    String? description,
    Set<String> memberIds = const {},
  }) async {
    createdTeamName = name;
    createdMemberIds = memberIds;

    return Team.fromJson({'id': 'team-1', 'name': name});
  }

  @override
  Future<List<Team>> teams() async => const [];

  @override
  Future<List<Plan>> plans({String? teamId}) async => const [];

  @override
  Future<WorkshopKpi> kpi({String? planId, DateTime? month}) async =>
      WorkshopKpi.fromJson(const {});

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
