import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/nav/shell_bar_inset.dart';
import 'package:omni_app/design/components/components.dart';

/// Nút + phải cách RÕ thanh tab (rà soát 12/11: "dấu cộng sát menu, bị menu
/// đè"). Thanh thật: viên kính 66 + đáy = vùng an toàn (tối thiểu 12). Khe 20
/// do người dùng chọn 25/11 trên ảnh app thật (12 / 20 / 32) sau khi nút + đổi
/// sang nền đặc, bóng mảnh. Mọi màn có nút + đều đặt qua [OmniFabLayer] /
/// [ShellBarInset.floatingBottom], nên ghim ở đây là đủ.
void main() {
  for (final safe in const [0.0, 34.0, 48.0]) {
    testWidgets('nút + cách thanh tab 20 (đáy an toàn $safe)', (t) async {
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
      // Không sát thanh (12 bị chê bóng chạm thanh)…
      expect(clearance, greaterThanOrEqualTo(20));
      // …và không bay quá cao khỏi vùng ngón cái.
      expect(clearance, lessThanOrEqualTo(28));
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

  testWidgets(
    'trong AppShell thật (extendBody + bottomNavigationBar + Scaffold lồng)',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      t.view.viewPadding = const FakeViewPadding(bottom: 34);
      t.view.padding = const FakeViewPadding(bottom: 34);
      addTearDown(t.view.reset);

      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final safe = MediaQuery.viewPaddingOf(context).bottom;
              return ShellBarInset(
                height: ShellBarInset.pillHeight + (safe > 12 ? safe : 12),
                child: Scaffold(
                  extendBody: true,
                  body: Scaffold(
                    extendBodyBehindAppBar: true,
                    body: OmniFabLayer(
                      body: const SizedBox.expand(),
                      fab: OmniLiquidFab(
                        key: const Key('fab'),
                        tooltip: 'Thêm',
                        onPressed: (_) {},
                      ),
                    ),
                  ),
                  bottomNavigationBar: Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      safe > 12 ? safe : 12,
                    ),
                    child: OmniGlass(
                      key: const Key('pill'),
                      radius: ShellBarInset.pillHeight / 2,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: const SizedBox(height: ShellBarInset.pillHeight),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await t.pumpAndSettle();

      final pill = t.getRect(find.byKey(const Key('pill')));
      final fab = t.getRect(find.byKey(const Key('fab')));
      final clearance = pill.top - fab.bottom;
      expect(clearance, greaterThanOrEqualTo(20));
      expect(clearance, lessThanOrEqualTo(28));
    },
  );
}
