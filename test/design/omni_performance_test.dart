import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:omni_app/design/components/components.dart';

/// Bậc hiệu năng (rà soát 08/11/2026): đo trên web CPU ×4, tắt làm mờ đưa
/// màn Tất cả từ 13,8 lên 58 khung/giây. Mỗi BackdropFilter đè nội dung cuộn
/// phải vẽ lại mỗi khung — đếm số lớp là cách giữ hiệu năng không trôi.
void main() {
  Widget host(OmniPerfTier? tier, Widget child) {
    final body = Scaffold(body: Center(child: child));
    return MaterialApp(
      home: tier == null ? body : OmniPerformanceScope(tier: tier, child: body),
    );
  }

  int blurs(WidgetTester t) => find.byType(BackdropFilter).evaluate().length;

  Widget glass() =>
      const OmniGlass(radius: 22, child: SizedBox(width: 100, height: 44));

  testWidgets('không có scope: coi như bậc đầy đủ, viên kính làm mờ', (
    t,
  ) async {
    await t.pumpWidget(host(null, glass()));
    expect(blurs(t), 1);
  });

  testWidgets('bậc tối giản: viên kính không còn BackdropFilter', (t) async {
    await t.pumpWidget(host(OmniPerfTier.minimal, glass()));
    expect(blurs(t), 0);
    expect(find.byType(OmniGlass), findsOneWidget);
  });

  testWidgets('bậc giảm: vẫn làm mờ (nhẹ hơn)', (t) async {
    await t.pumpWidget(host(OmniPerfTier.reduced, glass()));
    expect(blurs(t), 1);
  });

  testWidgets('nút tròn 44 của thanh trên không làm mờ ở mọi bậc', (t) async {
    await t.pumpWidget(
      host(
        OmniPerfTier.full,
        const OmniGlassCircle(child: Icon(LucideIcons.plus)),
      ),
    );
    expect(blurs(t), 0);
  });

  testWidgets('dải mờ mép: chỉ dải màu, không nhoè ở mọi bậc (26/11)', (
    t,
  ) async {
    Widget edge(OmniPerfTier tier) => host(
      tier,
      const SizedBox(
        width: 390,
        height: 60,
        child: OmniScrollEdge(atTop: true),
      ),
    );
    await t.pumpWidget(edge(OmniPerfTier.full));
    expect(blurs(t), 0);
    await t.pumpWidget(edge(OmniPerfTier.reduced));
    expect(blurs(t), 0);
  });

  testWidgets('opaque (menu, popover, khay đáy): nền đặc, không nhoè', (
    t,
  ) async {
    await t.pumpWidget(
      host(
        OmniPerfTier.full,
        const OmniGlass(
          opaque: true,
          radius: 16,
          child: SizedBox(width: 100, height: 44),
        ),
      ),
    );
    expect(blurs(t), 0);
    final box = t.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(OmniGlass),
            matching: find.byType(DecoratedBox),
          )
          .last,
    );
    final ctx = t.element(find.byType(OmniGlass));
    expect(
      (box.decoration as BoxDecoration).color,
      Theme.of(ctx).colorScheme.surface,
    );
  });

  testWidgets('kính phẳng: không vệt sáng (gradient), nền .92', (t) async {
    await t.pumpWidget(host(OmniPerfTier.full, glass()));
    final box = t.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(OmniGlass),
            matching: find.byType(DecoratedBox),
          )
          .last,
    );
    final deco = box.decoration as BoxDecoration;
    expect(deco.gradient, isNull);
    expect(deco.color!.a, closeTo(.92, .005));
  });

  testWidgets('tương phản cao vẫn là nền đặc dù bậc đầy đủ', (t) async {
    await t.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(highContrast: true),
        child: host(OmniPerfTier.full, glass()),
      ),
    );
    expect(blurs(t), 0);
  });
}
