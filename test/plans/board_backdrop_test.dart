import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/plans/application/plans_providers.dart';
import 'package:omni_app/modules/plans/domain/plan.dart';
import 'package:omni_app/modules/plans/presentation/plan_board_page.dart';
import 'package:omni_app/modules/settings/application/appearance_providers.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';

/// Bảng dự án vẽ nền cả app phía sau các CỘT — không sau dải nhóm việc.
void main() {
  final plan = Plan.fromJson({
    'id': 'p1',
    'name': 'Đàn cơ',
    'sections': [
      {'id': 's1', 'name': 'Nhập xưởng', 'order': 0},
    ],
  });

  Widget host(String? bg) => ProviderScope(
    overrides: [
      planProvider('p1').overrideWith((ref) async => plan),
      planTasksProvider(
        'p1',
      ).overrideWith((ref) async => (tasks: <Task>[], truncated: false)),
      backgroundProvider.overrideWith(() => _Fixed(bg)),
    ],
    child: MaterialApp(
      theme: OmniTheme.light(TargetPlatform.android),
      home: const PlanBoardPage(planId: 'p1'),
    ),
  );

  testWidgets('bảng vẽ nền đã chọn phía sau các cột', (tester) async {
    await tester.pumpWidget(host('walnut'));
    await tester.pumpAndSettle();

    final backdrop = find.byType(OmniBackdrop);
    expect(backdrop, findsOneWidget);
    expect(tester.widget<OmniBackdrop>(backdrop).name, 'walnut');
    // Nền nằm SAU cột, không sau dải nhóm việc: PageView là con của backdrop.
    expect(
      find.descendant(of: backdrop, matching: find.byType(PageView)),
      findsOneWidget,
    );
  });

  testWidgets('mặc định thì như cũ', (tester) async {
    await tester.pumpWidget(host(null));
    await tester.pumpAndSettle();

    expect(tester.widget<OmniBackdrop>(find.byType(OmniBackdrop)).name, isNull);
  });
}

class _Fixed extends BackgroundController {
  _Fixed(this._v);

  final String? _v;

  @override
  String? build() => _v;
}
