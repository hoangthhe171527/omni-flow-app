import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/plans/application/plans_providers.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/modules/plans/data/plans_api.dart';
import 'package:omni_app/modules/plans/domain/feed_entry.dart';
import 'package:omni_app/modules/plans/domain/plan.dart';
import 'package:omni_app/modules/plans/domain/workshop_kpi.dart';
import 'package:omni_app/modules/plans/domain/team.dart';
import 'package:omni_app/modules/plans/presentation/create_plan_page.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';

void main() {
  late _RecordingApi api;

  setUp(() => api = _RecordingApi());

  Widget host({List<TeamWithPlans> teams = const []}) => ProviderScope(
    overrides: [
      plansApiProvider.overrideWithValue(api),
      teamsWithPlansProvider.overrideWith((ref) async => teams),
    ],
    child: MaterialApp(
      theme: OmniTheme.light(TargetPlatform.android),
      home: const CreatePlanPage(),
    ),
  );

  testWidgets('điền sẵn năm công đoạn của xưởng', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    for (final name in kWorkshopSections) {
      expect(
        find.text(name),
        findsOneWidget,
        reason:
            'Xưởng này chạy đúng năm công đoạn đó. Bắt gõ lại năm lần cho mỗi '
            'kế hoạch mới là bắt làm một việc form đã biết trước câu trả lời.',
      );
    }
  });

  testWidgets('chưa có tên thì không lưu được', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));

    expect(button.onPressed, isNull);
  });

  testWidgets('có tên rồi thì lưu được, và gửi đúng các công đoạn', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Đàn cơ');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Tạo kế hoạch'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tạo kế hoạch'));
    await tester.pumpAndSettle();

    expect(api.createdName, 'Đàn cơ');
    expect(api.createdSections, kWorkshopSections);
  });

  testWidgets('tên chỉ có khoảng trắng không tính là có tên', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '   ');
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('công đoạn để trống thì bị bỏ, không gửi cột không tên', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Đàn điện');
    // Ô đầu tiên là tên kế hoạch, nên công đoạn thứ nhất là TextField thứ hai.
    await tester.enterText(find.byType(TextField).at(1), '   ');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Tạo kế hoạch'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tạo kế hoạch'));
    await tester.pumpAndSettle();

    expect(
      api.createdSections,
      isNot(contains('')),
      reason: 'Một cột không tên trên bảng thì vô dụng.',
    );
    expect(api.createdSections?.length, kWorkshopSections.length - 1);
  });

  testWidgets('chưa có team nào thì không hỏi thuộc team nào', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(
      find.text('Thuộc team'),
      findsNothing,
      reason:
          'Một ô chọn rỗng chỉ làm người dùng tưởng mình thiếu bước nào đó.',
    );
  });

  testWidgets('có team thì hỏi, và mặc định là chưa thuộc team nào', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        teams: [
          const TeamWithPlans(
            team: Team(id: 't1', name: 'Xưởng TNP'),
            plans: [],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Thuộc team'), findsOneWidget);
    expect(find.text('Chưa thuộc team nào'), findsOneWidget);
  });
}

/// Ghi lại tham số của lần gọi tạo, không đi mạng.
class _RecordingApi implements PlansApi {
  String? createdName;
  List<String>? createdSections;
  String? createdTeamId;

  @override
  Future<Plan> createPlan({
    required String name,
    String? teamId,
    List<String> sectionNames = const [],
    Set<String> gatedSectionNames = const {},
  }) async {
    createdName = name;
    createdTeamId = teamId;
    createdSections = sectionNames;

    return Plan.fromJson({'id': 'p1', 'name': name});
  }

  @override
  Future<Team> createTeam({required String name, String? description}) async =>
      Team.fromJson({'id': 't1', 'name': name});

  @override
  Future<WorkshopKpi> kpi({String? planId}) async =>
      WorkshopKpi.fromJson(const {});

  @override
  Future<List<FeedEntry>> feed({int limit = 30}) async => const [];

  @override
  Future<List<Team>> teams() async => const [];

  @override
  Future<List<Plan>> plans({String? teamId}) async => const [];

  @override
  Future<Plan> plan(String id) async => Plan.fromJson({'id': id, 'name': 'X'});

  @override
  Future<Paged<Task>> tasksInPlan(
    String planId, {
    int page = 1,
    int perPage = 50,
  }) async => Paged(items: const [], pagination: const ApiPagination.empty());
}
