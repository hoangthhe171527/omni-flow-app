import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/presentation/widgets/task_card.dart';

/// Thẻ việc trên bảng phải nói được điều quản đốc hỏi khi lướt: cây này đang
/// ở công đoạn nào, ai làm, có ảnh/trao đổi gì chưa, có gấp không.
///
/// Bản trước chỉ có tên đàn, thanh tiến độ, hạn và avatar — người dùng nhìn
/// ảnh chụp và nói "đơn giản quá, không thấy thông tin gì". Trello/myXteam
/// đặt số đính kèm, số bình luận và nhãn lên thẻ vì cùng lý do.
void main() {
  Widget host(Task task) => MaterialApp(
    theme: OmniTheme.light(TargetPlatform.android),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 380,
          child: TaskCard(task: task, onTap: () {}, showPlanName: false),
        ),
      ),
    ),
  );

  group('công đoạn kế tiếp', () {
    testWidgets('nói công đoạn đang mở đầu tiên và ai làm', (tester) async {
      await tester.pumpWidget(
        host(
          Task.fromJson({
            'id': 't',
            'title': 'KAWAI HAT-5',
            'checklist': [
              {'id': 'a', 'title': 'Tháo máy', 'done': true},
              {
                'id': 'b',
                'title': 'Nắp phím',
                'done': false,
                'assignee_name': 'Hằng Ni',
              },
              {'id': 'c', 'title': 'Lên dây', 'done': false},
            ],
          }),
        ),
      );

      expect(find.text('→ Nắp phím · Hằng Ni'), findsOneWidget);
      expect(find.textContaining('Lên dây'), findsNothing);
    });

    testWidgets('chưa ai nhận thì chỉ tên công đoạn', (tester) async {
      await tester.pumpWidget(
        host(
          Task.fromJson({
            'id': 't',
            'title': 'x',
            'checklist': [
              {'id': 'b', 'title': 'Nắp phím', 'done': false},
            ],
          }),
        ),
      );

      expect(find.text('→ Nắp phím'), findsOneWidget);
    });

    testWidgets('xong hết hoặc không có công đoạn thì không có dòng này', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          Task.fromJson({
            'id': 't',
            'title': 'x',
            'checklist': [
              {'id': 'a', 'title': 'Tháo máy', 'done': true},
            ],
          }),
        ),
      );
      expect(find.textContaining('→'), findsNothing);

      await tester.pumpWidget(host(Task.fromJson({'id': 't', 'title': 'x'})));
      expect(find.textContaining('→'), findsNothing);
    });
  });

  group('đếm ảnh, trao đổi, điểm', () {
    testWidgets('hiện số kèm biểu tượng khi > 0', (tester) async {
      await tester.pumpWidget(
        host(
          Task.fromJson({
            'id': 't',
            'title': 'x',
            'attachments_count': 2,
            'comments_count': 3,
            'rating': 4,
          }),
        ),
      );

      expect(find.byIcon(Icons.attachment_outlined), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.byIcon(Icons.forum_outlined), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('bằng 0 thì KHÔNG in số 0 cũng không in biểu tượng', (
      tester,
    ) async {
      // "0 ảnh · 0 trao đổi" trên mọi thẻ là tiếng ồn — đúng thứ làm thẻ
      // trông rối mà không nói gì.
      await tester.pumpWidget(host(Task.fromJson({'id': 't', 'title': 'x'})));

      expect(find.byIcon(Icons.attachment_outlined), findsNothing);
      expect(find.byIcon(Icons.forum_outlined), findsNothing);
      expect(find.byIcon(Icons.star_rounded), findsNothing);
      expect(find.text('0'), findsNothing);
    });
  });

  group('ưu tiên', () {
    testWidgets('cao thì có chip "Cao"', (tester) async {
      await tester.pumpWidget(
        host(Task.fromJson({'id': 't', 'title': 'x', 'priority': 'high'})),
      );

      expect(find.text('Cao'), findsOneWidget);
    });

    testWidgets('bình thường thì không có chip', (tester) async {
      // Mọi thẻ đều "Bình thường" thì chữ đó không phân biệt được gì.
      await tester.pumpWidget(
        host(Task.fromJson({'id': 't', 'title': 'x', 'priority': 'med'})),
      );

      expect(find.text('Bình thường'), findsNothing);
      expect(find.text('Cao'), findsNothing);
    });
  });

  testWidgets('thẻ đầy đủ thông tin vẫn không tràn ở 380dp', (tester) async {
    await tester.pumpWidget(
      host(
        Task.fromJson({
          'id': 't',
          'title':
              'YAMAHA U3 · 1874203 — thay dạ búa toàn bộ và cân lại bàn phím',
          'priority': 'high',
          'due_date': '2020-01-01',
          'attachments_count': 12,
          'comments_count': 34,
          'rating': 5,
          'assignee_names': ['Hằng Ni', 'Luận', 'Minh', 'An'],
          'checklist': [
            {
              'id': 'b',
              'title': 'Cân lại bàn phím toàn bộ 88 phím',
              'done': false,
              'assignee_name': 'Nguyễn Thị Hằng Ni',
            },
          ],
        }),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
