import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/tasks/application/task_controller.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/presentation/widgets/comment_section.dart';

/// Nhắc tên bằng `@` ngay trong chữ, như mọi app trao đổi trên thị trường.
///
/// Bản trước là một dãy chip đứng riêng trên ô nhập: chọn chip là một trạng
/// thái NGẦM không hiện trong câu, và người thợ quen Zalo/Slack thì cứ gõ `@`
/// rồi không thấy gì xảy ra. Giờ gõ `@` là ra gợi ý, chọn là `@Tên` nằm trong
/// câu, và id gửi đi được đọc lại từ chính câu đó — xoá chữ là hết nhắc.
void main() {
  late List<({String body, List<String> ids})> sent;

  final task = Task.fromJson({
    'id': 't1',
    'title': 'KAWAI HAT-5',
    'assignee_ids': ['u-1', 'u-2'],
    'assignee_names': ['Hằng Ni', 'Luận'],
    'checklist': [
      {
        'id': 's1',
        'title': 'Sơn',
        'done': false,
        'assignee_id': 'u-3',
        'assignee_name': 'Minh Anh',
      },
    ],
    'comments': [
      {
        'id': 'c1',
        'body': 'QC trượt, @Luận xem lại phần búa.',
        'user_name': 'Hằng Ni',
        'mentioned_user_names': ['Luận'],
        'created_at': '2026-09-11T07:00:00Z',
      },
      {
        'id': 'c2',
        'body': 'Đã nhận.',
        'user_name': 'Luận',
        'mentioned_user_names': ['Hằng Ni'],
        'created_at': '2026-09-11T07:10:00Z',
      },
    ],
    'comments_count': 2,
  });

  Widget host() {
    sent = [];

    return ProviderScope(
      overrides: [
        taskDetailProvider.overrideWith(() => _StubController(task, sent)),
      ],
      child: MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        home: Scaffold(
          body: SingleChildScrollView(
            child: CommentSection(task: task, taskId: 't1', canWrite: true),
          ),
        ),
      ),
    );
  }

  Finder suggestion(String userId) => find.byKey(ValueKey('mention:$userId'));

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
  }

  testWidgets('không còn dãy chip đứng riêng', (tester) async {
    await tester.pumpWidget(host());

    expect(find.byType(FilterChip), findsNothing);
    expect(find.text('Nhắc tên'), findsNothing);
  });

  testWidgets('gõ @L thì gợi ý đúng Luận, không gợi ý người khác', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    await type(tester, 'nhờ @L');

    expect(suggestion('u-2'), findsOneWidget);
    expect(suggestion('u-1'), findsNothing);
    expect(suggestion('u-3'), findsNothing);
  });

  testWidgets('người phụ trách công đoạn cũng nhắc được', (tester) async {
    // Minh Anh không nằm trong người làm của việc, chỉ phụ trách công đoạn
    // "Sơn" — đúng người hay bị nhắc nhất khi QC trượt (§B3).
    await tester.pumpWidget(host());

    await type(tester, '@m');

    expect(suggestion('u-3'), findsOneWidget);
  });

  testWidgets('chọn gợi ý thì @Tên nằm TRONG câu', (tester) async {
    await tester.pumpWidget(host());

    await type(tester, 'nhờ @L');
    await tester.tap(suggestion('u-2'));
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'nhờ @Luận ');
    expect(suggestion('u-2'), findsNothing, reason: 'chọn xong thì gợi ý đóng');
  });

  testWidgets('gửi thì id đọc từ chữ, không từ trạng thái ngầm', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    await type(tester, 'nhờ @L');
    await tester.tap(suggestion('u-2'));
    await tester.pump();
    await type(tester, 'nhờ @Luận xem lại búa');
    await tester.tap(find.byTooltip('Gửi'));
    await tester.pumpAndSettle();

    expect(sent.single.body, 'nhờ @Luận xem lại búa');
    expect(sent.single.ids, ['u-2']);
  });

  testWidgets('xoá @Tên khỏi câu là hết nhắc', (tester) async {
    await tester.pumpWidget(host());

    await type(tester, 'nhờ @L');
    await tester.tap(suggestion('u-2'));
    await tester.pump();
    await type(tester, 'nhờ xem lại búa');
    await tester.tap(find.byTooltip('Gửi'));
    await tester.pumpAndSettle();

    expect(sent.single.ids, isEmpty);
  });

  testWidgets('nút @ cạnh ô nhập chèn @ và mở đủ gợi ý', (tester) async {
    // Cho người không biết quy ước: bấm là thấy tên để chọn, như trên web.
    await tester.pumpWidget(host());

    await tester.tap(find.byTooltip('Nhắc tên'));
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, '@');
    expect(suggestion('u-1'), findsOneWidget);
    expect(suggestion('u-2'), findsOneWidget);
    expect(suggestion('u-3'), findsOneWidget);
  });

  testWidgets('thân bình luận tô @Tên bằng màu chính', (tester) async {
    await tester.pumpWidget(host());

    final scheme = Theme.of(
      tester.element(find.byType(CommentSection)),
    ).colorScheme;
    final rich = tester.widget<RichText>(
      find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('@Luận xem lại'),
      ),
    );
    final spans = <TextSpan>[];
    rich.text.visitChildren((s) {
      if (s is TextSpan) spans.add(s);
      return true;
    });
    final mention = spans.firstWhere((s) => s.text == '@Luận');

    expect(mention.style?.color, scheme.primary);
    expect(mention.style?.fontWeight, FontWeight.w600);
  });

  testWidgets('dòng "Nhắc:" chỉ hiện khi tên KHÔNG có trong câu', (
    tester,
  ) async {
    // c1 có "@Luận" trong câu — không lặp lại. c2 nhắc Hằng Ni từ web (không
    // có @ trong câu) — vẫn phải nói ra, vì đây là kênh duy nhất báo cho
    // người thợ biết công đoạn của mình là chỗ bị trả về.
    await tester.pumpWidget(host());

    expect(find.text('Nhắc: Hằng Ni'), findsOneWidget);
    expect(find.text('Nhắc: Luận'), findsNothing);
  });
}

class _StubController extends TaskController {
  _StubController(this._task, this._sent);

  final Task _task;
  final List<({String body, List<String> ids})> _sent;

  @override
  Future<TaskDetailState> build(String arg) async =>
      TaskDetailState(task: _task);

  @override
  Future<void> comment(
    String body, {
    List<String> mentionedUserIds = const [],
  }) async => _sent.add((body: body, ids: mentionedUserIds));
}
