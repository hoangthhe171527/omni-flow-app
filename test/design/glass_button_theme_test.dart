import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';

/// Nút hành động chính (`FilledButton`) dùng nền đặc màu chính + chữ onPrimary;
/// nút phụ (`OutlinedButton`) dùng nền nhẹ + viền mảnh trung tính, dáng viên thuốc.
void main() {
  testWidgets('nút chính dùng nền đặc primary và chữ onPrimary', (t) async {
    final theme = OmniTheme.light(TargetPlatform.android);
    final scheme = theme.colorScheme;
    final style = theme.filledButtonTheme.style!;
    expect(style.backgroundColor!.resolve({}), scheme.primary);
    expect(style.foregroundColor!.resolve({}), scheme.onPrimary);
    expect(style.shape!.resolve({}), isA<StadiumBorder>());
  });

  testWidgets('nút tự bo 10 vẫn giữ được bo 10 riêng của nút', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        home: Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () {},
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Ghi 4 khoản'),
            ),
          ),
        ),
      ),
    );
    final btn = t.widget<FilledButton>(find.byType(FilledButton));
    final shape = btn.style!.shape!.resolve({});
    expect(shape, isA<RoundedRectangleBorder>());
    expect(
      (shape! as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(10),
    );
  });

  testWidgets('nút phụ dùng viền trung tính, không dùng viền primary', (t) async {
    final theme = OmniTheme.light(TargetPlatform.android);
    final side = theme.outlinedButtonTheme.style!.side!.resolve({})!;
    expect(side.color, isNot(theme.colorScheme.primary));
    expect(theme.outlinedButtonTheme.style!.shape!.resolve({}), isA<StadiumBorder>());
  });
}
