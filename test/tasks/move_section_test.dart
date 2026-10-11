import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/design/tokens/tokens.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/presentation/widgets/task_detail/option_sheet.dart';

/// Chọn nhóm việc mới, thay cho kéo thả — nay qua `showOptionSheet`.
///
/// Trên điện thoại, kéo một thẻ qua ranh giới trang tranh trực tiếp với cử chỉ
/// lật trang của chính cái bảng — hai thao tác cùng hướng, và người dùng đoán
/// sai một nửa số lần. Một danh sách thì không đoán sai lần nào.
void main() {
  const sections = [
    TaskSection(id: 's1', name: 'Nhập xưởng'),
    TaskSection(id: 's2', name: 'Đang phục chế'),
    TaskSection(id: 's3', name: 'Chờ QC'),
  ];

  /// Mở sheet đúng như màn chi tiết gọi nó; `result()` trả chỉ số đã chọn.
  Future<int? Function()> open(
    WidgetTester tester, {
    List<TaskSection> list = sections,
    int? selected = 1,
  }) async {
    int? picked;

    await tester.pumpWidget(
      MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                picked = await showOptionSheet(
                  context,
                  title: 'Chuyển nhóm việc',
                  emptyMessage: 'Dự án này chưa khai báo nhóm việc nào.',
                  selected: selected,
                  items: [
                    for (var i = 0; i < list.length; i++)
                      OptionItem(
                        label: list[i].name,
                        color: OmniTaskTones.of(context).sectionColor(i),
                      ),
                  ],
                );
              },
              child: const Text('mở'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();

    return () => picked;
  }

  testWidgets('liệt kê đúng các nhóm việc của dự án', (tester) async {
    await open(tester);

    expect(find.text('Chuyển nhóm việc'), findsOneWidget);
    expect(find.text('Nhập xưởng'), findsOneWidget);
    expect(find.text('Đang phục chế'), findsOneWidget);
    expect(find.text('Chờ QC'), findsOneWidget);
  });

  testWidgets('đánh dấu ✓ đúng nhóm việc đang đứng', (tester) async {
    await open(tester);

    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Đang phục chế'),
          matching: find.byType(InkWell),
        ),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('chọn một nhóm việc thì đóng lại và trả về chỉ số của nó', (
    tester,
  ) async {
    final result = await open(tester);

    await tester.tap(find.text('Chờ QC'));
    await tester.pumpAndSettle();

    expect(result(), 2);
    expect(find.text('Chờ QC'), findsNothing);
  });

  testWidgets('nhóm việc hiện tại vẫn bấm được', (tester) async {
    final result = await open(tester);

    await tester.tap(find.text('Đang phục chế'));
    await tester.pumpAndSettle();

    expect(
      result(),
      1,
      reason:
          'Khoá dòng đang chọn buộc người dùng phải đoán vì sao nó không phản '
          'hồi. Cho bấm, rồi bỏ qua ở chỗ gọi.',
    );
  });

  testWidgets('dự án chưa có nhóm việc nào thì nói rõ', (tester) async {
    await open(tester, list: const [], selected: null);

    expect(find.text('Dự án này chưa khai báo nhóm việc nào.'), findsOneWidget);
  });

  testWidgets('mỗi dòng cao 46', (tester) async {
    await open(tester);

    final row = tester.getSize(
      find
          .ancestor(of: find.text('Chờ QC'), matching: find.byType(InkWell))
          .first,
    );

    expect(row.height, 46);
  });
}
