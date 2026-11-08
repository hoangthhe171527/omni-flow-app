import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
      host(OmniPerfTier.full, const OmniGlassCircle(child: Icon(Icons.add))),
    );
    expect(blurs(t), 0);
  });

  testWidgets('dải mờ mép: 1 lớp ở bậc đầy đủ (trước là 3), 0 ở bậc giảm', (
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
    expect(blurs(t), 1);
    await t.pumpWidget(edge(OmniPerfTier.reduced));
    expect(blurs(t), 0);
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
