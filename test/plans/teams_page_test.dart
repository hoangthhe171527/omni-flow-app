import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/plans/application/plans_providers.dart';
import 'package:omni_app/modules/plans/domain/plan.dart';
import 'package:omni_app/modules/plans/domain/team.dart';
import 'package:omni_app/modules/plans/presentation/teams_page.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/domain/task_permissions.dart';
import 'package:omni_app/security/permissions/access_policy.dart';

/// Cùng một màn, hai bộ mặt — và ranh giới giữa chúng là QUYỀN, không phải
/// tên vai trò.
void main() {
  const worker = {'tasks.read', 'tasks.write'};
  const assigner = {'tasks.read', 'tasks.write', 'tasks.projects.manage.all'};

  Plan plan(String id, String name, {String? teamId, int overdue = 0}) =>
      Plan.fromJson({
        'id': id,
        'name': name,
        'team_id': ?teamId,
        // Hình dạng thật của API: ba con số nằm trong `stats`. Bài này từng
        // dựng dữ liệu bằng tên trường tôi đoán ra, nên nó xanh trong khi app
        // thật hiện "Chưa có việc nào".
        'stats': {'total': 10, 'done': 4, 'overdue': overdue},
      });

  Widget host({
    required List<TeamWithPlans> groups,
    Set<String> permissions = worker,
  }) => ProviderScope(
    overrides: [
      teamsWithPlansProvider.overrideWith((ref) async => groups),
      taskAccessProvider.overrideWithValue(
        TaskAccess.of(AccessPolicy(permissions)),
      ),
    ],
    child: MaterialApp(
      theme: OmniTheme.light(TargetPlatform.android),
      home: const TeamsPage(),
    ),
  );

  final xuong = TeamWithPlans(
    team: const Team(id: 't1', name: 'Xưởng TNP', memberIds: ['u1', 'u2']),
    plans: [
      plan('p1', 'Đàn cơ', teamId: 't1', overdue: 3),
      plan('p2', 'Đàn điện', teamId: 't1'),
    ],
  );

  testWidgets('người nhận việc KHÔNG thấy nút tạo', (tester) async {
    await tester.pumpWidget(host(groups: [xuong]));
    await tester.pumpAndSettle();

    expect(find.text('Tạo mới'), findsNothing);
    // Nhưng vẫn xem được dự án mình thuộc về.
    expect(find.text('Đàn cơ'), findsOneWidget);
  });

  testWidgets('người giao việc thấy nút tạo', (tester) async {
    await tester.pumpWidget(host(groups: [xuong], permissions: assigner));
    await tester.pumpAndSettle();

    expect(find.text('Tạo mới'), findsOneWidget);
  });

  testWidgets('mỗi dự án hiện tiến độ và số việc trễ', (tester) async {
    await tester.pumpWidget(host(groups: [xuong]));
    await tester.pumpAndSettle();

    expect(find.text('Xong 4/10'), findsNWidgets(2));
    // Chỉ dự án CÓ việc trễ mới đeo chip. Đeo hết thì không cái nào nổi.
    expect(find.text('Trễ 3'), findsOneWidget);
  });

  testWidgets('team rỗng nói rõ là rỗng, không phải một khoảng trắng', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        groups: [
          const TeamWithPlans(
            team: Team(id: 't2', name: 'Tổ mới'),
            plans: [],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Team này chưa có dự án nào.'),
      findsOneWidget,
      reason:
          'Một khối tiêu đề không có gì bên dưới đọc như lỗi tải, và người '
          'dùng sẽ kéo để tải lại mãi.',
    );
  });

  testWidgets('chưa có team nào thì lời nhắn khác nhau theo vai', (
    tester,
  ) async {
    await tester.pumpWidget(host(groups: const []));
    await tester.pumpAndSettle();
    expect(find.textContaining('sẽ hiện ở đây'), findsOneWidget);

    await tester.pumpWidget(host(groups: const [], permissions: assigner));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tạo một team'), findsOneWidget);
  });

  testWidgets('dự án chưa thuộc team nào vẫn hiện, ở khối riêng', (
    tester,
  ) async {
    // Đây là MỌI dự án tạo trước tầng Team — tức gần như tất cả những gì
    // đang có trong cơ sở dữ liệu hôm nay.
    await tester.pumpWidget(
      host(
        groups: [
          TeamWithPlans(
            team: const Team(id: '', name: 'Chưa thuộc team nào'),
            plans: [plan('p9', 'Dự án cũ')],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chưa thuộc team nào'), findsOneWidget);
    expect(find.text('Dự án cũ'), findsOneWidget);
  });
}
