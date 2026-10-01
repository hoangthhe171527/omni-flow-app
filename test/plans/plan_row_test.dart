import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/design/tokens/tokens.dart';
import 'package:omni_app/modules/plans/domain/plan.dart';
import 'package:omni_app/modules/plans/presentation/widgets/plan_row.dart';

/// Thẻ dự án trong danh sách (`SMProjectsTasks.dc.html`, nửa "Đề xuất").
///
/// Định danh dự án là một Ô VUÔNG màu nền dự án cạnh tên — không còn đầu thẻ
/// tô gradient 64px với vòng quỹ đạo. Trong màn làm việc, khối màu đậm là
/// trang trí; ô vuông vẫn giữ được "dự án nào màu nào" mà không chiếm chỗ.
void main() {
  final plan = Plan.fromJson(const {
    'id': 'p1',
    'name': 'Đàn cơ',
    'cover': 'plum-1',
    'sections': [
      {'id': 's1', 'name': 'Máy'},
      {'id': 's2', 'name': 'Sơn'},
    ],
    'stats': {'total': 12, 'done': 3, 'overdue': 2},
  });

  Widget host(Plan p) => MaterialApp(
    theme: OmniTheme.light(TargetPlatform.android),
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: PlanRow(plan: p, onTap: () {}),
      ),
    ),
  );

  Finder gradients() => find.byWidgetPredicate(
    (w) =>
        w is Container &&
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).gradient != null,
  );

  testWidgets('không còn đầu thẻ gradient; ô vuông mang màu nền dự án', (
    tester,
  ) async {
    await tester.pumpWidget(host(plan));

    expect(gradients(), findsNothing);
    final swatch = tester.widget<PlanSwatch>(find.byType(PlanSwatch));
    expect(swatch.cover, 'plum-1');
    expect(
      tester.getSize(find.byType(PlanSwatch)).width,
      lessThanOrEqualTo(10),
    );

    final box =
        tester
                .widget<Container>(
                  find.descendant(
                    of: find.byType(PlanSwatch),
                    matching: find.byType(Container),
                  ),
                )
                .decoration!
            as BoxDecoration;
    expect(box.color, OmniCovers.colorOf('plum-1'));
  });

  testWidgets('tên chữ mực, ô vuông đứng trước tên, tiến độ dưới tên', (
    tester,
  ) async {
    await tester.pumpWidget(host(plan));

    final name = tester.widget<Text>(find.text('Đàn cơ'));
    expect(name.style?.color, OmniColors.foreground);

    final swatch = tester.getRect(find.byType(PlanSwatch));
    final title = tester.getRect(find.text('Đàn cơ'));
    final bar = tester.getRect(find.byType(LinearProgressIndicator));
    expect(swatch.right, lessThan(title.left));
    expect(bar.top, greaterThan(title.bottom));
    expect(bar.height, 4);
  });

  testWidgets('ba con số của quản đốc vẫn còn', (tester) async {
    await tester.pumpWidget(host(plan));

    expect(find.textContaining('Xong 3/12'), findsOneWidget);
    expect(find.textContaining('2 nhóm việc'), findsOneWidget);
    expect(find.text('Trễ 2'), findsOneWidget);
  });

  testWidgets('dự án tạo trước tính năng (cover null) vẫn có ô vuông', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(Plan.fromJson(const {'id': 'p0', 'name': 'Dự án cũ'})),
    );

    expect(find.byType(PlanSwatch), findsOneWidget);
    expect(OmniCovers.colorOf(null), OmniCovers.colorOf(OmniCovers.fallback));
    expect(find.text('Chưa có việc nào'), findsOneWidget);
  });
}
