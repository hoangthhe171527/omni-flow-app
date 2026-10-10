import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/plans/domain/plan.dart';
import 'package:omni_app/modules/plans/presentation/widgets/section_pager.dart';

PlanSection s(String id, String name) =>
    PlanSection(id: id, name: name, order: 0);

final _theme = OmniTheme.light(TargetPlatform.android);

Widget wrap(Widget child, {bool reduce = false}) => MaterialApp(
  // Một ThemeData dùng chung: dựng mới mỗi lần thì AnimatedTheme chạy hoạt hoạ
  // giữa hai lần pump và bài "hết hoạt hoạ" sai vì lý do không liên quan.
  theme: _theme,
  builder: (context, home) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
    child: home!,
  ),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('tab có tên + viên số, chạm gọi onSelected, cao ≥ 44', (t) async {
    var picked = -1;
    await t.pumpWidget(
      wrap(
        SectionTabs(
          sections: [s('a', 'Tiếp nhận'), s('b', 'Đang sửa')],
          current: 0,
          countOf: (i) => [2, 3][i],
          onSelected: (i) => picked = i,
        ),
      ),
    );
    expect(find.text('3'), findsOneWidget);
    await t.tap(find.text('Đang sửa'));
    expect(picked, 1);
    expect(
      t
          .getSize(
            find
                .ancestor(
                  of: find.text('Đang sửa'),
                  matching: find.byType(InkWell),
                )
                .first,
          )
          .height,
      greaterThanOrEqualTo(44),
    );
    expect(find.bySemanticsLabel(RegExp('Đang sửa')), findsOneWidget);
  });

  testWidgets('giảm chuyển động: gạch chân tới nơi sau một pump', (t) async {
    Widget tabs(int i) => wrap(
      SectionTabs(
        sections: [s('a', 'A'), s('b', 'B')],
        current: i,
        onSelected: (_) {},
      ),
      reduce: true,
    );
    await t.pumpWidget(tabs(0));
    await t.pumpWidget(tabs(1));
    await t.pump();
    expect(t.hasRunningAnimations, isFalse);
  });

  testWidgets('gạch chân trượt sang tab được chọn', (t) async {
    Widget tabs(int i) => wrap(
      SectionTabs(
        sections: [s('a', 'Tiếp nhận'), s('b', 'Đang sửa')],
        current: i,
        onSelected: (_) {},
      ),
    );
    await t.pumpWidget(tabs(0));
    await t.pumpAndSettle();
    final first = t.getTopLeft(find.byKey(const Key('section-underline'))).dx;
    await t.pumpWidget(tabs(1));
    await t.pumpAndSettle();
    final second = t.getTopLeft(find.byKey(const Key('section-underline'))).dx;
    expect(second, greaterThan(first));
  });
}
