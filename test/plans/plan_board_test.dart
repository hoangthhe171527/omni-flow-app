import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/plans/presentation/widgets/section_pager.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
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

  testWidgets('mỗi màn đúng MỘT nhóm việc, không hé cột bên cạnh', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        plan: plan,
        tasks: [
          task('t1', 'KAWAI HAT-5', sectionId: 's1'),
          task('t2', 'YAMAHA U3', sectionId: 's2'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final pageView = tester.widget<PageView>(find.byType(PageView));

    expect(
      pageView.controller?.viewportFraction,
      1.0,
      reason:
          'Hé cột bên cạnh làm chữ bị cắt và đọc như lỗi. Một cột chiếm trọn '
          'màn hình là điểm khác nhau giữa cách này và một cái kanban thu nhỏ.',
    );

    // Việc của nhóm 2 chưa được vẽ khi đang đứng ở nhóm 1.
    expect(find.text('KAWAI HAT-5'), findsOneWidget);
    expect(find.text('YAMAHA U3'), findsNothing);
  });

  testWidgets('chạm chỉ báo trang nhảy thẳng tới nhóm đó', (tester) async {
    await tester.pumpWidget(
      host(
        plan: plan,
        tasks: [task('t3', 'PETROF P118', sectionId: 's3')],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nhập xưởng'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Chờ QC'));
    await tester.pumpAndSettle();

    expect(
      find.text('PETROF P118'),
      findsOneWidget,
      reason: 'Vuốt bốn lần để tới cột cuối là bốn lần quá nhiều.',
    );
  });

  testWidgets('nhóm việc rỗng vẫn là một trang, và nói rõ là rỗng', (
    tester,
  ) async {
    await tester.pumpWidget(host(plan: plan, tasks: const []));
    await tester.pumpAndSettle();

    final pageView = tester.widget<PageView>(find.byType(PageView));

    expect(
      (pageView.childrenDelegate as SliverChildBuilderDelegate).childCount,
      3,
      reason:
          'Bỏ nhóm rỗng đi làm số trang lệch với số công đoạn, và người quản '
          'đốc mất đúng thông tin họ cần: công đoạn nào đang trống.',
    );
    expect(find.textContaining('Chưa có việc ở "Nhập xưởng"'), findsOneWidget);
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

  testWidgets('khi tắt hiệu ứng thì nhảy trang ngay, không trượt', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        plan: plan,
        tasks: [task('t3', 'PETROF P118', sectionId: 's3')],
        disableAnimations: true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Chờ QC'));
    // MỘT khung hình, không pumpAndSettle: nếu nó còn trượt thì chưa tới nơi.
    await tester.pump();

    expect(
      find.text('PETROF P118'),
      findsOneWidget,
      reason:
          'Bảng lướt ngang toàn màn hình là đúng loại chuyển động mà cài đặt '
          '"giảm chuyển động" nhắm tới.',
    );
  });

  /// Tab của một nhóm việc trên dải, kể cả khi đã cuộn khuất.
  Finder pill(String section) =>
      find.widgetWithText(SectionTabItem, section, skipOffstage: false);

  /// Số việc hiện TRONG tab của nhóm đó.
  Finder countIn(String section, int n) =>
      find.descendant(of: pill(section), matching: find.text('$n'));

  testWidgets('MỌI nhóm hiện tên và số việc trên dải, không chỉ nhóm đang mở', (
    tester,
  ) async {
    // Bản đầu là một hàng chấm: chấm thứ ba không nói nó là "Chờ QC", và số
    // việc chỉ hiện cho nhóm đang mở. Người quản đốc phải vuốt qua từng trang
    // để biết công đoạn nào đang dồn việc — đúng câu hỏi bảng này sinh ra để
    // trả lời bằng một cái nhìn.
    await tester.pumpWidget(
      host(
        plan: plan,
        tasks: [
          task('t1', 'A', sectionId: 's1'),
          task('t2', 'B', sectionId: 's1'),
          task('t3', 'C', sectionId: 's2'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(pill('Nhập xưởng'), findsOneWidget);
    expect(pill('Đang phục chế'), findsOneWidget);
    expect(pill('Chờ QC'), findsOneWidget);

    expect(countIn('Nhập xưởng', 2), findsOneWidget);
    expect(countIn('Đang phục chế', 1), findsOneWidget);
    // Nhóm rỗng KHÔNG in số 0: "0" cạnh tên là tiếng ồn, và cột rỗng đã nói
    // rõ là rỗng khi mở ra.
    expect(countIn('Chờ QC', 0), findsNothing);
  });

  testWidgets('vuốt sang trang thì viên của nhóm đó tự cuộn vào vùng nhìn', (
    tester,
  ) async {
    // Tám nhóm việc tràn khỏi một màn 800dp. Vuốt tới trang cuối mà dải vẫn
    // đứng ở đầu thì viên đang sáng nằm khuất — người dùng không biết mình
    // đang ở đâu, đúng thứ dải này sinh ra để nói.
    final wide = Plan.fromJson({
      'id': planId,
      'name': 'Đàn cơ',
      'sections': [
        for (var i = 1; i <= 8; i++)
          {'id': 's$i', 'name': 'Công đoạn số $i', 'order': i},
      ],
    });
    await tester.pumpWidget(
      host(
        plan: wide,
        tasks: [task('t8', 'PETROF P118', sectionId: 's8')],
      ),
    );
    await tester.pumpAndSettle();

    final width = tester.getSize(find.byType(PlanBoardPage)).width;
    expect(
      tester.getRect(pill('Công đoạn số 8')).left,
      greaterThan(width),
      reason: 'tám viên phải tràn khỏi màn thì bài này mới có nghĩa',
    );

    for (var i = 0; i < 7; i++) {
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();
    }

    expect(find.text('PETROF P118'), findsOneWidget);
    expect(
      tester.getRect(pill('Công đoạn số 8')).right,
      lessThanOrEqualTo(width),
    );
  });

  // API cho chủ/quản lý DỰ ÁN sửa nhóm việc, không chỉ người có
  // `tasks.projects.manage.all` (CV-I14). Giờ nằm trong menu ⋯.
  group('menu ⋯ Tuỳ chọn dự án', () {
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

    testWidgets('quản lý dự án thấy "Sửa nhóm việc" trong ⋯', (tester) async {
      await tester.pumpWidget(board('manager'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Sửa nhóm việc'), findsNothing);
      await tester.tap(find.byTooltip('Tuỳ chọn dự án'));
      await tester.pumpAndSettle();
      expect(find.text('Sửa nhóm việc'), findsOneWidget);
      expect(find.text('Xoá dự án'), findsNothing);
    });

    testWidgets('người giao việc có đủ Sửa nhóm việc + Xoá dự án', (
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
      await tester.tap(find.byTooltip('Tuỳ chọn dự án'));
      await tester.pumpAndSettle();
      expect(find.text('Sửa nhóm việc'), findsOneWidget);
      expect(find.text('Xoá dự án'), findsOneWidget);
    });

    testWidgets('thành viên thường không thấy ⋯', (tester) async {
      await tester.pumpWidget(board('member'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Tuỳ chọn dự án'), findsNothing);
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

    testWidgets('vuốt ngang sang nhóm việc kế, tab theo', (tester) async {
      await tester.pumpWidget(host(plan: team, tasks: const []));
      await tester.pumpAndSettle();
      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();
      final tabs = tester.widget<SectionTabs>(find.byType(SectionTabs));
      expect(tabs.current, 1);
    });

    testWidgets('nút Việc mới cao ≥ 48 khi được phép tạo', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            planProvider(planId).overrideWith((ref) async => team),
            planTasksProvider(
              planId,
            ).overrideWith((ref) async => (tasks: <Task>[], truncated: false)),
            backgroundProvider.overrideWith(FixedBackground.new),
            taskAccessProvider.overrideWithValue(
              TaskAccess.of(const AccessPolicy({'tasks.read', 'tasks.write'})),
            ),
          ],
          child: MaterialApp(
            theme: OmniTheme.light(TargetPlatform.android),
            home: const PlanBoardPage(planId: planId),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Việc mới'), findsOneWidget);
      expect(
        tester.getSize(find.byType(FloatingActionButton)).height,
        greaterThanOrEqualTo(48),
      );
    });
  });
}
