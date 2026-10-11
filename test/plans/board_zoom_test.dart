import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/components/omni_motion_widgets.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/plans/application/plans_providers.dart';
import 'package:omni_app/modules/plans/domain/plan.dart';
import 'package:omni_app/modules/plans/presentation/plan_board_page.dart';
import 'package:omni_app/modules/plans/presentation/widgets/board_column.dart';
import 'package:omni_app/modules/plans/presentation/widgets/board_zoom.dart';
import 'package:omni_app/modules/settings/application/appearance_providers.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/domain/task_permissions.dart';
import 'package:omni_app/modules/team/team.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

import '../support/fixed_background.dart';

/// Chế độ thu nhỏ bảng (`Board.dc.html` `.zc`, `.zt`, nút kính lúp nổi).
void main() {
  const planId = 'p1';

  final plan = Plan.fromJson(const {
    'id': planId,
    'name': 'Bảo hành',
    'team_name': 'Tổ kỹ thuật',
    'cover': 'plum-1',
    'sections': [
      {'id': 's1', 'name': 'Tiếp nhận', 'order': 0},
      {'id': 's2', 'name': 'Đang xử lý', 'order': 1},
      {'id': 's3', 'name': 'Chờ linh kiện', 'order': 2},
      {'id': 's4', 'name': 'Xong', 'order': 3},
    ],
  });

  final tasks = [
    Task.fromJson(const {
      'id': 't1',
      'title': 'Bảo hành W106',
      'section_id': 's1',
    }),
    Task.fromJson(const {
      'id': 't2',
      'title': 'Kawai ND21',
      'section_id': 's1',
    }),
    Task.fromJson(const {
      'id': 't5',
      'title': 'Khung CLP950',
      'section_id': 's3',
    }),
    Task.fromJson(const {
      'id': 't7',
      'title': 'Bảo hành 2 cây',
      'section_id': 's4',
      'status': 'done',
    }),
  ];

  Future<void> pumpBoard(WidgetTester tester, {bool reduce = false}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          planProvider(planId).overrideWith((ref) async => plan),
          planTasksProvider(
            planId,
          ).overrideWith((ref) async => (tasks: tasks, truncated: false)),
          backgroundProvider.overrideWith(FixedBackground.new),
          teamDirectoryProvider.overrideWith(
            (ref) async => const <TeamMember>[],
          ),
          sessionProvider.overrideWithValue(
            const Session(
              status: SessionStatus.authenticated,
              user: SessionUser(id: 'u-me', fullName: 'Tôi', email: 'me@x.vn'),
            ),
          ),
          taskAccessProvider.overrideWithValue(
            TaskAccess.of(AccessPolicy(const {'tasks.read', 'tasks.write'})),
          ),
        ],
        child: MaterialApp(
          theme: OmniTheme.light(TargetPlatform.android),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
            child: child!,
          ),
          home: const PlanBoardPage(planId: planId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder column(String name) => find.byWidgetPredicate(
    (w) => w is BoardColumn && w.section.name == name,
    skipOffstage: false,
  );

  testWidgets('nút nổi 52 bo 12, phải 16, đáy 34; nhãn đổi theo chế độ', (
    tester,
  ) async {
    await pumpBoard(tester);
    final fab = find.bySemanticsLabel('Thu nhỏ xem toàn bảng');
    expect(fab, findsOneWidget);
    final rect = tester.getRect(find.byKey(const Key('board-zoom-fab')));
    expect(rect.size, const Size(52, 52));
    expect(rect.right, 390 - 16);
    expect(rect.bottom, 844 - 34);
    final deco =
        tester
                .widget<Container>(find.byKey(const Key('board-zoom-fab')))
                .decoration!
            as BoxDecoration;
    expect(deco.borderRadius, BorderRadius.circular(12));
    expect(deco.boxShadow!.single.blurRadius, 22);
    expect(deco.boxShadow!.single.offset, const Offset(0, 8));
    expect(find.byIcon(Icons.zoom_out_rounded), findsOneWidget);

    await tester.tap(fab);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Phóng to lại'), findsOneWidget);
    expect(find.byIcon(Icons.zoom_in_rounded), findsOneWidget);
  });

  testWidgets('(f) lưới: ô cột 150, chạm "Chờ linh kiện" về bảng ở cột 3', (
    tester,
  ) async {
    await pumpBoard(tester);
    await tester.tap(find.bySemanticsLabel('Thu nhỏ xem toàn bảng'));
    await tester.pumpAndSettle();

    expect(find.byType(BoardZoomGrid), findsOneWidget);
    expect(find.byType(BoardColumn), findsNothing);
    final tile = find.bySemanticsLabel('Mở nhóm Chờ linh kiện');
    expect(tile, findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('zoom-tile-s3'))).width,
      150,
    );
    // Mỗi việc là một ô một dòng.
    expect(find.text('Khung CLP950'), findsOneWidget);
    // Hai ô cột đầu cùng hàng, cách 10, lề 16, cách header 14.
    final a = tester.getRect(find.byKey(const ValueKey('zoom-tile-s1')));
    final b = tester.getRect(find.byKey(const ValueKey('zoom-tile-s2')));
    expect(a.left, 16);
    expect(b.left - a.right, 10);
    final header = tester.getRect(find.byKey(const Key('board-header')));
    expect(a.top - header.bottom, 14);

    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(find.byType(BoardZoomGrid), findsNothing);
    final third = tester.getRect(column('Chờ linh kiện'));
    expect(third.left, greaterThanOrEqualTo(0));
    expect(third.right, lessThanOrEqualTo(390));
    expect(third.center.dx, moreOrLessEquals(195, epsilon: 0.5));
  });

  testWidgets('việc xong trong lưới mờ .78', (tester) async {
    await pumpBoard(tester);
    await tester.tap(find.bySemanticsLabel('Thu nhỏ xem toàn bảng'));
    await tester.pumpAndSettle();
    final op = tester.widget<Opacity>(
      find
          .ancestor(
            of: find.text('Bảo hành 2 cây'),
            matching: find.byType(Opacity),
          )
          .first,
    );
    expect(op.opacity, 0.78);
  });

  testWidgets('lưới hiện dần 300ms', (tester) async {
    await pumpBoard(tester);
    await tester.tap(find.bySemanticsLabel('Thu nhỏ xem toàn bảng'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    final fade = tester.widget<FadeTransition>(
      find.byKey(const Key('board-zoom-fade')),
    );
    expect(fade.opacity.value, greaterThan(0));
    expect(fade.opacity.value, lessThan(1));
    await tester.pump(const Duration(milliseconds: 150));
    expect(fade.opacity.value, 1);
  });

  testWidgets('(g) giảm chuyển động: không còn khung nào', (tester) async {
    await pumpBoard(tester, reduce: true);
    await tester.tap(find.bySemanticsLabel('Thu nhỏ xem toàn bảng'));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.byType(BoardZoomGrid), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Mở nhóm Chờ linh kiện'));
    await tester.pump();
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    expect(
      tester.getRect(column('Chờ linh kiện')).center.dx,
      moreOrLessEquals(195, epsilon: 0.5),
    );
  });

  testWidgets('về từ lưới: thẻ không rise lại', (tester) async {
    await pumpBoard(tester);
    await tester.tap(find.bySemanticsLabel('Thu nhỏ xem toàn bảng'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Mở nhóm Tiếp nhận'));
    await tester.pump();
    for (final rise in tester.widgetList<OmniRise>(find.byType(OmniRise))) {
      expect(rise.animate, isFalse);
    }
  });
}
