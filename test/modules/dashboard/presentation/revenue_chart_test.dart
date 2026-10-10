import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/dashboard/domain/revenue_period.dart';
import 'package:omni_app/modules/dashboard/domain/revenue_series.dart';
import 'package:omni_app/modules/dashboard/presentation/widgets/revenue_chart.dart';

RevenueSeries series({double? target = 3500e6}) => RevenueSeries(
  range: RevenueRange.month,
  current: [for (var i = 0; i < 10; i++) 100e6],
  previous: [for (var i = 0; i < 30; i++) 90e6],
  target: target,
  slots: 31,
);

Widget host(
  RevenueSeries s, {
  int? scrubIndex,
  ValueChanged<int?>? onScrub,
  bool animations = true,
  ThemeData? theme,
}) => MaterialApp(
  theme: theme ?? OmniTheme.light(),
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(800, 600),
      disableAnimations: !animations,
    ),
    child: Scaffold(
      body: Center(
        child: SizedBox(
          width: 310,
          child: RevenueChart(
            series: s,
            scrubIndex: scrubIndex,
            onScrub: onScrub ?? (_) {},
          ),
        ),
      ),
    ),
  ),
);

RevenueChartPainter painterOf(WidgetTester t) =>
    t
            .widget<CustomPaint>(
              find.descendant(
                of: find.byType(RevenueChart),
                matching: find.byWidgetPredicate(
                  (w) => w is CustomPaint && w.painter is RevenueChartPainter,
                ),
              ),
            )
            .painter!
        as RevenueChartPainter;

void main() {
  testWidgets('cao 112; không chỉ tiêu → không vạch cam', (t) async {
    await t.pumpWidget(host(series(target: null), animations: false));
    await t.pump();
    expect(t.getSize(find.byType(RevenueChart)).height, 112);
    expect(painterOf(t).showTarget, isFalse);
  });

  testWidgets('có chỉ tiêu → showTarget', (t) async {
    await t.pumpWidget(host(series(), animations: false));
    await t.pump();
    expect(painterOf(t).showTarget, isTrue);
  });

  testWidgets('kéo ngang báo chỉ số ngày; thả tay → null', (t) async {
    final got = <int?>[];
    await t.pumpWidget(host(series(), onScrub: got.add, animations: false));
    final r = t.getRect(find.byType(RevenueChart));
    await t.dragFrom(
      Offset(r.left + 10, r.center.dy),
      Offset(r.width / 2 - 10, 0),
    );
    await t.pump();
    expect(got.last, isNull);
    expect(got[got.length - 2], 15); // round(0.5 * 30)
  });

  testWidgets('ngày tương lai → chỉ hiện kỳ trước', (t) async {
    final s = series();
    expect(s.valueAt(20), isNull);
    await t.pumpWidget(host(s, scrubIndex: 20, animations: false));
    await t.pump();
    expect(find.textContaining('Chưa tới'), findsOneWidget);
    expect(find.textContaining('Kỳ trước 1,89 tỷ'), findsOneWidget);
    expect(painterOf(t).scrubIndex, 20);
  });

  testWidgets('ngày đã qua → hiện giá trị kỳ này', (t) async {
    await t.pumpWidget(host(series(), scrubIndex: 4, animations: false));
    await t.pump();
    expect(find.textContaining('500 tr'), findsOneWidget);
    expect(find.textContaining('Kỳ trước 450 tr'), findsOneWidget);
  });

  testWidgets('Semantics tóm tắt + tăng/giảm dời ngày', (t) async {
    final h = t.ensureSemantics();
    final got = <int?>[];
    final s = series();
    await t.pumpWidget(
      host(s, scrubIndex: 3, onScrub: got.add, animations: false),
    );
    await t.pump();
    final node = t.getSemantics(find.bySemanticsLabel(s.summary()));
    final data = node.getSemanticsData();
    expect(data.hasAction(SemanticsAction.increase), isTrue);
    expect(data.hasAction(SemanticsAction.decrease), isTrue);
    final owner = node.owner!;
    owner.performAction(node.id, SemanticsAction.increase);
    owner.performAction(node.id, SemanticsAction.decrease);
    expect(got, [4, 2]);
    h.dispose();
  });

  testWidgets('tắt chuyển động → vẽ đủ ngay', (t) async {
    await t.pumpWidget(host(series(), animations: false));
    await t.pump();
    expect(painterOf(t).progress, 1.0);
  });

  testWidgets('bật chuyển động → đang vẽ dần ở 100ms', (t) async {
    await t.pumpWidget(host(series()));
    await t.pump(const Duration(milliseconds: 100));
    expect(painterOf(t).progress, lessThan(1.0));
    await t.pumpAndSettle();
    expect(painterOf(t).progress, 1.0);
  });

  testWidgets('theme tối: màu đường = primary tối', (t) async {
    final dark = OmniTheme.dark();
    await t.pumpWidget(host(series(), animations: false, theme: dark));
    await t.pumpAndSettle();
    expect(painterOf(t).lineColor, dark.colorScheme.primary);
  });

  testWidgets('chạm rồi cuộn dọc → onScrub(null), không kẹt', (t) async {
    final got = <int?>[];
    await t.pumpWidget(
      MaterialApp(
        theme: OmniTheme.light(),
        home: Scaffold(
          body: ListView(
            children: [
              SizedBox(
                width: 310,
                child: RevenueChart(series: series(), onScrub: got.add),
              ),
              const SizedBox(height: 2000),
            ],
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final r = t.getRect(find.byType(RevenueChart));
    final g = await t.startGesture(r.center);
    await t.pump(const Duration(milliseconds: 200));
    await g.moveBy(const Offset(0, -40));
    await g.moveBy(const Offset(0, -40));
    await g.up();
    await t.pumpAndSettle();
    expect(got, isNotEmpty);
    expect(got.last, isNull);
  });

  testWidgets('chạm nhả → onScrub(null)', (t) async {
    final got = <int?>[];
    await t.pumpWidget(host(series(), onScrub: got.add, animations: false));
    await t.tap(find.byType(RevenueChart));
    await t.pump();
    expect(got.last, isNull);
  });

  testWidgets('chuỗi mới bằng giá trị → không vẽ lại từ đầu', (t) async {
    await t.pumpWidget(host(series()));
    await t.pumpAndSettle();
    expect(painterOf(t).progress, 1.0);
    await t.pumpWidget(host(series()));
    await t.pump(const Duration(milliseconds: 100));
    expect(painterOf(t).progress, 1.0);
  });

  test('RevenueSeries so sánh theo giá trị', () {
    expect(series(), series());
    expect(series().hashCode, series().hashCode);
    expect(series() == series(target: null), isFalse);
  });

  testWidgets('Semantics có gợi ý vuốt', (t) async {
    final h = t.ensureSemantics();
    final s = series();
    await t.pumpWidget(host(s, animations: false));
    await t.pump();
    final data = t
        .getSemantics(find.bySemanticsLabel(s.summary()))
        .getSemanticsData();
    expect(data.hint, 'Vuốt lên/xuống để xem từng ngày');
    h.dispose();
  });

  testWidgets('ringColor dùng cho vòng điểm cuối', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: OmniTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 310,
            child: RevenueChart(
              series: series(),
              onScrub: (_) {},
              ringColor: const Color(0xFF123456),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(painterOf(t).surfaceColor, const Color(0xFF123456));
  });
}
