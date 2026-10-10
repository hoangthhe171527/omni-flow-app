import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/modules/customers/presentation/widgets/inline_edit_row.dart';

Widget host(
  Widget Function(bool editing, VoidCallback start, VoidCallback end) build, {
  bool disableAnimations = false,
}) {
  var editing = false;
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => build(
            editing,
            () => setState(() => editing = true),
            () => setState(() => editing = false),
          ),
        ),
      ),
    ),
  );
}

Color? _bg(WidgetTester t) {
  final c = t.widget<AnimatedContainer>(find.byType(AnimatedContainer).first);
  return (c.decoration as BoxDecoration?)?.color;
}

InlineEditRow _row({
  required bool editing,
  required VoidCallback start,
  required VoidCallback end,
  required Future<void> Function(String) onSave,
  String label = 'Email',
  String value = 'a@b.vn',
  bool editable = true,
  bool multiline = false,
  VoidCallback? onTapValue,
}) => InlineEditRow(
  label: label,
  value: value,
  editable: editable,
  multiline: multiline,
  isEditing: editing,
  onStartEdit: start,
  onEndEdit: end,
  onTapValue: onTapValue,
  onSave: onSave,
);

void main() {
  testWidgets('chạm → ô sửa; Enter lưu; chớp xanh rồi tắt', (t) async {
    String? saved;
    await t.pumpWidget(
      host(
        (e, s, n) => _row(
          editing: e,
          start: s,
          end: n,
          label: 'Điện thoại',
          value: '0283',
          onSave: (d) async => saved = d,
        ),
      ),
    );
    await t.tap(find.text('0283'));
    await t.pump();
    await t.enterText(find.byType(TextField), '0901');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pump();
    expect(saved, '0901');
    expect(find.byType(TextField), findsNothing);
    expect(_bg(t), isNot(Colors.transparent));
    await t.pump(const Duration(milliseconds: 800));
    expect(_bg(t), Colors.transparent);
    await t.pumpAndSettle();
  });

  testWidgets('Esc huỷ, không gọi onSave', (t) async {
    var calls = 0;
    await t.pumpWidget(
      host(
        (e, s, n) =>
            _row(editing: e, start: s, end: n, onSave: (d) async => calls++),
      ),
    );
    await t.tap(find.text('a@b.vn'));
    await t.pump();
    await t.enterText(find.byType(TextField), 'x@y.vn');
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pump();
    expect(calls, 0);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('a@b.vn'), findsOneWidget);
  });

  testWidgets('nháp trùng giá trị cũ: đóng ô, không gọi onSave', (t) async {
    var calls = 0;
    await t.pumpWidget(
      host(
        (e, s, n) =>
            _row(editing: e, start: s, end: n, onSave: (d) async => calls++),
      ),
    );
    await t.tap(find.text('a@b.vn'));
    await t.pump();
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pump();
    expect(calls, 0);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('nháp rỗng = xoá trường (onSave nhận chuỗi rỗng)', (t) async {
    String? saved;
    await t.pumpWidget(
      host(
        (e, s, n) =>
            _row(editing: e, start: s, end: n, onSave: (d) async => saved = d),
      ),
    );
    await t.tap(find.text('a@b.vn'));
    await t.pump();
    await t.enterText(find.byType(TextField), '');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pump();
    expect(saved, '');
    await t.pump(const Duration(milliseconds: 800));
    await t.pumpAndSettle();
  });

  testWidgets('lỗi 422: ô vẫn mở, giữ chữ, hiện lỗi, không chớp', (t) async {
    await t.pumpWidget(
      host(
        (e, s, n) => _row(
          editing: e,
          start: s,
          end: n,
          onSave: (d) async => throw const ValidationException(
            'Dữ liệu không hợp lệ',
            errors: {
              'email': ['Email không hợp lệ'],
            },
          ),
        ),
      ),
    );
    await t.tap(find.text('a@b.vn'));
    await t.pump();
    await t.enterText(find.byType(TextField), 'sai@');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pump();
    expect(find.text('Email không hợp lệ'), findsOneWidget);
    expect(
      t.widget<TextField>(find.byType(TextField)).controller!.text,
      'sai@',
    );
    expect(_bg(t), Colors.transparent);
  });

  testWidgets('lỗi không phải 422: câu chung', (t) async {
    await t.pumpWidget(
      host(
        (e, s, n) => _row(
          editing: e,
          start: s,
          end: n,
          onSave: (d) async => throw const NetworkException('mất mạng'),
        ),
      ),
    );
    await t.tap(find.text('a@b.vn'));
    await t.pump();
    await t.enterText(find.byType(TextField), 'c@d.vn');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pump();
    expect(find.text('Không lưu được. Thử lại.'), findsOneWidget);
  });

  testWidgets('editable=false: không bút chì, chạm gọi onTapValue', (t) async {
    var tapped = 0;
    await t.pumpWidget(
      host(
        (e, s, n) => _row(
          editing: e,
          start: s,
          end: n,
          label: 'Điện thoại',
          value: '0283',
          editable: false,
          onTapValue: () => tapped++,
          onSave: (d) async {},
        ),
      ),
    );
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    await t.tap(find.text('0283'));
    await t.pump();
    expect(find.byType(TextField), findsNothing);
    expect(tapped, 1);
  });

  testWidgets('ghi chú nhiều dòng: Enter xuống dòng, lưu bằng ✓', (t) async {
    String? saved;
    await t.pumpWidget(
      host(
        (e, s, n) => _row(
          editing: e,
          start: s,
          end: n,
          label: 'Ghi chú',
          value: 'cũ',
          multiline: true,
          onSave: (d) async => saved = d,
        ),
      ),
    );
    await t.tap(find.text('cũ'));
    await t.pump();
    await t.enterText(find.byType(TextField), 'một\nhai');
    await t.testTextInput.receiveAction(TextInputAction.newline);
    await t.pump();
    expect(saved, isNull);
    expect(find.byType(TextField), findsOneWidget);
    await t.tap(find.bySemanticsLabel('Lưu'));
    await t.pump();
    expect(saved, 'một\nhai');
    await t.pump(const Duration(milliseconds: 800));
    await t.pumpAndSettle();
  });

  testWidgets('giảm chuyển động: sau lưu một pump là hết hoạt ảnh', (t) async {
    await t.pumpWidget(
      host(
        disableAnimations: true,
        (e, s, n) => _row(
          editing: e,
          start: s,
          end: n,
          label: 'Điện thoại',
          value: '0283',
          onSave: (d) async {},
        ),
      ),
    );
    await t.tap(find.text('0283'));
    await t.pump();
    await t.enterText(find.byType(TextField), '0901');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pump();
    expect(_bg(t), isNot(Colors.transparent));
    expect(t.hasRunningAnimations, isFalse);
    await t.pump(const Duration(milliseconds: 700));
    expect(_bg(t), Colors.transparent);
  });

  testWidgets('nút ✕/✓ có vùng chạm ≥ 44', (t) async {
    await t.pumpWidget(
      host(
        (e, s, n) => _row(
          editing: e,
          start: s,
          end: n,
          label: 'Điện thoại',
          value: '0283',
          onSave: (d) async {},
        ),
      ),
    );
    await t.tap(find.text('0283'));
    await t.pump();
    for (final l in ['Lưu', 'Huỷ']) {
      expect(
        t.getSize(find.bySemanticsLabel(l)).shortestSide,
        greaterThanOrEqualTo(44),
      );
    }
  });
}
