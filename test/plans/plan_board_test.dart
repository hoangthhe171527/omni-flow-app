import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/plans/application/plans_providers.dart';
import 'package:omni_app/modules/plans/domain/plan.dart';
import 'package:omni_app/modules/plans/presentation/plan_board_page.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';

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
    ],
    child: MaterialApp(
      theme: OmniTheme.light(TargetPlatform.android),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: const PlanBoardPage(planId: planId),
      ),
    ),
  );

  testWidgets('thẻ KHÔNG lặp lại tên kế hoạch', (tester) async {
    // Tiêu đề màn đã là "Đàn cơ", và cả bảng chỉ thuộc một kế hoạch. In lại
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

  testWidgets('kế hoạch chưa có nhóm việc nào vẫn xem được', (tester) async {
    final bare = Plan.fromJson({'id': planId, 'name': 'Kế hoạch trống'});

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

  testWidgets('số việc của nhóm đang mở hiện cạnh tên nhóm', (tester) async {
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

    expect(find.text('2 việc'), findsOneWidget);
  });
}
