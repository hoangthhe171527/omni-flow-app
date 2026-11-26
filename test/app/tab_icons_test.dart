import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/app/apps/app_shell_layout.dart';
import 'package:omni_app/app/shell/tab_icons.dart';
import 'package:omni_app/bootstrap.dart';

/// Phương án C "đặc + nhãn" (26/11/2026): thanh tab dùng icon đặc. Người dùng
/// ghim được mọi mục lên thanh, nên mọi mục điều hướng phải có icon đặc —
/// thiếu thì thanh lẫn một icon nét giữa các icon đặc.
void main() {
  test('mọi mục điều hướng có icon đặc trong `tabIcons`', () {
    final missing = <String>{
      for (final module in appModules)
        for (final entry in module.navEntries())
          if (!tabIcons.containsKey(entry.routeName)) entry.routeName,
      for (final spec in appItemSpecs.values)
        if (!tabIcons.containsKey(spec.routeName)) spec.routeName,
    };
    expect(
      missing,
      isEmpty,
      reason:
          'Thêm icon Phosphor Fill vào `tabIcons` (app/shell/tab_icons.dart).',
    );
  });

  test('không hai mục dùng chung một icon đặc', () {
    final byIcon = <int, List<String>>{};
    tabIcons.forEach(
      (route, icon) => (byIcon[icon.codePoint] ??= []).add(route),
    );
    final shared = byIcon.values.where((r) => r.length > 1).toList();
    expect(shared, isEmpty);
  });
}
