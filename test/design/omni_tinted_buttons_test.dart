import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/design/theme/omni_theme.dart';

/// Nút kính trắng mờ chìm trên nền trắng (form Thêm khách, sheet, thẻ nhóm).
/// Trên bề mặt trắng nút đổi sang "kính nhuộm tông" (phương án B duyệt
/// 08/11/2026): nút chính nền xanh nhạt chữ xanh, nút phụ nền xám nhạt chữ
/// mực — không tô đặc, không viền màu. Trên nền xám vẫn là kính trắng.
void main() {
  Color? bg(WidgetTester t, String label, Type type) {
    final button = t.widget<ButtonStyleButton>(
      find.ancestor(of: find.text(label), matching: find.byType(type)).first,
    );
    final context = t.element(find.text(label));
    final style = Theme.of(context).filledButtonTheme.style;
    final outlined = Theme.of(context).outlinedButtonTheme.style;
    final s = type == FilledButton ? style : outlined;
    return (button.style ?? s)?.backgroundColor?.resolve(<WidgetState>{});
  }

  Widget host(Widget child) => MaterialApp(
    theme: OmniTheme.light(),
    home: Scaffold(body: Center(child: child)),
  );

  Widget buttons() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      FilledButton(onPressed: () {}, child: const Text('Lưu')),
      OutlinedButton(onPressed: () {}, child: const Text('Huỷ')),
    ],
  );

  testWidgets('nền xám: nút chính đặc primary, nút phụ nền đặc nhẹ', (t) async {
    await t.pumpWidget(host(buttons()));
    final scheme = OmniTheme.light().colorScheme;
    expect(bg(t, 'Lưu', FilledButton), scheme.primary);
    expect(bg(t, 'Huỷ', OutlinedButton)!.a, 1.0);
  });

  testWidgets('trong thẻ nhóm trắng: nút chính xanh nhạt, nút phụ xám nhạt', (
    t,
  ) async {
    await t.pumpWidget(host(OmniGroupSection(children: [buttons()])));
    final scheme = OmniTheme.light().colorScheme;
    final pri = bg(t, 'Lưu', FilledButton)!;
    final sec = bg(t, 'Huỷ', OutlinedButton)!;
    // Nhuộm tông: khác hẳn nền trắng của thẻ, nghiêng về màu chính / mực.
    expect(pri, isNot(scheme.surface));
    expect(pri.b, greaterThan(pri.r), reason: 'nút chính ngả xanh');
    expect(sec, isNot(scheme.surface));
    expect(sec.a, 1.0, reason: 'nền đặc pha sẵn, không trong suốt chìm vào');
  });

  testWidgets('trong sheet kính: nút cũng nhuộm tông', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: OmniTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showOmniSheet<void>(
                context: context,
                builder: (_) => buttons(),
              ),
              child: const Text('mở'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('mở'));
    await t.pumpAndSettle();
    final pri = bg(t, 'Lưu', FilledButton)!;
    expect(pri, isNot(Colors.white.withValues(alpha: .82)));
    expect(pri.b, greaterThan(pri.r));
  });
}
