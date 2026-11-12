import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/components/omni_inline_rename.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/presentation/widgets/subtask_row.dart';

/// Chạm tên để sửa tại chỗ (bug sheet 12/11/2026, artifact đã duyệt mục 5).
void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );

  Widget rename({
    required List<String> saved,
    bool canEdit = true,
    String value = 'KAWAI HAT-5',
  }) => OmniInlineRename(
    value: value,
    canEdit: canEdit,
    fieldKey: const ValueKey('f'),
    onSubmit: (next) async => saved.add(next),
    builder: (_) => Text(value, key: const ValueKey('view')),
  );

  testWidgets('chạm tên mở ô nhập, ✓ lưu tên đã cắt khoảng trắng', (
    tester,
  ) async {
    final saved = <String>[];
    await tester.pumpWidget(host(rename(saved: saved)));

    await tester.tap(find.byKey(const ValueKey('view')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('f')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('f')),
      '  KAWAI HAT-5 2308512 ',
    );
    await tester.tap(find.byKey(const ValueKey('inline-rename-save')));
    await tester.pumpAndSettle();

    expect(saved, ['KAWAI HAT-5 2308512']);
    expect(find.byKey(const ValueKey('f')), findsNothing);
  });

  testWidgets('Xong trên bàn phím cũng lưu', (tester) async {
    final saved = <String>[];
    await tester.pumpWidget(host(rename(saved: saved)));
    await tester.tap(find.byKey(const ValueKey('view')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('f')), 'Tên mới');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(saved, ['Tên mới']);
  });

  testWidgets('✕, tên trắng hay không đổi thì không lưu', (tester) async {
    final saved = <String>[];
    await tester.pumpWidget(host(rename(saved: saved)));

    Future<void> edit(String text, String button) async {
      await tester.tap(find.byKey(const ValueKey('view')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('f')), text);
      await tester.tap(find.byKey(ValueKey(button)));
      await tester.pumpAndSettle();
    }

    await edit('Tên khác', 'inline-rename-cancel');
    await edit('   ', 'inline-rename-save');
    await edit('KAWAI HAT-5', 'inline-rename-save');

    expect(saved, isEmpty);
    expect(find.byKey(const ValueKey('view')), findsOneWidget);
  });

  testWidgets('không có quyền sửa: chạm không mở ô nhập', (tester) async {
    await tester.pumpWidget(host(rename(saved: [], canEdit: false)));
    await tester.tap(find.byKey(const ValueKey('view')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('f')), findsNothing);
  });

  testWidgets('việc con: chạm tên sửa tại chỗ khi có onRename', (tester) async {
    final saved = <String>[];
    const s = Subtask(id: 'a', title: 'Nắp phím', done: false);
    SubtaskRow row({Future<void> Function(String)? onRename}) => SubtaskRow(
      subtask: s,
      pending: null,
      enabled: true,
      onToggle: (_) {},
      onRetry: () {},
      onDiscard: () {},
      onRename: onRename,
    );

    await tester.pumpWidget(host(row()));
    await tester.tap(find.text('Nắp phím'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('subtask-title-field-a')), findsNothing);

    await tester.pumpWidget(host(row(onRename: (n) async => saved.add(n))));
    await tester.tap(find.text('Nắp phím'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('subtask-title-field-a')),
      'Nắp phím + bản lề',
    );
    await tester.tap(find.byKey(const ValueKey('inline-rename-save')));
    await tester.pumpAndSettle();
    expect(saved, ['Nắp phím + bản lề']);
  });
}
