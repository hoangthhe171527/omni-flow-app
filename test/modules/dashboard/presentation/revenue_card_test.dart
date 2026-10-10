import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/design/components/omni_segmented.dart';
import 'package:omni_app/design/components/omni_states.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/design/tokens/omni_colors.dart';
import 'package:omni_app/modules/dashboard/application/dashboard_providers.dart';
import 'package:omni_app/modules/dashboard/domain/revenue_period.dart';
import 'package:omni_app/modules/dashboard/domain/revenue_series.dart';
import 'package:omni_app/modules/dashboard/presentation/widgets/revenue_card.dart';
import 'package:omni_app/modules/dashboard/presentation/widgets/revenue_chart.dart';

RevenueSeries series(
  RevenueRange r, {
  double? target = 3500e6,
  double cur = 100e6,
  double prev = 90e6,
}) => RevenueSeries(
  range: r,
  current: [for (var i = 0; i < 10; i++) cur],
  previous: [for (var i = 0; i < 30; i++) prev],
  target: target,
  slots: switch (r) {
    RevenueRange.week => 7,
    RevenueRange.month => 31,
    RevenueRange.year => 12,
  },
);

Widget host(Future<RevenueSeries?> Function(Ref ref) fn) => ProviderScope(
  key: UniqueKey(),
  overrides: [revenueSeriesProvider.overrideWith(fn)],
  child: MaterialApp(
    theme: OmniTheme.light(),
    home: const MediaQuery(
      data: MediaQueryData(size: Size(800, 600), disableAnimations: true),
      child: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(width: 360, child: RevenueCard()),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('đổi sang Năm → provider gọi với year; số lớn + ▲', (t) async {
    final ranges = <RevenueRange>[];
    await t.pumpWidget(
      host((ref) async {
        final r = ref.watch(revenueRangeProvider);
        ranges.add(r);
        return series(r);
      }),
    );
    await t.pumpAndSettle();
    expect(find.text('1 tỷ'), findsOneWidget); // 10 × 100tr
    expect(find.text('11%'), findsOneWidget); // 1000/900
    expect(find.byIcon(Icons.arrow_drop_up_rounded), findsOneWidget);
    expect(find.textContaining('cùng kỳ'), findsOneWidget);
    await t.tap(find.text('Năm'));
    await t.pumpAndSettle();
    expect(ranges.last, RevenueRange.year);
    expect(find.text('Doanh thu năm nay'), findsOneWidget);
    expect(find.text('T12'), findsOneWidget); // vạch trục
  });

  testWidgets('giảm → ▼ màu nguy; không có kỳ trước → —', (t) async {
    await t.pumpWidget(
      host((ref) async => series(RevenueRange.month, prev: 200e6)),
    );
    await t.pumpAndSettle();
    final down = t.widget<Text>(find.text('50%'));
    expect(down.style?.color, OmniColors.dangerText);
    expect(find.byIcon(Icons.arrow_drop_down_rounded), findsOneWidget);
    await t.pumpWidget(
      host(
        (ref) async => RevenueSeries(
          range: RevenueRange.month,
          current: [1e6],
          previous: const [],
          target: null,
          slots: 31,
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('% mục tiêu chỉ khi có chỉ tiêu; chú giải luôn có', (t) async {
    await t.pumpWidget(host((ref) async => series(RevenueRange.month)));
    await t.pumpAndSettle();
    expect(find.text('29% mục tiêu'), findsOneWidget);
    expect(find.text('Kỳ này'), findsOneWidget);
    expect(find.text('Kỳ trước'), findsOneWidget);
    await t.pumpWidget(
      host((ref) async => series(RevenueRange.week, target: null)),
    );
    await t.pumpAndSettle();
    expect(find.textContaining('mục tiêu'), findsNothing);
  });

  testWidgets('đang kéo → số lớn = giá trị ngày + Kỳ trước + nhãn ngày', (
    t,
  ) async {
    await t.pumpWidget(host((ref) async => series(RevenueRange.month)));
    await t.pumpAndSettle();
    t.widget<RevenueChart>(find.byType(RevenueChart)).onScrub(4); // ngày 5
    await t.pump();
    expect(find.text('500 tr'), findsWidgets);
    expect(find.text('Kỳ trước: 450 tr'), findsOneWidget);
    expect(find.text('Ngày 5'), findsOneWidget);
    t.widget<RevenueChart>(find.byType(RevenueChart)).onScrub(null);
    await t.pump();
    expect(find.text('1 tỷ'), findsOneWidget);
  });

  testWidgets('provider null → không có gì của thẻ', (t) async {
    await t.pumpWidget(host((ref) async => null));
    await t.pumpAndSettle();
    expect(find.byType(OmniSegmented), findsNothing);
    expect(find.byType(RevenueChart), findsNothing);
  });

  testWidgets('lỗi 500 → Thử lại (≥44) gọi lại provider', (t) async {
    var calls = 0;
    await t.pumpWidget(
      host((ref) async {
        calls++;
        throw const ServerException('Lỗi máy chủ', code: '500');
      }),
    );
    await t.pumpAndSettle();
    expect(find.byType(OmniErrorView), findsOneWidget);
    final btn = find.text('Thử lại');
    expect(btn, findsOneWidget);
    expect(
      t
          .getSize(
            find
                .ancestor(
                  of: btn,
                  matching: find.byWidgetPredicate(
                    (w) => w is ButtonStyleButton,
                  ),
                )
                .first,
          )
          .height,
      greaterThanOrEqualTo(44),
    );
    await t.tap(btn);
    await t.pumpAndSettle();
    expect(calls, 2);
  });

  testWidgets('đang tải → khung xương, không số 0', (t) async {
    final c = Completer<RevenueSeries?>();
    await t.pumpWidget(host((ref) => c.future));
    await t.pump();
    expect(find.byType(OmniSkeletonBox), findsWidgets);
    expect(find.text('0 đ'), findsNothing);
    c.complete(null);
    await t.pumpAndSettle();
  });

  testWidgets('toàn 0 → hiện 0 đ và biểu đồ', (t) async {
    await t.pumpWidget(
      host((ref) async => series(RevenueRange.month, cur: 0, prev: 0)),
    );
    await t.pumpAndSettle();
    expect(find.text('0 đ'), findsWidgets);
    expect(find.byType(RevenueChart), findsOneWidget);
  });

  testWidgets('giữ đúng một thể hiện chuỗi; vòng điểm cuối = nền thẻ', (
    t,
  ) async {
    final s = series(RevenueRange.month);
    await t.pumpWidget(host((ref) async => s));
    await t.pumpAndSettle();
    final chart = t.widget<RevenueChart>(find.byType(RevenueChart));
    expect(identical(chart.series, s), isTrue);
    expect(chart.ringColor, OmniTheme.light().colorScheme.surface);
  });

  testWidgets('Tháng OK, đổi sang Năm lỗi → Thử lại, không giữ số cũ', (
    t,
  ) async {
    await t.pumpWidget(
      host((ref) async {
        final r = ref.watch(revenueRangeProvider);
        if (r == RevenueRange.year) {
          throw const ServerException('Lỗi máy chủ', code: '500');
        }
        return series(r);
      }),
    );
    await t.pumpAndSettle();
    expect(find.text('1 tỷ'), findsOneWidget);
    await t.tap(find.text('Năm'));
    await t.pumpAndSettle();
    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.text('1 tỷ'), findsNothing);
  });

  testWidgets('đang tải kỳ mới → nội dung cũ mờ đi', (t) async {
    final year = Completer<RevenueSeries?>();
    await t.pumpWidget(
      host((ref) {
        final r = ref.watch(revenueRangeProvider);
        if (r == RevenueRange.year) return year.future;
        return Future.value(series(r));
      }),
    );
    await t.pumpAndSettle();
    double dim() => t
        .widget<AnimatedOpacity>(find.byKey(const ValueKey('revenue-stale')))
        .opacity;
    expect(dim(), 1.0);
    await t.tap(find.text('Năm'));
    await t.pump();
    expect(dim(), lessThan(1.0));
    year.complete(series(RevenueRange.year));
    await t.pumpAndSettle();
    expect(dim(), 1.0);
    expect(find.text('Doanh thu năm nay'), findsOneWidget);
  });
}
