import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';

/// Nút kính (liquid-buttons-uiux.html B): vệt sáng của theme phải theo dáng
/// THẬT của nút. Trước đây nó luôn vẽ viên thuốc, nút sổ chi phí bo 10 lòi
/// hai góc trên.
void main() {
  Future<ShapeBorder?> highlightShape(WidgetTester t, Widget button) async {
    await t.pumpWidget(
      MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        home: Scaffold(body: Center(child: button)),
      ),
    );
    final box = t.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(button.runtimeType),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is DecoratedBox &&
                  w.decoration is ShapeDecoration &&
                  (w.decoration as ShapeDecoration).gradient != null,
            ),
          )
          .first,
    );
    return (box.decoration as ShapeDecoration).shape;
  }

  testWidgets('nút tự bo 10: vệt sáng cùng bo 10, không viên thuốc', (t) async {
    final shape = await highlightShape(
      t,
      FilledButton(
        onPressed: () {},
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: const Text('Ghi 4 khoản'),
      ),
    );
    expect(shape, isA<RoundedRectangleBorder>());
    expect(
      (shape! as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(10),
    );
  });

  testWidgets('nút mặc định: vệt sáng dáng viên thuốc', (t) async {
    final shape = await highlightShape(
      t,
      OutlinedButton(onPressed: () {}, child: const Text('Huỷ')),
    );
    expect(shape, isA<StadiumBorder>());
  });

  testWidgets('nút kính không có viền màu chủ đạo', (t) async {
    final theme = OmniTheme.light(TargetPlatform.android);
    final side = theme.filledButtonTheme.style!.side!.resolve({})!;
    expect(side.color, isNot(theme.colorScheme.primary));
    expect(side.color.r, closeTo(1, 0.01), reason: 'mép sáng trắng');
  });
}
