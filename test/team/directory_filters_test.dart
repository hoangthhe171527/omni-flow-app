import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/assign_sheet.dart';
import 'package:omni_app/modules/plans/presentation/widgets/member_picker_sheet.dart';
import 'package:omni_app/modules/plans/presentation/widgets/person_filter_sheet.dart';
import 'package:omni_app/modules/team/presentation/team_page.dart';
import 'package:omni_app/modules/team/team.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

/// Danh bạ nay nạp MỌI trạng thái (để tra tên người đã nghỉ). Mỗi màn đọc nó
/// phải không bày người đã nghỉ ra; bộ chọn còn không bày lời mời chưa nhận
/// (review I1, APP-I10). Giao việc cho người đã nghỉ là 422 "phải là thành
/// viên đang làm" — đúng kiểu hỏng lệch im lặng.
void main() {
  const directory = [
    TeamMember(membershipId: 'm1', userId: 'u1', name: 'Lan'),
    TeamMember(
      membershipId: 'm2',
      userId: 'u2',
      name: 'Người đã nghỉ',
      status: 'inactive',
    ),
    TeamMember(
      membershipId: 'm3',
      userId: 'u3',
      name: 'Khách mời',
      accepted: false,
    ),
  ];

  Widget host(Widget home) => ProviderScope(
    overrides: [
      teamDirectoryProvider.overrideWith((ref) async => directory),
      sessionProvider.overrideWithValue(
        const Session(
          status: SessionStatus.authenticated,
          policy: AccessPolicy({}),
        ),
      ),
    ],
    child: MaterialApp(
      theme: OmniTheme.light(TargetPlatform.android),
      home: home,
    ),
  );

  Widget opener(Future<void> Function(BuildContext) open) => Scaffold(
    body: Builder(
      builder: (context) =>
          TextButton(onPressed: () => open(context), child: const Text('mở')),
    ),
  );

  Future<void> tapOpen(WidgetTester tester) async {
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
  }

  test(
    'provider bộ chọn chỉ có người chọn được; tra tên có cả người nghỉ',
    () async {
      final container = ProviderContainer(
        overrides: [
          teamDirectoryProvider.overrideWith((ref) async => directory),
        ],
      );
      addTearDown(container.dispose);

      final selectable = await container.read(teamMembersProvider.future);
      expect(selectable.map((m) => m.userId), ['u1']);
      expect(container.read(teamMemberByIdProvider).keys, {'u1', 'u2', 'u3'});
    },
  );

  testWidgets('màn Nhân viên: không có người đã nghỉ; lời mời là Đang chờ', (
    tester,
  ) async {
    await tester.pumpWidget(host(const TeamPage()));
    await tester.pumpAndSettle();

    expect(find.text('Lan'), findsOneWidget);
    expect(find.text('Người đã nghỉ'), findsNothing);
    expect(find.text('Khách mời'), findsOneWidget);
    expect(find.text('Đang chờ'), findsOneWidget);
  });

  testWidgets('Hộp thư — giao hội thoại: chỉ người chọn được', (tester) async {
    await tester.pumpWidget(host(const Scaffold(body: AssignSheet())));
    await tester.pumpAndSettle();

    expect(find.text('Lan'), findsOneWidget);
    expect(find.text('Người đã nghỉ'), findsNothing);
    expect(find.text('Khách mời'), findsNothing);
  });

  testWidgets('chọn thành viên dự án: chỉ người chọn được', (tester) async {
    await tester.pumpWidget(
      host(opener((c) => showMemberPicker(c, selected: const {}))),
    );
    await tapOpen(tester);

    expect(find.text('Lan'), findsOneWidget);
    expect(find.text('Người đã nghỉ'), findsNothing);
    expect(find.text('Khách mời'), findsNothing);
  });

  testWidgets('chọn thành viên dự án: người đã chọn mà nay nghỉ vẫn gỡ được', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(opener((c) => showMemberPicker(c, selected: const {'u2'}))),
    );
    await tapOpen(tester);

    expect(find.text('Người đã nghỉ'), findsOneWidget);
    expect(find.text('Lan'), findsOneWidget);
  });

  testWidgets('lọc theo người: chỉ người chọn được', (tester) async {
    await tester.pumpWidget(
      host(
        opener((c) => showPersonFilterSheet(c, current: BoardPerson.everyone)),
      ),
    );
    await tapOpen(tester);

    expect(find.text('Lan'), findsOneWidget);
    expect(find.text('Người đã nghỉ'), findsNothing);
    expect(find.text('Khách mời'), findsNothing);
  });
}
