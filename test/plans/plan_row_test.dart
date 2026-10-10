import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/design/tokens/tokens.dart';
import 'package:omni_app/modules/plans/domain/plan.dart';
import 'package:omni_app/modules/plans/presentation/widgets/plan_row.dart';

/// Dòng dự án trong thẻ của team (`Tasks.dc.html`, nửa `isPlans`): ô màu bo 8,
/// tên + meta, thanh 3 đoạn từ số thật, chip Trễ, mũi tên.
void main() {
  Plan plan({
    int sections = 0,
    int total = 10,
    int done = 0,
    int overdue = 0,
    String? cover,
    String name = 'Đàn cơ',
  }) => Plan.fromJson({
    'id': 'p1',
    'name': name,
    'cover': ?cover,
    'sections': [
      for (var i = 0; i < sections; i++) {'id': 's$i', 'name': 'N$i'},
    ],
    'stats': {'total': total, 'done': done, 'overdue': overdue},
  });

  Widget wrap(Widget child) => MaterialApp(
    theme: OmniTheme.light(TargetPlatform.android),
    home: Scaffold(body: child),
  );

  Finder bar() => find.byKey(const Key('plan-row-bar'));

  testWidgets('thanh 3 đoạn theo số thật: xong / trễ / còn lại', (t) async {
    await t.pumpWidget(
      wrap(PlanRow(plan: plan(total: 10, done: 4, overdue: 2))),
    );
    final flexes = t
        .widgetList<Expanded>(
          find.descendant(of: bar(), matching: find.byType(Expanded)),
        )
        .map((e) => e.flex)
        .toList();
    expect(flexes, [4, 2, 4]);
  });

  testWidgets('dự án 0 việc: "Chưa có việc", không chia thanh', (t) async {
    await t.pumpWidget(wrap(PlanRow(plan: plan(sections: 3, total: 0))));
    expect(find.text('3 nhóm việc · Chưa có việc'), findsOneWidget);
    expect(
      find.descendant(of: bar(), matching: find.byType(Expanded)),
      findsNothing,
    );
  });

  testWidgets('ô màu 34 bo 8 mang màu nền dự án; không gradient', (t) async {
    await t.pumpWidget(wrap(PlanRow(plan: plan(cover: 'plum-1'))));
    final box = t.widget<Container>(find.byKey(const Key('plan-row-swatch')));
    final deco = box.decoration! as BoxDecoration;
    expect(deco.color, OmniCovers.colorOf('plum-1'));
    expect(deco.gradient, isNull);
    expect(deco.borderRadius, const BorderRadius.all(Radius.circular(8)));
    expect(
      t.getSize(find.byKey(const Key('plan-row-swatch'))),
      const Size(34, 34),
    );
  });

  testWidgets('dự án cũ (cover null) vẫn có ô màu mặc định', (t) async {
    await t.pumpWidget(wrap(PlanRow(plan: plan())));
    final deco =
        t
                .widget<Container>(find.byKey(const Key('plan-row-swatch')))
                .decoration!
            as BoxDecoration;
    expect(deco.color, OmniCovers.colorOf(null));
  });

  testWidgets('chip Trễ N chỉ hiện khi có việc trễ; dòng cao ≥ 56', (t) async {
    await t.pumpWidget(wrap(PlanRow(plan: plan(overdue: 3), onTap: () {})));
    expect(find.text('Trễ 3'), findsOneWidget);
    expect(t.getSize(find.byType(PlanRow)).height, greaterThanOrEqualTo(56));

    await t.pumpWidget(wrap(PlanRow(plan: plan(overdue: 0), onTap: () {})));
    expect(find.textContaining('Trễ'), findsNothing);
  });
}
