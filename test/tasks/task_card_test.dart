import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/components/omni_avatar.dart';
import 'package:omni_app/design/components/omni_status_chip.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/presentation/widgets/task_card.dart';

void main() {
  Widget host(Task task, {double width = 380}) => MaterialApp(
    theme: OmniTheme.light(TargetPlatform.android),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: TaskCard(task: task, onTap: () {}),
        ),
      ),
    ),
  );

  // Chip có NỀN, nên bề rộng của nó là thứ nhìn thấy được. Bản đầu bọc nó
  // trong Expanded — không sao khi chip chỉ là chữ với icon, nhưng khi thêm
  // nền thì cái nền chạy hết bề ngang thẻ và đọc như một thanh trạng thái.
  testWidgets('chip hạn ôm lấy chữ, không kéo hết bề ngang thẻ', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        Task.fromJson({
          'id': 't',
          'title': 'KAWAI HAT-5',
          'due_date': '2026-12-31',
        }),
      ),
    );

    final chip = tester.getSize(find.byType(OmniStatusChip));

    expect(
      chip.width,
      lessThan(200),
      reason:
          'Chip rộng ${chip.width.toStringAsFixed(0)}dp trên thẻ 380dp. '
          'Một chip trạng thái chạy hết hàng đọc như thanh tiến độ.',
    );
  });

  testWidgets('thẻ nói ai đang làm, kể cả khi chỉ có một người', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        Task.fromJson({
          'id': 't',
          'title': 'KAWAI HAT-5',
          'assignee_names': ['Hằng Ni'],
        }),
      ),
    );

    expect(
      find.byType(OmniAvatar),
      findsOneWidget,
      reason:
          'Trước đây thẻ chỉ nói khi có TỪ HAI người trở lên — im lặng đúng '
          'trường hợp thường gặp nhất.',
    );
  });

  testWidgets('việc chưa gán ai thì nói rõ trên thẻ', (tester) async {
    await tester.pumpWidget(
      host(Task.fromJson({'id': 't', 'title': 'Chưa ai nhận'})),
    );

    expect(find.text('Chưa gán'), findsOneWidget);
  });

  testWidgets('quá ba người thì gộp phần dư thành một con số', (tester) async {
    await tester.pumpWidget(
      host(
        Task.fromJson({
          'id': 't',
          'title': 'Đông người',
          'assignee_names': ['A', 'B', 'C', 'D', 'E'],
        }),
      ),
    );

    expect(find.byType(OmniAvatar), findsNWidgets(3));
    expect(find.text('+2'), findsOneWidget);
  });

  testWidgets('hai avatar chồng nhau không quá một phần tư', (tester) async {
    // Ảnh chụp thật: "HN" và "LU" đè lên nhau tới mức chữ của người đứng
    // trước bị người đứng sau che mất một nửa — 22dp chồng 8dp là 36%. Các
    // app việc trên thị trường chồng ~25%: đủ để đọc là "một nhóm", vẫn thấy
    // trọn chữ cái của từng người.
    await tester.pumpWidget(
      host(
        Task.fromJson({
          'id': 't',
          'title': 'Hai người',
          'assignee_names': ['Hằng Ni', 'Luận'],
        }),
      ),
    );

    final rects =
        find
            .byType(OmniAvatar)
            .evaluate()
            .map((e) => tester.getRect(find.byWidget(e.widget)))
            .toList()
          ..sort((a, b) => a.left.compareTo(b.left));
    final overlap = rects[0].right - rects[1].left;

    expect(overlap, lessThanOrEqualTo(rects[0].width * 0.25 + 0.01));
    expect(
      overlap,
      greaterThan(0),
      reason: 'vẫn là một chồng, không phải hai ô rời',
    );
  });

  testWidgets('nhãn hạn dài vẫn không tràn', (tester) async {
    await tester.pumpWidget(
      host(
        Task.fromJson({
          'id': 't',
          'title': 'Quá hạn rất lâu',
          'due_date': '2020-01-01',
        }),
        width: 240,
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
