import 'dart:ui' show Tristate;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/design/components/omni_dashed_circle.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/plans/presentation/widgets/board_task_card.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/data/tasks_api.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/domain/task_label.dart';

/// Thẻ việc đầy đủ (`Board.dc.html` `.card`): dải nhãn, ô tích nảy, gạch
/// ngang khi xong, ghim, chip hạn, số đếm, avatar / vòng nét đứt.
void main() {
  Task task({
    String id = 't1',
    String status = 'todo',
    String priority = 'med',
    List<String> names = const [],
    List<String> labels = const [],
    int subtasks = 0,
    int done = 0,
    int comments = 0,
    int files = 0,
    Object? pinned,
    String? due,
  }) => Task.fromJson({
    'id': id,
    'title': 'Bảo hành Ux kẹt cờ giảm âm',
    'status': status,
    'priority': priority,
    'assignee_names': names,
    'labels': labels,
    'comments_count': comments,
    'attachments_count': files,
    'due_date': ?due,
    'pinned': ?pinned,
    'checklist': [
      for (var i = 0; i < subtasks; i++)
        {'id': 's$i', 'title': 'Bước $i', 'done': i < done},
    ],
  });

  const catalog = [
    TaskLabel(id: '1', code: 'urgent', label: 'Gấp', color: '#DC2626'),
    TaskLabel(id: '2', code: 'warranty', label: 'Bảo hành', color: '#2563EB'),
  ];

  late _FakeTasksApi api;

  Widget wrap(
    Widget child, {
    bool dark = false,
    bool noMotion = false,
    List<TaskLabel> labels = catalog,
  }) {
    api = _FakeTasksApi();
    return ProviderScope(
      overrides: [
        tasksApiProvider.overrideWithValue(api),
        taskLabelsProvider.overrideWith((ref) async => labels),
      ],
      child: MaterialApp(
        theme: dark
            ? OmniTheme.dark(TargetPlatform.android)
            : OmniTheme.light(TargetPlatform.android),
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: noMotion),
          child: Scaffold(
            body: Center(child: SizedBox(width: 284, child: child)),
          ),
        ),
      ),
    );
  }

  Finder title() => find.text('Bảo hành Ux kẹt cờ giảm âm');

  TextStyle titleStyle(WidgetTester t) =>
      t.widget<Text>(title()).style ?? const TextStyle();

  testWidgets('(a) hai nhãn: hai vạch 32×6 bo 3 đúng màu, bỏ mã lạ', (t) async {
    await t.pumpWidget(
      wrap(
        BoardTaskCard(
          task: task(labels: ['urgent', 'gone', 'warranty']),
          onTap: () {},
        ),
      ),
    );
    await t.pumpAndSettle();

    final bars = _labelBars();
    expect(bars, findsNWidgets(2));
    final colors = [
      for (final e in t.widgetList<Container>(bars))
        (e.decoration! as BoxDecoration).color,
    ];
    expect(colors, [const Color(0xFFDC2626), const Color(0xFF2563EB)]);
    expect(t.getSize(bars.first), const Size(32, 6));
    expect(
      (t.widget<Container>(bars.first).decoration! as BoxDecoration)
          .borderRadius,
      BorderRadius.circular(3),
    );
    // Vạch hai cách vạch một 4.
    expect(t.getTopLeft(bars.last).dx - t.getTopRight(bars.first).dx, 4);
    expect(find.bySemanticsLabel('Nhãn: Gấp, Bảo hành'), findsOneWidget);
  });

  testWidgets('không nhãn thì không có dải', (t) async {
    await t.pumpWidget(wrap(BoardTaskCard(task: task(), onTap: () {})));
    await t.pumpAndSettle();
    expect(_labelBars(), findsNothing);
  });

  testWidgets('(b) chạm ô tích: gọi setStatus(done) một lần, gạch ngay', (
    t,
  ) async {
    await t.pumpWidget(
      wrap(BoardTaskCard(task: task(), onTap: () {}, canComplete: true)),
    );
    await t.pumpAndSettle();
    expect(titleStyle(t).decoration, isNot(TextDecoration.lineThrough));

    final gate = Completer<Task>();
    api.next = gate;
    await t.tap(find.bySemanticsLabel('Đánh dấu xong'));
    await t.pump();

    expect(api.calls, [('t1', 'done')]);
    expect(titleStyle(t).decoration, TextDecoration.lineThrough);
    expect(find.bySemanticsLabel('Bỏ đánh dấu xong'), findsOneWidget);

    gate.complete(task(status: 'done'));
    await t.pumpAndSettle();
    expect(api.calls, hasLength(1));
    expect(titleStyle(t).decoration, TextDecoration.lineThrough);
  });

  testWidgets('(b) lỗi thì hoàn tác và báo', (t) async {
    await t.pumpWidget(
      wrap(BoardTaskCard(task: task(), onTap: () {}, canComplete: true)),
    );
    await t.pumpAndSettle();

    final gate = Completer<Task>();
    api.next = gate;
    await t.tap(find.bySemanticsLabel('Đánh dấu xong'));
    await t.pump();
    expect(titleStyle(t).decoration, TextDecoration.lineThrough);

    gate.completeError(const NetworkException('mất mạng'));
    await t.pumpAndSettle();
    expect(titleStyle(t).decoration, isNot(TextDecoration.lineThrough));
    expect(find.bySemanticsLabel('Đánh dấu xong'), findsOneWidget);
    expect(find.textContaining('Chưa lưu được'), findsOneWidget);
  });

  testWidgets('bỏ đánh dấu việc đã xong gửi doing', (t) async {
    await t.pumpWidget(
      wrap(
        BoardTaskCard(
          task: task(status: 'done'),
          onTap: () {},
          canComplete: true,
        ),
      ),
    );
    await t.pumpAndSettle();
    api.next = Completer<Task>()..complete(task());
    await t.tap(find.bySemanticsLabel('Bỏ đánh dấu xong'));
    await t.pumpAndSettle();
    expect(api.calls, [('t1', 'doing')]);
  });

  testWidgets('chạm ô tích không mở thẻ', (t) async {
    var opened = 0;
    await t.pumpWidget(
      wrap(
        BoardTaskCard(task: task(), onTap: () => opened++, canComplete: true),
      ),
    );
    await t.pumpAndSettle();
    api.next = Completer<Task>()..complete(task(status: 'done'));
    await t.tap(find.bySemanticsLabel('Đánh dấu xong'));
    await t.pumpAndSettle();
    expect(opened, 0);
    await t.tap(title());
    expect(opened, 1);
  });

  testWidgets('ô tích: vùng chạm 44, ô vẽ 20 bo 5, Semantics toggled', (
    t,
  ) async {
    await t.pumpWidget(
      wrap(BoardTaskCard(task: task(), onTap: () {}, canComplete: true)),
    );
    await t.pumpAndSettle();

    final hit = find.byKey(const ValueKey('tick-target'));
    expect(t.getSize(hit), const Size(44, 44));
    final box = find.byKey(const ValueKey('tick-box'));
    expect(t.getSize(box), const Size(20, 20));
    final deco = t.widget<Container>(box).decoration! as BoxDecoration;
    expect(deco.borderRadius, BorderRadius.circular(5));
    expect((deco.border! as Border).top.width, 1.5);
    expect((deco.border! as Border).top.color, const Color(0xFF9AA5B8));

    final node = t.getSemantics(find.bySemanticsLabel('Đánh dấu xong'));
    expect(node.flagsCollection.isToggled, isNot(Tristate.isTrue));
  });

  testWidgets('ô tích nảy 350ms (scale 1.25 ở 40%)', (t) async {
    await t.pumpWidget(
      wrap(BoardTaskCard(task: task(), onTap: () {}, canComplete: true)),
    );
    await t.pumpAndSettle();
    api.next = Completer<Task>();
    await t.tap(find.bySemanticsLabel('Đánh dấu xong'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 140));

    final scale = t.widget<ScaleTransition>(
      find.byKey(const ValueKey('tick-bounce')),
    );
    expect(scale.scale.value, closeTo(1.25, 0.01));
    await t.pump(const Duration(milliseconds: 210));
    expect(scale.scale.value, closeTo(1, 0.001));
  });

  testWidgets('giảm chuyển động: ô tích không nảy, thẻ rõ ngay', (t) async {
    await t.pumpWidget(
      wrap(
        BoardTaskCard(
          task: task(),
          onTap: () {},
          canComplete: true,
          delay: const Duration(milliseconds: 300),
        ),
        noMotion: true,
      ),
    );
    final opacity = t.widgetList<Opacity>(find.byType(Opacity));
    expect(opacity.where((o) => o.opacity < 1), isEmpty);

    api.next = Completer<Task>();
    await t.tap(find.bySemanticsLabel('Đánh dấu xong'));
    await t.pump();
    final scale = t.widget<ScaleTransition>(
      find.byKey(const ValueKey('tick-bounce')),
    );
    expect(scale.scale.value, 1);
    expect(t.hasRunningAnimations, isFalse);
  });

  testWidgets('(c) thiếu canComplete thì không có ô tích', (t) async {
    await t.pumpWidget(wrap(BoardTaskCard(task: task(), onTap: () {})));
    await t.pumpAndSettle();
    expect(find.bySemanticsLabel('Đánh dấu xong'), findsNothing);
    expect(find.byKey(const ValueKey('tick-box')), findsNothing);
  });

  testWidgets('việc xong: gạch ngang, màu phụ, cả thẻ mờ .78', (t) async {
    await t.pumpWidget(
      wrap(
        BoardTaskCard(
          task: task(status: 'done'),
          onTap: () {},
          canComplete: true,
        ),
      ),
    );
    await t.pumpAndSettle();
    final style = titleStyle(t);
    expect(style.decoration, TextDecoration.lineThrough);
    expect(style.color, const Color(0xFF56637A));
    expect(style.fontWeight, FontWeight.w500);
    expect(style.height, 1.35);
    final card = t.widget<Opacity>(find.byKey(const ValueKey('card-opacity')));
    expect(card.opacity, 0.78);
    final box =
        t.widget<Container>(find.byKey(const ValueKey('tick-box'))).decoration!
            as BoxDecoration;
    expect(
      box.color,
      OmniTheme.light(TargetPlatform.android).colorScheme.primary,
    );
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('ghim: hiện khi API gửi pinned, vắng khoá thì không', (t) async {
    await t.pumpWidget(
      wrap(BoardTaskCard(task: task(pinned: true), onTap: () {})),
    );
    await t.pumpAndSettle();
    expect(find.bySemanticsLabel('Đã ghim'), findsOneWidget);

    await t.pumpWidget(wrap(BoardTaskCard(task: task(), onTap: () {})));
    await t.pumpAndSettle();
    expect(find.bySemanticsLabel('Đã ghim'), findsNothing);
  });

  testWidgets('(d) chưa giao ai: vòng nét đứt, Semantics "Chưa giao ai"', (
    t,
  ) async {
    await t.pumpWidget(wrap(BoardTaskCard(task: task(), onTap: () {})));
    await t.pumpAndSettle();
    expect(find.bySemanticsLabel('Chưa giao ai'), findsOneWidget);
    expect(find.byType(OmniDashedCircle), findsOneWidget);
    expect(t.getSize(find.byType(OmniDashedCircle)), const Size(24, 24));
  });

  testWidgets('(e) số việc con, tệp, bình luận', (t) async {
    await t.pumpWidget(
      wrap(
        BoardTaskCard(
          task: task(subtasks: 5, done: 2, files: 1, comments: 4),
          onTap: () {},
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('2/5'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.bySemanticsLabel('2 trên 5 việc con xong'), findsOneWidget);
    expect(find.bySemanticsLabel('1 tệp đính kèm'), findsOneWidget);
    expect(find.bySemanticsLabel('4 bình luận'), findsOneWidget);
    // Bỏ khỏi thẻ: thanh tiến độ, công đoạn kế tiếp.
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Bước 2'), findsNothing);
  });

  testWidgets('không đếm gì thì không có số; không hạn thì không có chip', (
    t,
  ) async {
    await t.pumpWidget(wrap(BoardTaskCard(task: task(), onTap: () {})));
    await t.pumpAndSettle();
    expect(find.textContaining('/'), findsNothing);
    expect(find.text('Chưa đặt hạn'), findsNothing);
  });

  testWidgets('chip hạn có biểu tượng lịch 13, chữ 12 w500', (t) async {
    await t.pumpWidget(
      wrap(
        BoardTaskCard(
          task: task(due: '2099-10-14'),
          onTap: () {},
        ),
      ),
    );
    await t.pumpAndSettle();
    final label = t.widget<Text>(find.text('Hạn 14/10'));
    expect(label.style?.fontWeight, FontWeight.w500);
    final icon = t.widget<Icon>(find.byIcon(Icons.calendar_today_outlined));
    expect(icon.size, 13);
  });

  testWidgets('avatar 24 viền 2, chồng −6; quá ba người thì "+2"', (t) async {
    await t.pumpWidget(
      wrap(
        BoardTaskCard(
          task: task(names: ['Hoàng', 'Minh', 'Tú', 'Lan', 'Hà']),
          onTap: () {},
        ),
      ),
    );
    await t.pumpAndSettle();
    final faces = find.byKey(const ValueKey('assignee'));
    expect(faces, findsNWidgets(3));
    expect(t.getSize(faces.first), const Size(24, 24));
    expect(t.getTopLeft(faces.at(1)).dx - t.getTopLeft(faces.first).dx, 18);
    expect(find.text('+2'), findsOneWidget);
    expect(find.bySemanticsLabel('Hoàng, Minh, Tú, Lan, Hà'), findsOneWidget);
    expect(find.byType(OmniDashedCircle), findsNothing);
  });

  testWidgets('giữ "Ưu tiên cao"', (t) async {
    await t.pumpWidget(
      wrap(
        BoardTaskCard(
          task: task(priority: 'high'),
          onTap: () {},
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Ưu tiên cao'), findsOneWidget);
  });

  testWidgets('thẻ: nền surface, bo 8, đệm 10/10/10/8, bóng 0 1 2', (t) async {
    await t.pumpWidget(wrap(BoardTaskCard(task: task(), onTap: () {})));
    await t.pumpAndSettle();
    final shell = t.widget<Container>(find.byKey(const ValueKey('card-shell')));
    final deco = shell.decoration! as BoxDecoration;
    expect(deco.borderRadius, BorderRadius.circular(8));
    expect(deco.boxShadow!.single.offset, const Offset(0, 1));
    expect(deco.boxShadow!.single.blurRadius, 2);
    expect(shell.padding, const EdgeInsets.fromLTRB(8, 10, 10, 10));
  });

  testWidgets('chạm thẻ gọi onTap', (t) async {
    var taps = 0;
    await t.pumpWidget(
      wrap(BoardTaskCard(task: task(), onTap: () => taps++), noMotion: true),
    );
    await t.tap(title());
    expect(taps, 1);
  });

  testWidgets('(h) mọi chữ trên thẻ ≥12', (t) async {
    await t.pumpWidget(
      wrap(
        BoardTaskCard(
          task: task(
            names: ['Hoàng Minh'],
            labels: ['urgent'],
            subtasks: 3,
            done: 1,
            files: 2,
            comments: 3,
            due: '2099-10-14',
            priority: 'high',
          ),
          onTap: () {},
          canComplete: true,
        ),
      ),
    );
    await t.pumpAndSettle();
    for (final rt in t.widgetList<RichText>(
      find.descendant(
        of: find.byType(BoardTaskCard),
        matching: find.byType(RichText),
      ),
    )) {
      rt.text.visitChildren((span) {
        final size = span.style?.fontSize;
        if (size != null) expect(size, greaterThanOrEqualTo(12));
        return true;
      });
      final size = rt.text.style?.fontSize;
      if (size != null) expect(size, greaterThanOrEqualTo(12));
    }
  });

  testWidgets('tối: nền thẻ theo surface, không trắng cứng', (t) async {
    await t.pumpWidget(
      wrap(BoardTaskCard(task: task(), onTap: () {}), dark: true),
    );
    await t.pumpAndSettle();
    final deco =
        t
                .widget<Container>(find.byKey(const ValueKey('card-shell')))
                .decoration!
            as BoxDecoration;
    expect(
      deco.color,
      OmniTheme.dark(TargetPlatform.android).colorScheme.surface,
    );
  });
}

class _FakeTasksApi implements TasksApi {
  final calls = <(String, String)>[];
  Completer<Task>? next;

  @override
  Future<Task> setStatus(String taskId, String status) {
    calls.add((taskId, status));
    return (next ?? Completer<Task>()).future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Finder _labelBars() => find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith('label-bar-'),
);
