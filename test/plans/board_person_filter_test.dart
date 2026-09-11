import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/plans/application/plans_providers.dart';
import 'package:omni_app/modules/plans/domain/plan.dart';
import 'package:omni_app/modules/plans/presentation/plan_board_page.dart';
import 'package:omni_app/modules/plans/presentation/widgets/person_filter_sheet.dart';
import 'package:omni_app/modules/settings/application/appearance_providers.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/team/team.dart';

import '../support/fixed_background.dart';

/// Lọc bảng theo người.
///
/// Hai câu hỏi, một cái sheet. Quản đốc hỏi "Hằng Ni đang làm những cây nào
/// trên bảng này"; người thợ hỏi "công đoạn nào đang trống" — §3, xưởng chạy
/// kiểu pull, ai rảnh thì nhận. Trước nay cả hai chỉ trả lời được bằng cách
/// lướt hết bảng đọc từng thẻ.
void main() {
  final plan = Plan.fromJson(const {
    'id': 'p1',
    'name': 'Phục chế tháng 9',
    'sections': [
      {'id': 's1', 'name': 'Đang làm'},
    ],
  });

  final tasks = [
    Task.fromJson(const {
      'id': 't1',
      'title': 'Cây của Hằng Ni',
      'section_id': 's1',
      'assignee_ids': ['u-hang-ni'],
      'assignee_names': ['Hằng Ni'],
    }),
    Task.fromJson(const {
      'id': 't2',
      'title': 'Cây của Luận',
      'section_id': 's1',
      'assignee_ids': ['u-luan'],
      'assignee_names': ['Luận'],
    }),
    Task.fromJson(const {
      'id': 't3',
      'title': 'Cây chưa ai nhận',
      'section_id': 's1',
    }),
  ];

  Widget host() => ProviderScope(
    overrides: [
      planProvider.overrideWith((ref, id) async => plan),
      planTasksProvider.overrideWith(
        (ref, id) async => (tasks: tasks, truncated: false),
      ),
      teamMembersProvider.overrideWith(
        (ref) async => const [
          TeamMember(membershipId: 'm1', userId: 'u-hang-ni', name: 'Hằng Ni'),
          TeamMember(membershipId: 'm2', userId: 'u-luan', name: 'Luận'),
        ],
      ),
      backgroundProvider.overrideWith(FixedBackground.new),
    ],
    child: MaterialApp(
      theme: OmniTheme.light(TargetPlatform.android),
      home: const PlanBoardPage(planId: 'p1'),
    ),
  );

  testWidgets('mặc định hiện hết, không lọc gì', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('Cây của Hằng Ni'), findsOneWidget);
    expect(find.text('Cây của Luận'), findsOneWidget);
    expect(find.text('Cây chưa ai nhận'), findsOneWidget);
    expect(find.textContaining('Đang lọc'), findsNothing);
  });

  testWidgets('lọc theo một người thì chỉ còn cây của người đó', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Lọc theo người'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hằng Ni'));
    await tester.pumpAndSettle();

    expect(find.text('Cây của Hằng Ni'), findsOneWidget);
    expect(find.text('Cây của Luận'), findsNothing);
    expect(find.text('Cây chưa ai nhận'), findsNothing);
  });

  testWidgets('"Chưa giao ai" trả lời câu hỏi của §3', (tester) async {
    // Công đoạn nào đang trống. Người thợ hỏi câu này mỗi lần rảnh tay.
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Lọc theo người'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chưa giao ai'));
    await tester.pumpAndSettle();

    expect(find.text('Cây chưa ai nhận'), findsOneWidget);
    expect(find.text('Cây của Hằng Ni'), findsNothing);
  });

  testWidgets('con số cạnh tên nhóm việc đi theo bộ lọc', (tester) async {
    // Ngược lại thì cột ghi "3 việc" mà chỉ vẽ ra 1 — và người đọc tin con số.
    // Số việc nằm TRONG viên của nhóm trên dải, cạnh tên nhóm.
    Finder countIn(int n) => find.descendant(
      of: find.widgetWithText(OmniFilterPill, 'Đang làm'),
      matching: find.text('$n'),
    );

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(countIn(3), findsOneWidget);

    await tester.tap(find.byTooltip('Lọc theo người'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Luận'));
    await tester.pumpAndSettle();

    expect(countIn(1), findsOneWidget);
    expect(countIn(3), findsNothing);
  });

  testWidgets('nói ra là đang lọc, và có đường ra', (tester) async {
    // Một cái bảng đang lọc trông y hệt một cái bảng vắng việc. Thanh này là
    // thứ duy nhất phân biệt hai chuyện đó.
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Lọc theo người'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hằng Ni'));
    await tester.pumpAndSettle();

    expect(find.text('Đang lọc: Hằng Ni'), findsOneWidget);

    await tester.tap(find.byTooltip('Bỏ lọc'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Đang lọc'), findsNothing);
    expect(find.text('Cây của Luận'), findsOneWidget);
  });

  test('bộ lọc là BA trạng thái, không phải hai', () {
    // "Chưa giao ai" không phải là "không lọc". Trạng thái giữa mới là thứ §3
    // cần, và gộp nó vào một trong hai đầu là mất đúng câu hỏi hay dùng nhất.
    expect(BoardPerson.everyone.matches(const []), isTrue);
    expect(BoardPerson.everyone.matches(const ['u1']), isTrue);

    expect(BoardPerson.unassigned.matches(const []), isTrue);
    expect(BoardPerson.unassigned.matches(const ['u1']), isFalse);

    const one = BoardPerson.person('u1', 'Hằng Ni');
    expect(one.matches(const ['u1', 'u2']), isTrue);
    expect(one.matches(const ['u2']), isFalse);
    expect(one.matches(const []), isFalse);
  });

  test('chỉ trạng thái "không lọc" mới không có nhãn', () {
    expect(BoardPerson.everyone.chipLabel, isNull);
    expect(BoardPerson.unassigned.chipLabel, 'Chưa giao ai');
    expect(const BoardPerson.person('u1', 'Hằng Ni').chipLabel, 'Hằng Ni');
  });
}
