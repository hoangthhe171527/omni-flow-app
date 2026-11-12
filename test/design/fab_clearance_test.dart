import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/nav/shell_bar_inset.dart';
import 'package:omni_app/design/components/components.dart';

/// Nút + kính phải cách RÕ thanh tab kính (rà soát 12/11: "dấu cộng sát menu,
/// bị menu đè"). Thanh thật: viên kính 66 + đáy = vùng an toàn (tối thiểu 12),
/// thêm dải mờ lan lên 12 trên viên kính. Mọi màn có nút + đều đặt qua
/// [OmniFabLayer] / [ShellBarInset.floatingBottom], nên ghim ở đây là đủ.
void main() {
  for (final safe in const [0.0, 34.0, 48.0]) {
    testWidgets('nút + cách thanh tab ≥ 32 (đáy an toàn $safe)', (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      t.view.viewPadding = FakeViewPadding(bottom: safe);
      t.view.padding = FakeViewPadding(bottom: safe);
      addTearDown(t.view.reset);

      await t.pumpWidget(
        MaterialApp(
          home: ShellBarInset(
            height: ShellBarInset.barHeight,
            child: Scaffold(
              body: OmniFabLayer(
                body: const SizedBox.expand(),
                fab: OmniLiquidFab(
                  key: const Key('fab'),
                  tooltip: 'Thêm',
                  onPressed: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();

      final pillTop =
          844 - (ShellBarInset.pillHeight + (safe > 12 ? safe : 12));
      final fab = t.getRect(find.byKey(const Key('fab')));
      final clearance = pillTop - fab.bottom;
      // 12 dải mờ của thanh + ≥ 20 khoảng trống thật.
      expect(clearance, greaterThanOrEqualTo(32));
      // Không bay quá cao khỏi vùng ngón cái.
      expect(clearance, lessThanOrEqualTo(40));
    });
  }

  testWidgets(
    'ngoài shell (màn đẩy, không thanh tab): chỉ tránh vùng an toàn',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      t.view.viewPadding = const FakeViewPadding(bottom: 34);
      t.view.padding = const FakeViewPadding(bottom: 34);
      addTearDown(t.view.reset);

      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OmniFabLayer(
              body: const SizedBox.expand(),
              fab: OmniLiquidFab(
                key: const Key('fab'),
                tooltip: 'Thêm',
                onPressed: (_) {},
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();

      final fab = t.getRect(find.byKey(const Key('fab')));
      expect(844 - 34 - fab.bottom, OmniFabLayer.gap);
    },
  );
}
