import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/app/apps/app_shell_layout.dart';
import 'package:omni_app/bootstrap.dart';

/// Rà soát 12/11/2026: thanh menu Kho có ba cỡ chữ vì nhãn dài ("Nhà cung
/// cấp", "Hàng sắp về") bị FittedBox thu nhỏ. Thanh tab nay không thu nhỏ chữ
/// nữa — mọi nhãn tab phải vừa ô, tức ≤ [maxTabLabelLength] ký tự.
void main() {
  test('mọi mục điều hướng có nhãn tab ≤ $maxTabLabelLength ký tự', () {
    final tooLong = <String>[
      for (final module in appModules)
        for (final entry in module.navEntries())
          if (tabLabelOf(entry).length > maxTabLabelLength)
            '${entry.routeName}: "${tabLabelOf(entry)}"',
      for (final spec in appItemSpecs.values)
        if ((tabLabels[spec.routeName] ?? spec.label ?? '').length >
            maxTabLabelLength)
          '${spec.routeName}: "${tabLabels[spec.routeName] ?? spec.label}"',
    ];
    expect(
      tooLong,
      isEmpty,
      reason: 'Thêm nhãn ngắn vào `tabLabels` (app_shell_layout.dart).',
    );
  });

  test('Kho dùng nhãn ngắn đã duyệt', () {
    expect(tabLabels['inventory.lots'], 'Sắp về');
    expect(tabLabels['inventory.suppliers'], 'NCC');
  });
}
