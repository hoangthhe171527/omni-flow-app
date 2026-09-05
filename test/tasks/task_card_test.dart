import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
      host(Task.fromJson({'id': 't', 'title': 'KAWAI HAT-5', 'due_date': '2026-12-31'})),
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
