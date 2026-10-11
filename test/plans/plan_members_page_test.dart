import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/plans/data/plans_api.dart';
import 'package:omni_app/modules/plans/domain/plan.dart';
import 'package:omni_app/modules/plans/presentation/plan_members_page.dart';
import 'package:omni_app/modules/team/team.dart';

/// Thành viên và vai: `member_ids` và `member_roles` đi cùng nhau; chủ không
/// gỡ hay đổi vai được.
void main() {
  late _FakePlansApi api;

  const people = [
    TeamMember(membershipId: 'm0', userId: 'u-owner', name: 'Trung Nguyên'),
    TeamMember(membershipId: 'm1', userId: 'u-me', name: 'Minh Hà'),
    TeamMember(membershipId: 'm2', userId: 'u-2', name: 'Lan Phạm'),
    TeamMember(membershipId: 'm3', userId: 'u-3', name: 'Tú Lê'),
  ];

  Future<void> pump(WidgetTester tester, Map<String, dynamic> json) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    api = _FakePlansApi(Plan.fromJson(json));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          plansApiProvider.overrideWithValue(api),
          teamDirectoryProvider.overrideWith((ref) async => people),
        ],
        child: MaterialApp(
          theme: OmniTheme.light(TargetPlatform.android),
          home: const PlanMembersPage(planId: 'p1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const base = {
    'id': 'p1',
    'name': 'Bảo hành',
    'owner_id': 'u-owner',
    'member_ids': ['u-owner', 'u-me', 'u-2'],
    'member_roles': {'u-me': 'manager'},
  };

  testWidgets('liệt kê chủ, vai, và chủ không có nút đổi', (tester) async {
    await pump(tester, base);

    expect(find.text('Trung Nguyên'), findsOneWidget);
    expect(find.text('Chủ'), findsOneWidget);
    expect(find.text('Quản lý'), findsOneWidget);
    expect(find.text('Thành viên'), findsWidgets);
    expect(find.bySemanticsLabel('Đổi vai Trung Nguyên'), findsNothing);
    expect(find.bySemanticsLabel('Đổi vai Lan Phạm'), findsOneWidget);
  });

  testWidgets('(d) thêm thành viên gửi member_ids và member_roles khớp nhau', (
    tester,
  ) async {
    await pump(tester, base);

    await tester.tap(find.text('Thêm thành viên'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tú Lê'));
    await tester.pump();
    await tester.tap(find.textContaining('Xong ('));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();

    final json = api.patches.single.toJson();
    expect(json.keys.toSet(), {'member_ids', 'member_roles'});
    expect((json['member_ids'] as List).toSet(), {
      'u-owner',
      'u-me',
      'u-2',
      'u-3',
    });
    expect(json['member_roles'], {
      'u-owner': 'owner',
      'u-me': 'manager',
      'u-2': 'member',
      'u-3': 'member',
    });
    expect(
      (json['member_ids'] as List).toSet(),
      (json['member_roles'] as Map).keys.toSet(),
    );
  });

  testWidgets('đổi vai và gỡ người', (tester) async {
    await pump(tester, base);

    await tester.tap(find.bySemanticsLabel('Đổi vai Lan Phạm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Người xem'));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Đổi vai Minh Hà'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gỡ khỏi kế hoạch'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();

    expect(api.patches.single.toJson(), {
      'member_ids': ['u-owner', 'u-2'],
      'member_roles': {'u-owner': 'owner', 'u-2': 'viewer'},
    });
  });

  testWidgets('chủ không nằm trong member_ids thì không bị thêm vào', (
    tester,
  ) async {
    await pump(tester, {
      'id': 'p1',
      'name': 'Bảo hành',
      'owner_id': 'u-owner',
      'member_ids': ['u-2'],
    });
    expect(find.text('Trung Nguyên'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Đổi vai Lan Phạm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quản lý'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();

    expect(api.patches.single.toJson(), {
      'member_ids': ['u-2'],
      'member_roles': {'u-2': 'manager'},
    });
  });
}

class _FakePlansApi implements PlansApi {
  _FakePlansApi(this._plan);

  final Plan _plan;
  final patches = <PlanPatch>[];

  @override
  Future<Plan> plan(String id) async => _plan;

  @override
  Future<Plan> updatePlan(String planId, PlanPatch patch) async {
    patches.add(patch);
    return _plan;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
