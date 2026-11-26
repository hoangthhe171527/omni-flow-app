import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/design/tokens/tokens.dart';

/// Đợt A2: ô tìm chuẩn "có điều khiển" — thay các ô tìm tự dựng ở Khách,
/// Hộp thư, Cơ hội (vốn tự giữ controller để theo bộ lọc đặt lại).
void main() {
  String text(WidgetTester t) =>
      t.widget<TextField>(find.byType(TextField)).controller!.text;

  Future<ValueNotifier<String>> pump(WidgetTester t, List<String> sent) async {
    final store = ValueNotifier('');
    await t.pumpWidget(
      MaterialApp(
        theme: OmniTheme.light(),
        home: Scaffold(
          body: ValueListenableBuilder<String>(
            valueListenable: store,
            builder: (_, v, _) => OmniSearchField(
              hint: 'Tìm',
              flat: true,
              debounce: const Duration(milliseconds: 300),
              value: v,
              onChanged: (s) {
                sent.add(s);
                store.value = s;
              },
            ),
          ),
        ),
      ),
    );
    return store;
  }

  testWidgets('gõ → gửi sau độ trễ; giá trị đổi từ nơi khác → ô theo', (
    t,
  ) async {
    final sent = <String>[];
    final store = await pump(t, sent);

    await t.enterText(find.byType(TextField), 'lan');
    await t.pump(const Duration(milliseconds: 310));
    expect(sent, ['lan']);

    store.value = ''; // bộ lọc bị đặt lại
    await t.pump();
    expect(text(t), '');
  });

  testWidgets('đặt lại giữa lúc đang gõ: huỷ lượt gõ đang chờ', (t) async {
    final sent = <String>[];
    final store = await pump(t, sent);
    store.value = 'cũ';
    await t.pump();
    expect(text(t), 'cũ');

    await t.enterText(find.byType(TextField), 'mới');
    store.value = 'đặt lại';
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(sent, isEmpty, reason: 'hẹn giờ cũ không được gửi "mới" đè lên');
    expect(text(t), 'đặt lại');
  });

  testWidgets('✕ xoá chữ và gửi rỗng ngay, nhãn "Xoá tìm kiếm"', (t) async {
    final sent = <String>[];
    await pump(t, sent);
    await t.enterText(find.byType(TextField), 'abc');
    await t.pump(const Duration(milliseconds: 310));
    await t.tap(find.byTooltip('Xoá tìm kiếm'));
    await t.pump();
    expect(sent.last, '');
    expect(text(t), '');
  });

  Future<void> pumpBare(WidgetTester t, Widget field) => t.pumpWidget(
    MaterialApp(
      theme: OmniTheme.light(),
      home: Scaffold(body: field),
    ),
  );

  // Lọc tại chỗ (Sổ chi phí, màn Việc): không chờ, gửi ngay từng phím.
  testWidgets('debounce 0 → gửi ngay, không cần chờ hẹn giờ', (t) async {
    final sent = <String>[];
    await pumpBare(
      t,
      OmniSearchField(
        hint: 'Tìm',
        debounce: Duration.zero,
        onChanged: sent.add,
      ),
    );
    await t.enterText(find.byType(TextField), ' 2.45tr ');
    expect(sent, ['2.45tr']);
  });

  // Đầu Bảng kế hoạch nằm trên ảnh bìa: chữ trắng, viên kính bo tròn.
  testWidgets('onCover: chữ trắng, viên kính bo tròn, đặc khi tương phản cao', (
    t,
  ) async {
    Widget field() => OmniSearchField(
      hint: 'Tìm trong kế hoạch',
      onCover: true,
      onChanged: (_) {},
    );
    await pumpBare(t, field());
    final input = t.widget<TextField>(find.byType(TextField));
    expect(input.style!.color, Colors.white);
    final border = input.decoration!.border! as OutlineInputBorder;
    expect(border.borderRadius, OmniRadius.pillAll);
    expect(input.decoration!.fillColor, Colors.white.withValues(alpha: .20));

    await t.pumpWidget(
      MaterialApp(
        theme: OmniTheme.light(),
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(highContrast: true),
          child: child!,
        ),
        home: Scaffold(body: field()),
      ),
    );
    expect(
      t.widget<TextField>(find.byType(TextField)).decoration!.fillColor,
      OmniCovers.glass,
    );
  });
}
