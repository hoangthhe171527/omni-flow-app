import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/customers/presentation/widgets/inline_edit_row.dart';

void main() {
  testWidgets('lượt lưu cũ về muộn không mở khoá lượt lưu mới', (t) async {
    final completers = <Completer<void>>[];
    var editing = true;
    late StateSetter setOuter;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (c, s) {
              setOuter = s;
              return InlineEditRow(
                label: 'Tên',
                value: 'A',
                editable: true,
                isEditing: editing,
                onStartEdit: () => s(() => editing = true),
                onEndEdit: () => s(() => editing = false),
                onSave: (_) {
                  final x = Completer<void>();
                  completers.add(x);
                  return x.future;
                },
              );
            },
          ),
        ),
      ),
    );
    await t.enterText(find.byType(TextField), 'B');
    await t.testTextInput.receiveAction(TextInputAction.done); // lượt 1 treo
    await t.pump();
    setOuter(() => editing = false); // cha đóng ô
    await t.pump();
    setOuter(() => editing = true); // mở lại
    await t.pump();
    await t.enterText(find.byType(TextField), 'C');
    await t.testTextInput.receiveAction(TextInputAction.done); // lượt 2 treo
    await t.pump();
    completers[0].complete(); // lượt 1 về muộn
    await t.pump();
    // Lượt 2 vẫn đang lưu: ô chỉ đọc, gửi lại không tạo lượt 3.
    expect(t.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pump();
    expect(completers, hasLength(2));
    completers[1].complete();
    await t.pumpAndSettle();
  });
}
