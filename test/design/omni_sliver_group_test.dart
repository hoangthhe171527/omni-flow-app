import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/design/theme/omni_theme.dart';

void main() {
  var built = 0;

  Widget host(Widget sliver) => MaterialApp(
    theme: OmniTheme.light(TargetPlatform.iOS),
    home: Scaffold(body: CustomScrollView(slivers: [sliver])),
  );

  OmniSliverGroup group(int n, {String? title}) => OmniSliverGroup(
    title: title,
    itemCount: n,
    dividerIndent: 14,
    itemBuilder: (context, i) {
      built++;
      return SizedBox(height: 56, child: Text('dòng $i'));
    },
  );

  setUp(() => built = 0);

  testWidgets('chỉ dựng dòng trong tầm nhìn — 500 dòng không dựng 500', (
    tester,
  ) async {
    await tester.pumpWidget(host(group(500)));
    expect(find.text('dòng 0'), findsOneWidget);
    expect(find.text('dòng 499'), findsNothing);
    // Màn 800 cao / dòng 57 ≈ 14 dòng + vùng đệm cuộn.
    expect(built, lessThan(40));
  });

  testWidgets('cùng hình nhóm: đầu nhóm chữ HOA, vạch ngăn giữa các dòng', (
    tester,
  ) async {
    await tester.pumpWidget(host(group(3, title: 'Quá hạn')));
    expect(find.text('QUÁ HẠN'), findsOneWidget);
    // Vạch chỉ GIỮA các dòng: 3 dòng → 2 vạch.
    expect(find.byType(Divider), findsNWidgets(2));
  });

  testWidgets('dòng đầu bo trên, dòng cuối bo dưới, giữa không bo', (
    tester,
  ) async {
    await tester.pumpWidget(host(group(3)));
    BorderRadius radiusOf(int i) {
      final m = tester.widget<Material>(
        find
            .ancestor(of: find.text('dòng $i'), matching: find.byType(Material))
            .first,
      );
      return (m.shape! as RoundedRectangleBorder).borderRadius as BorderRadius;
    }

    expect(radiusOf(0).topLeft, const Radius.circular(16));
    expect(radiusOf(0).bottomLeft, Radius.zero);
    expect(radiusOf(1), BorderRadius.zero);
    expect(radiusOf(2).bottomRight, const Radius.circular(16));
    expect(radiusOf(2).topRight, Radius.zero);
  });

  testWidgets('nhóm rỗng không vẽ gì', (tester) async {
    await tester.pumpWidget(host(group(0, title: 'Trống')));
    expect(find.text('TRỐNG'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
