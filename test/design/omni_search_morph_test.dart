import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/design/theme/omni_theme.dart';

/// Ô tìm kiểu "Biến hình" (duyệt 26/11/2026, rà soát mục 6 + 18): nút lọc
/// xám / viên có số, gợi ý quay, viền cầu vồng khi đang gõ.
void main() {
  Widget host(Widget child, {bool reduce = false}) => MaterialApp(
    theme: OmniTheme.light(),
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
      child: app!,
    ),
    home: Scaffold(
      body: Center(child: SizedBox(width: 360, child: child)),
    ),
  );

  testWidgets('nút lọc: chưa lọc = icon xám, không số', (t) async {
    await t.pumpWidget(
      host(OmniSearchFilterButton(onPressed: () {}, activeFilters: 0)),
    );
    final icon = t.widget<Icon>(find.byIcon(LucideIcons.slidersHorizontal));
    final scheme = Theme.of(
      t.element(find.byType(OmniSearchFilterButton)),
    ).colorScheme;
    expect(icon.color, scheme.onSurfaceVariant);
    expect(find.text('0'), findsNothing);
    expect(t.getSize(find.byType(OmniSearchFilterButton)).height, 44);
  });

  testWidgets('nút lọc: đang lọc = viên mực có số bộ lọc', (t) async {
    await t.pumpWidget(
      host(
        OmniSearchFilterButton(
          onPressed: () {},
          activeFilters: 2,
          countKey: const Key('count'),
        ),
      ),
    );
    final scheme = Theme.of(
      t.element(find.byType(OmniSearchFilterButton)),
    ).colorScheme;
    expect(find.text('2'), findsOneWidget);
    final pill = t.widget<Container>(find.byKey(const Key('count')));
    expect((pill.decoration! as BoxDecoration).color, scheme.onSurface);
  });

  testWidgets('OmniSearchBottom: onFilter + activeFilters dựng nút lọc', (
    t,
  ) async {
    var taps = 0;
    await t.pumpWidget(
      host(
        OmniSearchBottom(
          hint: 'Tìm',
          onChanged: (_) {},
          onFilter: () => taps++,
          activeFilters: 3,
          filterKey: const Key('filter'),
        ),
      ),
    );
    expect(find.text('3'), findsOneWidget);
    await t.tap(find.byKey(const Key('filter')));
    expect(taps, 1);
  });

  testWidgets('gợi ý quay: nhiều gợi ý thì lăn sang gợi ý kế', (t) async {
    await t.pumpWidget(
      host(
        OmniSearchBottom(
          hint: 'Tìm khách…',
          hints: const ['Tìm khách…', 'Tìm đơn hàng…'],
          onChanged: (_) {},
        ),
      ),
    );
    expect(find.text('Tìm khách…'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 2300));
    await t.pump(const Duration(milliseconds: 700));
    expect(find.text('Tìm đơn hàng…'), findsOneWidget);
    expect(find.text('Tìm khách…'), findsNothing);
  });

  testWidgets('gợi ý quay: giảm chuyển động thì đứng yên', (t) async {
    await t.pumpWidget(
      host(
        OmniSearchBottom(
          hint: 'Tìm khách…',
          hints: const ['Tìm khách…', 'Tìm đơn hàng…'],
          onChanged: (_) {},
        ),
        reduce: true,
      ),
    );
    await t.pump(const Duration(milliseconds: 2300));
    await t.pump(const Duration(milliseconds: 700));
    expect(find.text('Tìm khách…'), findsOneWidget);
    expect(find.text('Tìm đơn hàng…'), findsNothing);
  });

  testWidgets('đang gõ: viền cầu vồng bật rồi tắt', (t) async {
    await t.pumpWidget(host(OmniSearchBottom(hint: 'Tìm', onChanged: (_) {})));
    double ring() => t
        .widget<AnimatedOpacity>(find.byKey(const Key('omni-search-busy-ring')))
        .opacity;
    expect(ring(), 0);

    await t.enterText(find.byType(TextField), 'lan');
    await t.pump();
    expect(ring(), 1);

    await t.pump(const Duration(milliseconds: 700));
    await t.pump();
    expect(ring(), 0);
    await t.pumpAndSettle();
  });
}
