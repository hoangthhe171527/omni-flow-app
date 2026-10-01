import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/design/tokens/tokens.dart';

/// Một kiểu tab cho cả app: gạch chân 2px màu chính (`SPrinciples.dc.html` §8).
void main() {
  Widget host(Widget child, {double width = 360}) => MaterialApp(
    theme: OmniTheme.light(TargetPlatform.android),
    home: Scaffold(
      body: Center(
        child: SizedBox(width: width, child: child),
      ),
    ),
  );

  const tabs = [
    OmniTab(label: 'Hôm nay', count: 4),
    OmniTab(label: 'Quá hạn', count: 3, alert: true),
    OmniTab(label: 'Sắp tới'),
    OmniTab(label: 'Tất cả'),
  ];

  BorderSide underline(WidgetTester tester, String label) {
    final box = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.widgetWithText(OmniTabItem, label),
        matching: find.byType(AnimatedContainer),
      ),
    );
    return ((box.decoration! as BoxDecoration).border! as Border).bottom;
  }

  testWidgets('tab đang chọn gạch chân 2px màu chính, tab khác không', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(OmniTabStrip(tabs: tabs, selected: 0, onSelected: (_) {})),
    );

    expect(underline(tester, 'Hôm nay').color, OmniColors.primary);
    expect(underline(tester, 'Hôm nay').width, 2);
    expect(underline(tester, 'Sắp tới').color, Colors.transparent);
  });

  testWidgets('tên tab không bị cắt ở màn 360dp', (tester) async {
    await tester.pumpWidget(
      host(OmniTabStrip(tabs: tabs, selected: 0, onSelected: (_) {})),
    );

    for (final label in ['Hôm nay', 'Quá hạn', 'Sắp tới', 'Tất cả']) {
      final text = tester.widget<Text>(find.text(label));
      expect(text.overflow, isNot(TextOverflow.ellipsis), reason: label);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('số "cần xử lý" là chip đỏ, số thường là chữ xám', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(OmniTabStrip(tabs: tabs, selected: 0, onSelected: (_) {})),
    );

    expect(
      find.descendant(
        of: find.widgetWithText(OmniTabItem, 'Quá hạn'),
        matching: find.byType(OmniBadge),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.widgetWithText(OmniTabItem, 'Hôm nay'),
        matching: find.byType(OmniBadge),
      ),
      findsNothing,
    );
  });

  testWidgets('chạm tab báo đúng chỉ số', (tester) async {
    int? picked;
    await tester.pumpWidget(
      host(
        OmniTabStrip(tabs: tabs, selected: 0, onSelected: (i) => picked = i),
      ),
    );

    await tester.tap(find.text('Quá hạn'));
    expect(picked, 1);
  });

  testWidgets('thanh tiến độ cao 4, màu chính', (tester) async {
    await tester.pumpWidget(host(const OmniProgressBar(value: 0.4)));

    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.minHeight, 4);
    expect(
      (bar.valueColor! as AlwaysStoppedAnimation<Color?>).value,
      OmniColors.primary,
    );
  });
}
