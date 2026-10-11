import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/components/omni_avatar.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/plans/presentation/widgets/board_task_card.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';

void main() {
  Task task({
    String priority = 'med',
    List<String> names = const [],
    int subtasks = 0,
    int done = 0,
    int comments = 0,
  }) => Task.fromJson({
    'id': 'x',
    'title': 'KAWAI HAT-5',
    'priority': priority,
    'assignee_names': names,
    'comments_count': comments,
    'checklist': [
      for (var i = 0; i < subtasks; i++)
        {'id': 's$i', 'title': 'Bước $i', 'done': i < done},
    ],
  });

  Widget wrap(Widget child, {bool dark = false, bool noMotion = false}) =>
      MaterialApp(
        theme: dark
            ? OmniTheme.dark(TargetPlatform.android)
            : OmniTheme.light(TargetPlatform.android),
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: noMotion),
          child: Scaffold(
            body: Center(child: SizedBox(width: 380, child: child)),
          ),
        ),
      );

  testWidgets('thẻ: tên, hạn, Ưu tiên cao, avatar, 2/5', (t) async {
    await t.pumpWidget(
      wrap(
        BoardTaskCard(
          task: task(
            priority: 'high',
            names: ['Hoàng', 'Minh'],
            subtasks: 5,
            done: 2,
          ),
          onTap: () {},
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('KAWAI HAT-5'), findsOneWidget);
    expect(find.text('Chưa đặt hạn'), findsOneWidget);
    expect(find.text('Ưu tiên cao'), findsOneWidget);
    expect(find.text('2/5'), findsOneWidget);
    expect(find.byType(OmniAvatar), findsNWidgets(2));
    expect(find.text('Chưa gán'), findsNothing);
  });

  testWidgets('chưa ai làm: "Chưa gán"; không việc con: không có thanh', (
    t,
  ) async {
    await t.pumpWidget(wrap(BoardTaskCard(task: task(), onTap: () {})));
    await t.pumpAndSettle();
    expect(find.text('Chưa gán'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.textContaining('/'), findsNothing);
  });

  testWidgets('đếm trao đổi vẫn hiện, kể cả khi không có việc con', (t) async {
    await t.pumpWidget(
      wrap(BoardTaskCard(task: task(comments: 3), onTap: () {})),
    );
    await t.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('công đoạn kế tiếp hiện dưới tiêu đề', (t) async {
    await t.pumpWidget(
      wrap(BoardTaskCard(task: task(subtasks: 2, done: 1), onTap: () {})),
    );
    await t.pumpAndSettle();
    expect(find.text('Bước 1'), findsOneWidget);
  });

  testWidgets('quá ba người: 3 avatar + "+2"', (t) async {
    await t.pumpWidget(
      wrap(
        BoardTaskCard(
          task: task(names: ['A', 'B', 'C', 'D', 'E']),
          onTap: () {},
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.byType(OmniAvatar), findsNWidgets(3));
    expect(find.text('+2'), findsOneWidget);
  });

  testWidgets('chạm thẻ gọi onTap', (t) async {
    var taps = 0;
    await t.pumpWidget(
      wrap(BoardTaskCard(task: task(), onTap: () => taps++), noMotion: true),
    );
    await t.tap(find.text('KAWAI HAT-5'));
    expect(taps, 1);
  });

  testWidgets('giảm chuyển động: thẻ rõ ngay, không hiệu ứng rise', (t) async {
    await t.pumpWidget(
      wrap(
        BoardTaskCard(
          task: task(),
          onTap: () {},
          delay: const Duration(milliseconds: 300),
        ),
        noMotion: true,
      ),
    );
    final opacity = t.widgetList<Opacity>(find.byType(Opacity));
    expect(opacity.where((o) => o.opacity < 1), isEmpty);
  });

  testWidgets('tối: chip dùng token tối (không phải màu sáng cứng)', (t) async {
    await t.pumpWidget(
      wrap(
        BoardTaskCard(
          task: task(priority: 'high'),
          onTap: () {},
        ),
        dark: true,
      ),
    );
    await t.pumpAndSettle();
    final box = t.widget<DecoratedBox>(
      find
          .ancestor(
            of: find.text('Ưu tiên cao'),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect(
      (box.decoration as BoxDecoration).color,
      isNot(const Color(0xFFFDE8E8)),
    );
  });
}
