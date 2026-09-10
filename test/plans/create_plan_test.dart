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

  /// Cuộn xuống cho tới khi nút "Tạo dự án" được DỰNG.
  ///
  /// Màn này là một `ListView`, nên widget dưới vùng nhìn thấy không tồn tại
  /// trong cây — `ensureVisible` không cứu được vì nó cần widget đã có. Từ khi
  /// màn thêm dải xem trước nền (120dp) thì nút rơi hẳn xuống dưới trong cửa
  /// sổ kiểm 800×600.
  Future<void> revealSave(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('Tạo dự án'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('điền sẵn bộ nhóm việc mặc định', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    for (final name in kDefaultSections) {
      // Cuộn tới từng cái: `ListView` không dựng thứ nằm dưới vùng nhìn thấy,
      // và từ khi màn có dải xem trước nền thì nhóm việc cuối rơi xuống dưới.
      await tester.scrollUntilVisible(
        find.text(name),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(
        find.text(name),
        findsOneWidget,
        reason:
            'Bộ mặc định phải CHUNG, không theo ngành nào: app dùng cho nhiều '
            'loại công việc, và mọi tenant mới đều nhận đúng những chữ này. '
            'Bắt gõ lại cho mỗi dự án mới là bắt làm một việc form đã biết '
            'trước câu trả lời.',
      );
    }
  });

  testWidgets('chưa có tên thì không lưu được', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await revealSave(tester);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));

    expect(button.onPressed, isNull);
  });

  testWidgets('có tên rồi thì lưu được, và gửi đúng các nhóm việc', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Đàn cơ');
    await tester.pumpAndSettle();
    await revealSave(tester);
    await tester.tap(find.text('Tạo dự án'));
    await tester.pumpAndSettle();

    expect(api.createdName, 'Đàn cơ');
    expect(api.createdSections, kDefaultSections);
  });

  testWidgets('tên chỉ có khoảng trắng không tính là có tên', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '   ');
    await tester.pumpAndSettle();

    await revealSave(tester);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('nhóm việc để trống thì bị bỏ, không gửi cột không tên', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Đàn điện');
    // Ô đầu tiên là tên dự án, nên công đoạn thứ nhất là TextField thứ hai.
    await tester.enterText(find.byType(TextField).at(1), '   ');
    await tester.pumpAndSettle();
    await revealSave(tester);
    await tester.tap(find.text('Tạo dự án'));
    await tester.pumpAndSettle();

    expect(
      api.createdSections,
      isNot(contains('')),
      reason: 'Một cột không tên trên bảng thì vô dụng.',
    );
    expect(api.createdSections?.length, kDefaultSections.length - 1);
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
  @override
  Future<Plan> updateSections(String planId, List<PlanSection> sections) async {
    throw UnimplementedError();
  }

  String? createdName;
  List<String>? createdSections;
  String? createdTeamId;

  String? createdCover;
  Set<String>? createdMemberIds;

  @override
  Future<Plan> createPlan({
    required String name,
    String? teamId,
    List<String> sectionNames = const [],
    Set<String> gatedSectionNames = const {},
    String? cover,
  }) async {
    createdName = name;
    createdTeamId = teamId;
    createdSections = sectionNames;
    createdCover = cover;

    return Plan.fromJson({'id': 'p1', 'name': name});
  }

  @override
  Future<Team> createTeam({
    required String name,
    String? description,
    Set<String> memberIds = const {},
  }) async {
    createdMemberIds = memberIds;

    return Team.fromJson({'id': 't1', 'name': name});
  }

  @override
  Future<WorkshopKpi> kpi({String? planId, DateTime? month}) async =>
      WorkshopKpi.fromJson(const {});

  @override
  Future<WorkshopFeed> feed({
    List<String> types = const [],
    int days = 7,
    int limit = 30,
  }) async => (entries: const <FeedEntry>[], truncated: false);

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
