import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/tasks/presentation/widgets/edit_sheets.dart';

/// Sheet sửa chữ khi bàn phím đang mở.
///
/// `showOmniSheet` đã đệm đáy bằng phần bàn phím che. Sheet nào tự đệm thêm
/// lần nữa thì nội dung bị ép vào khoảng còn lại, tràn xuống dưới: nút "Lưu"
/// vẫn VẼ ra (Column không cắt phần tràn) nhưng nằm ngoài khung nhận chạm —
/// bấm không ăn gì. Người dùng gặp ở ô Mô tả của chi tiết việc.
///
/// Màn nhỏ (iPhone SE 320×568) thì kể cả đệm đúng một lần, mô tả tám dòng
/// cũng cao hơn khoảng trên bàn phím: ô nhập phải tự cuộn, nút "Lưu" vẫn
/// trong tầm chạm.
void main() {
  const iphone = (size: Size(390, 844), top: 47.0, keyboard: 336.0);
  const se = (size: Size(320, 568), top: 20.0, keyboard: 253.0);

  Future<String?> openAndSave(
    WidgetTester t,
    ({Size size, double top, double keyboard}) screen, {
    required bool multiline,
    required String text,
    int? maxLength,
  }) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = screen.size;
    t.view.padding = FakeViewPadding(top: screen.top);
    t.view.viewInsets = FakeViewPadding(bottom: screen.keyboard);
    addTearDown(t.view.reset);

    String? result = 'chưa trả';
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  result = await showTextEditSheet(
                    context: context,
                    title: 'Mô tả',
                    initial: '',
                    hint: 'Ghi chú, yêu cầu, lưu ý khi làm…',
                    multiline: multiline,
                    allowEmpty: true,
                    maxLength: maxLength,
                  );
                },
                child: const Text('mở'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('mở'));
    await t.pumpAndSettle();

    await t.enterText(find.byType(TextField), text);
    await t.pumpAndSettle();
    // Tràn = nút nằm ngoài khung nhận chạm.
    expect(t.takeException(), isNull);

    final save = find.widgetWithText(FilledButton, 'Lưu');
    // Đáy nút phải nằm ngay trên bàn phím, không bị đẩy thêm một lần nữa.
    expect(
      t.getRect(save).bottom,
      lessThanOrEqualTo(screen.size.height - screen.keyboard),
    );
    await t.tap(save, warnIfMissed: false);
    await t.pumpAndSettle();

    return result;
  }

  final eightLines = List.generate(8, (i) => 'Bước ${i + 1}').join('\n');

  testWidgets('Mô tả (nhiều dòng, có bộ đếm): bấm Lưu khi bàn phím mở', (
    t,
  ) async {
    expect(
      await openAndSave(
        t,
        iphone,
        multiline: true,
        maxLength: 10000,
        text: 'Thay dây đàn',
      ),
      'Thay dây đàn',
    );
  });

  testWidgets('Tên việc (một dòng): bấm Lưu khi bàn phím mở', (t) async {
    expect(
      await openAndSave(t, iphone, multiline: false, text: 'Thay dây đàn'),
      'Thay dây đàn',
    );
  });

  testWidgets('màn nhỏ: mô tả tám dòng vẫn bấm Lưu được', (t) async {
    expect(
      await openAndSave(
        t,
        se,
        multiline: true,
        maxLength: 10000,
        text: eightLines,
      ),
      eightLines,
    );
  });

  testWidgets('màn nhỏ: tên việc một dòng vẫn bấm Lưu được', (t) async {
    expect(
      await openAndSave(t, se, multiline: false, text: 'Thay dây đàn'),
      'Thay dây đàn',
    );
  });
}
