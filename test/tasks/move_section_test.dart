import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/presentation/widgets/move_section_sheet.dart';

/// Chọn công đoạn mới, thay cho kéo thả.
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

  Future<String?> open(
    WidgetTester tester, {
    List<TaskSection> list = sections,
    String? current = 's2',
  }) async {
    String? result;
    var returned = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showMoveSectionSheet(
                  context: context,
                  sections: list,
                  current: current,
                );
                returned = true;
              },
              child: const Text('mở'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();

    return returned ? result : null;
  }

  testWidgets('liệt kê đúng các nhóm việc của dự án', (tester) async {
    await open(tester);

    expect(find.text('Nhập xưởng'), findsOneWidget);
    expect(find.text('Đang phục chế'), findsOneWidget);
    expect(find.text('Chờ QC'), findsOneWidget);
  });

  testWidgets('đánh dấu nhóm việc đang đứng', (tester) async {
    await open(tester);

    expect(find.byIcon(Icons.radio_button_checked_rounded), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsNWidgets(2));
  });

  testWidgets('chọn một nhóm việc thì đóng lại và trả về id của nó', (
    tester,
  ) async {
    String? chosen;

    await tester.pumpWidget(
      MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                chosen = await showMoveSectionSheet(
                  context: context,
                  sections: sections,
                  current: 's2',
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
    await tester.tap(find.text('Chờ QC'));
    await tester.pumpAndSettle();

    expect(chosen, 's3');
    expect(find.text('Chờ QC'), findsNothing);
  });

  testWidgets('nhóm việc hiện tại vẫn bấm được', (tester) async {
    String? chosen;
    var settled = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                chosen = await showMoveSectionSheet(
                  context: context,
                  sections: sections,
                  current: 's2',
                );
                settled = true;
              },
              child: const Text('mở'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đang phục chế'));
    await tester.pumpAndSettle();

    expect(
      settled,
      isTrue,
      reason:
          'Khoá dòng đang chọn buộc người dùng phải đoán vì sao nó không phản '
          'hồi. Cho bấm, rồi bỏ qua ở chỗ gọi.',
    );
    expect(chosen, 's2');
  });

  testWidgets('dự án chưa có nhóm việc nào thì nói rõ', (tester) async {
    await open(tester, list: const [], current: null);

    expect(find.text('Dự án này chưa khai báo nhóm việc nào.'), findsOneWidget);
  });

  testWidgets('mỗi dòng cao ít nhất 56dp', (tester) async {
    await open(tester);

    final tile = tester.getSize(
      find.ancestor(of: find.text('Chờ QC'), matching: find.byType(ListTile)),
    );

    expect(
      tile.height,
      greaterThanOrEqualTo(56),
      reason: 'Người bấm nó cũng là người đang đứng ở bàn làm việc.',
    );
  });
}
