import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/design/tokens/tokens.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/presentation/widgets/comment_section.dart';

/// Bố cục ô soạn trao đổi, đo bằng toạ độ chứ không bằng mắt.
///
/// Ảnh chụp thật (bộ soát UI, màn 03b) cho thấy ba chỗ hỏng cùng một lúc:
/// dãy chip nhắc tên dán sát mép trên ô nhập mà không có nhãn nói chúng là
/// gì, nút gửi 40dp neo đáy một ô nhập 52dp nên lệch tâm, và thân bình luận —
/// lý do một cây đàn bị trả về — in bằng màu chữ phụ, mờ hơn cả tên người.
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

  Widget host() => ProviderScope(
    child: MaterialApp(
      theme: OmniTheme.light(TargetPlatform.android),
      home: Scaffold(
        body: SingleChildScrollView(
          child: CommentSection(task: task, taskId: 't1', canWrite: true),
        ),
      ),
    ),
  );

  testWidgets('dãy chip có nhãn và cách ô nhập ít nhất 8dp', (tester) async {
    await tester.pumpWidget(host());

    expect(find.text('Nhắc tên'), findsOneWidget);

    final chips = tester.getRect(find.byType(Wrap));
    final field = tester.getRect(find.byType(TextField));

    expect(
      field.top - chips.bottom,
      greaterThanOrEqualTo(OmniSpacing.sm),
      reason: 'chip dán sát ô nhập đọc như một khối lỗi, không phải hai thứ',
    );
  });

  testWidgets('nút gửi thẳng tâm với ô nhập khi một dòng', (tester) async {
    await tester.pumpWidget(host());

    final field = tester.getRect(find.byType(TextField));
    final send = tester.getRect(find.byTooltip('Gửi'));

    expect((send.center.dy - field.center.dy).abs(), lessThanOrEqualTo(2));
  });

  testWidgets('thân bình luận in màu chữ CHÍNH, không phải màu phụ', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    final body = tester.widget<Text>(find.text('QC không đạt: mặt búa chưa đều.'));
    final scheme = Theme.of(tester.element(find.byType(CommentSection))).colorScheme;

    expect(body.style?.color, scheme.onSurface);
  });
}
