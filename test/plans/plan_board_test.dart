import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/plans/presentation/widgets/board_column.dart';
import 'package:omni_app/modules/plans/application/plans_providers.dart';
import 'package:omni_app/modules/plans/domain/plan.dart';
import 'package:omni_app/modules/plans/presentation/plan_board_page.dart';
import 'package:omni_app/modules/settings/application/appearance_providers.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/domain/task_permissions.dart';
import 'package:omni_app/modules/team/team.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

import '../support/fixed_background.dart';

/// Màn quan trọng nhất của người giao việc, và là chỗ tôi từng sai.
///
/// Tôi đã nói "điện thoại không hợp kanban". Ảnh chụp myXteam của người dùng
/// chứng minh ngược lại — cách làm đúng là PHÂN TRANG, không phải cuộn ngang
/// tự do. Những bài dưới đây canh chính chỗ khác nhau đó.
void main() {
  const planId = 'p1';

  final plan = Plan.fromJson({
    'id': planId,
    'name': 'Đàn cơ',
    'sections': [
      {'id': 's1', 'name': 'Nhập xưởng', 'order': 0},
      {'id': 's2', 'name': 'Đang phục chế', 'order': 1},
      {'id': 's3', 'name': 'Chờ QC', 'order': 2},
    ],
  });

  Task task(String id, String title, {String? sectionId}) => Task.fromJson({
    'id': id,
    'title': title,
    'section_id': ?sectionId,
    'project_name': 'Đàn cơ',
  });

  Widget host({
    required Plan plan,
    required List<Task> tasks,
    bool disableAnimations = false,
  }) => ProviderScope(
    overrides: [
      planProvider(planId).overrideWith((ref) async => plan),
      planTasksProvider(
        planId,
      ).overrideWith((ref) async => (tasks: tasks, truncated: false)),
      backgroundProvider.overrideWith(FixedBackground.new),
      teamDirectoryProvider.overrideWith((ref) async => const <TeamMember>[]),
    ],
    child: MaterialApp(
      theme: OmniTheme.light(TargetPlatform.android),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: const PlanBoardPage(planId: planId),
      ),
    ),
  );

  testWidgets('thẻ KHÔNG lặp lại tên dự án', (tester) async {
    // Tiêu đề màn đã là "Đàn cơ", và cả bảng chỉ thuộc một dự án. In lại
    // trên từng thẻ là ba dòng giống hệt nhau trên một màn hình bằng bàn tay.
    await tester.pumpWidget(
      host(
        plan: plan,
        tasks: [
          task('t1', 'KAWAI HAT-5', sectionId: 's1'),
          task('t2', 'YAMAHA U1H', sectionId: 's1'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // Đúng một lần: ở tiêu đề màn.
    expect(find.text('Đàn cơ'), findsOneWidget);
    expect(find.text('KAWAI HAT-5'), findsOneWidget);
  });

  testWidgets('nhóm việc rỗng vẫn là một cột, đếm 0', (tester) async {
    await tester.pumpWidget(host(plan: plan, tasks: const []));
    await tester.pumpAndSettle();

    expect(find.byType(BoardColumn, skipOffstage: false), findsNWidgets(3));
    expect(
      find.descendant(
        of: find.byKey(const Key('column-count')).first,
        matching: find.text('0'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('việc không thuộc nhóm nào rơi vào cột đầu, không biến mất', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(plan: plan, tasks: [task('t9', 'Cây chưa xếp công đoạn')]),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Cây chưa xếp công đoạn'),
      findsOneWidget,
      reason: 'Một cây đàn không ai thấy là một cây đàn không ai làm.',
    );
  });

  testWidgets('việc thuộc một nhóm ĐÃ BỊ XOÁ cũng rơi vào cột đầu', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        plan: plan,
        tasks: [task('t9', 'Cây mồ côi', sectionId: 'nhóm-đã-xoá')],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cây mồ côi'), findsOneWidget);
  });

  testWidgets('dự án chưa có nhóm việc nào vẫn xem được', (tester) async {
    final bare = Plan.fromJson({'id': planId, 'name': 'Dự án trống'});

    await tester.pumpWidget(
      host(plan: bare, tasks: [task('t1', 'Một cây đàn')]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tất cả công việc'), findsOneWidget);
    expect(find.text('Một cây đàn'), findsOneWidget);
  });
  // API cho chủ/quản lý DỰ ÁN sửa nhóm việc, không chỉ người có
  // `tasks.projects.manage.all` (CV-I14). Giờ nằm trong menu ⋯.
  group('menu ⋯ Tuỳ chọn kế hoạch', () {
    Widget board(
      String role, {
      Set<String> perms = const {'tasks.read', 'tasks.write'},
    }) => ProviderScope(
      overrides: [
        planProvider(planId).overrideWith(
          (ref) async => Plan.fromJson({
            'id': planId,
            'name': 'Đàn cơ',
            'owner_id': 'u-owner',
            'member_ids': ['u-me'],
            'member_roles': {'u-me': role},
            'sections': [
              {'id': 's1', 'name': 'Nhập xưởng', 'order': 0},
              {'id': 's2', 'name': 'Đang sửa', 'order': 1},
            ],
          }),
        ),
        archivedTasksProvider(planId).overrideWith(
          (ref) async => (tasks: const <Task>[], truncated: false),
        ),
        planTasksProvider(
          planId,
        ).overrideWith((ref) async => (tasks: <Task>[], truncated: false)),
        backgroundProvider.overrideWith(FixedBackground.new),
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
      child: MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        home: const PlanBoardPage(planId: planId),
      ),
    );

    testWidgets('quản lý kế hoạch thấy menu sửa kế hoạch trong ⋯', (
      tester,
    ) async {
      await tester.pumpWidget(board('manager'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Sửa nhóm việc'), findsNothing);
      await tester.tap(find.byTooltip('Tuỳ chọn kế hoạch'));
      await tester.pumpAndSettle();
      expect(find.text('Sửa tên, mô tả, nền'), findsOneWidget);
      expect(find.text('Xoá kế hoạch'), findsNothing);
    });

    testWidgets('người giao việc có đủ Sửa kế hoạch + Xoá kế hoạch', (
      tester,
    ) async {
      await tester.pumpWidget(
        board(
          'member',
          perms: const {
            'tasks.read',
            'tasks.write',
            'tasks.projects.manage.all',
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Tuỳ chọn kế hoạch'));
      await tester.pumpAndSettle();
      expect(find.text('Sửa tên, mô tả, nền'), findsOneWidget);
      expect(find.text('Xoá kế hoạch'), findsOneWidget);
    });

    testWidgets('Xoá kế hoạch từ ⋯ mở hộp xác nhận', (tester) async {
      await tester.pumpWidget(
        board(
          'member',
          perms: const {
            'tasks.read',
            'tasks.write',
            'tasks.projects.manage.all',
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Tuỳ chọn kế hoạch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xoá kế hoạch'));
      await tester.pumpAndSettle();
      expect(find.text('Xoá kế hoạch “Đàn cơ”?'), findsOneWidget);
    });

    testWidgets('thành viên thường: ⋯ chỉ có ba mục đọc', (tester) async {
      await tester.pumpWidget(board('member'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Tuỳ chọn kế hoạch'));
      await tester.pumpAndSettle();
      expect(find.text('Việc đã lưu trữ'), findsOneWidget);
      expect(find.text('Tệp đính kèm'), findsOneWidget);
      expect(find.text('Báo cáo kế hoạch'), findsOneWidget);
      expect(find.text('Sửa tên, mô tả, nền'), findsNothing);
      expect(find.text('Xoá kế hoạch'), findsNothing);
    });
  });

  group('đầu bảng', () {
    final team = Plan.fromJson({
      'id': planId,
      'name': 'Sửa chữa đàn',
      'team_name': 'Tổ kỹ thuật',
      'sections': [
        {'id': 'a', 'name': 'Tiếp nhận', 'order': 0},
        {'id': 'b', 'name': 'Đang sửa', 'order': 1},
      ],
    });

    testWidgets('tên, "team · N việc"; lọc → thanh Đang lọc + Bỏ lọc', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          plan: team,
          tasks: [
            Task.fromJson(const {
              'id': 't1',
              'title': 'Một',
              'section_id': 'a',
              'assignee_ids': ['u1'],
            }),
            Task.fromJson(const {
              'id': 't2',
              'title': 'Hai',
              'section_id': 'a',
            }),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sửa chữa đàn'), findsOneWidget);
      expect(find.text('Tổ kỹ thuật · 2 việc'), findsOneWidget);

      await tester.tap(find.byTooltip('Lọc theo người'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chưa giao ai'));
      await tester.pumpAndSettle();
      expect(find.text('Tổ kỹ thuật · 1 việc'), findsOneWidget);
      expect(find.text('Bỏ lọc'), findsOneWidget);

      await tester.tap(find.text('Bỏ lọc'));
      await tester.pumpAndSettle();
      expect(find.text('Bỏ lọc'), findsNothing);
      expect(find.text('Tổ kỹ thuật · 2 việc'), findsOneWidget);
    });
  });
}
