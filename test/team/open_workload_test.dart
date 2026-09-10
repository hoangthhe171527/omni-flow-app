import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/tasks/routes.dart';
import 'package:omni_app/modules/team/application/team_providers.dart';
import 'package:omni_app/modules/team/domain/team_member.dart';
import 'package:omni_app/modules/team/presentation/team_page.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

/// Từ danh sách nhân viên tới tải việc của một người.
///
/// Chạm vào một người phải mở TẢI VIỆC của họ — câu hỏi quản đốc hỏi nhiều
/// nhất khi đứng giữa xưởng. Trước đây chạm vào mở sheet liên kết Zalo, một
/// thao tác làm vài lần trong đời một nhân viên.
///
/// Bài này đi qua một GoRouter thật chứ không giả một callback: cặp (tên
/// route, tham số đường dẫn) là đúng thứ đã hỏng im lặng nhiều lần trong dự án
/// này — sai tên thì go_router ném lúc chạy, và không màn hình nào biết trước.
void main() {
  const foreman = {
    'membership.members.read',
    'tasks.projects.manage.all',
    'tasks.read',
  };
  const worker = {'membership.members.read', 'tasks.read'};

  final members = [
    const TeamMember(membershipId: 'm1', userId: 'u-hang-ni', name: 'Hằng Ni'),
  ];

  Widget host({
    required Set<String> permissions,
    required List<String> opened,
  }) {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/team', builder: (_, _) => const TeamPage(), routes: []),
        GoRoute(
          path: '/tasks/by/:userId',
          name: TaskRoutes.workload,
          builder: (_, state) {
            opened.add(state.pathParameters['userId']!);

            return const Scaffold(body: Text('TẢI VIỆC'));
          },
        ),
      ],
      initialLocation: '/team',
    );
    addTearDown(router.dispose);

    return ProviderScope(
      overrides: [
        teamMembersProvider.overrideWith((ref) async => members),
        sessionProvider.overrideWithValue(
          Session(
            status: SessionStatus.authenticated,
            policy: AccessPolicy(permissions),
          ),
        ),
      ],
      child: MaterialApp.router(
        theme: OmniTheme.light(TargetPlatform.android),
        routerConfig: router,
      ),
    );
  }

  testWidgets('quản đốc chạm vào một người thì mở tải việc của ĐÚNG người đó', (
    tester,
  ) async {
    final opened = <String>[];
    await tester.pumpWidget(host(permissions: foreman, opened: opened));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hằng Ni'));
    await tester.pumpAndSettle();

    expect(opened, ['u-hang-ni']);
    expect(find.text('TẢI VIỆC'), findsOneWidget);
  });

  testWidgets('thợ chạm vào thì KHÔNG đi đâu cả', (tester) async {
    // §7: xưởng không công khai số liệu cá nhân. Chặn ở route là đủ để an
    // toàn, nhưng bày ra một hàng người bấm vào là bị chặn thì tệ hơn không
    // bày gì — nên màn hình cũng phải biết.
    final opened = <String>[];
    await tester.pumpWidget(host(permissions: worker, opened: opened));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hằng Ni'));
    await tester.pumpAndSettle();

    expect(opened, isEmpty);
    expect(find.text('TẢI VIỆC'), findsNothing);
  });
}
