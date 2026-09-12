import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/design/tokens/tokens.dart';
import 'package:omni_app/modules/tasks/application/task_controller.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/presentation/widgets/comment_section.dart';

/// Bố cục ô soạn trao đổi, đo bằng toạ độ chứ không bằng mắt.
///
/// Ảnh chụp thật (bộ soát UI, màn 03b) từng cho thấy dãy gợi ý dán sát mép
/// trên ô nhập, và thân bình luận — lý do một cây đàn bị trả về — in bằng màu
/// chữ phụ, mờ hơn cả tên người.
void main() {
  final task = Task.fromJson({
    'id': 't1',
    'title': 'KAWAI HAT-5',
    'assignee_ids': ['u-1', 'u-2'],
    'assignee_names': ['Hằng Ni', 'Luận'],
    'checklist': <Map<String, dynamic>>[],
    'comments': [
      {
        'id': 'c1',
        'body': 'QC không đạt: mặt búa chưa đều.',
        'user_name': 'Hằng Ni',
        'created_at': '2026-09-11T07:00:00Z',
      },
    ],
    'comments_count': 1,
  });

  // Khối trao đổi đọc bình luận qua provider, và provider ấy lấy hạt giống từ
  // controller chi tiết: phải có một controller giả, không thì nó gọi API thật.
  Widget host() => ProviderScope(
    overrides: [taskDetailProvider.overrideWith(() => _StubDetail(task))],
    child: MaterialApp(
      theme: OmniTheme.light(TargetPlatform.android),
      home: Scaffold(
        body: SingleChildScrollView(
          child: CommentSection(task: task, taskId: 't1', canWrite: true),
        ),
      ),
    ),
  );

  testWidgets('dải gợi ý @ cách ô nhập ít nhất 8dp', (tester) async {
    await tester.pumpWidget(host());
    await tester.enterText(find.byType(TextField), '@');
    await tester.pump();

    final strip = tester.getRect(find.byType(Wrap));
    final field = tester.getRect(find.byType(TextField));

    expect(
      field.top - strip.bottom,
      greaterThanOrEqualTo(OmniSpacing.sm),
      reason: 'gợi ý dán sát ô nhập đọc như một khối lỗi, không phải hai thứ',
    );
  });

  testWidgets('nút @ và nút gửi thẳng tâm với ô nhập khi một dòng', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    final field = tester.getRect(find.byType(TextField));
    final send = tester.getRect(find.byTooltip('Gửi'));
    final at = tester.getRect(find.byTooltip('Nhắc tên'));

    expect((send.center.dy - field.center.dy).abs(), lessThanOrEqualTo(2));
    expect((at.center.dy - field.center.dy).abs(), lessThanOrEqualTo(2));
  });

  testWidgets('thân bình luận in màu chữ CHÍNH, không phải màu phụ', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    const body = 'QC không đạt: mặt búa chưa đều.';
    final rich = tester.widget<RichText>(
      find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText() == body,
      ),
    );
    final scheme = Theme.of(
      tester.element(find.byType(CommentSection)),
    ).colorScheme;

    // Đọc đúng span CỦA thân bình luận: `Text.rich` bọc nó trong một span
    // ngoài mang style mặc định, nên `rich.text.style` là của lớp vỏ.
    final spans = <TextSpan>[];
    rich.text.visitChildren((s) {
      if (s is TextSpan) spans.add(s);
      return true;
    });
    final own = spans.firstWhere((s) => s.text == body);

    expect(own.style?.color, scheme.onSurface);
  });
}

/// Trả về một trạng thái cố định, không gọi API.
class _StubDetail extends TaskController {
  _StubDetail(this._task);

  final Task _task;

  @override
  Future<TaskDetailState> build(String arg) async =>
      TaskDetailState(task: _task);
}
