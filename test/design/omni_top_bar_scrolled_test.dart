import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/components/omni_top_bar.dart';
import 'package:omni_app/design/theme/omni_theme.dart';

/// Chuẩn iOS (gói Viomni: "thanh trên khi đã cuộn"): đầu trang thanh trong
/// suốt; nội dung cuộn vào dưới thanh thì thanh hiện nền kính phẳng — không để
/// chữ của thân màn đè lên tiêu đề (lỗi 26/11/2026, màn Tổng quan).
void main() {
  double backdrop(WidgetTester t) => t
      .widget<AnimatedOpacity>(find.byKey(const Key('omni-top-bar-backdrop')))
      .opacity;

  Future<void> pump(WidgetTester t) => t.pumpWidget(
    MaterialApp(
      theme: OmniTheme.light(),
      home: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: const OmniTopBar(
          semanticsTitle: 'Tổng quan',
          showBell: false,
          showAccount: false,
        ),
        body: ListView(
          children: [
            for (var i = 0; i < 40; i++)
              SizedBox(height: 60, child: Text('Dòng $i')),
          ],
        ),
      ),
    ),
  );

  testWidgets('đầu trang trong suốt, cuộn thì hiện nền, về đầu thì ẩn', (
    t,
  ) async {
    await pump(t);
    expect(backdrop(t), 0);

    await t.drag(find.byType(ListView), const Offset(0, -300));
    await t.pumpAndSettle();
    expect(backdrop(t), 1);

    await t.drag(find.byType(ListView), const Offset(0, 600));
    await t.pumpAndSettle();
    expect(backdrop(t), 0);
  });

  testWidgets('cuộn ngang không đổi thanh', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: OmniTheme.light(),
        home: Scaffold(
          extendBodyBehindAppBar: true,
          appBar: const OmniTopBar(
            semanticsTitle: 'Tổng quan',
            showBell: false,
            showAccount: false,
          ),
          body: Center(
            child: SizedBox(
              height: 60,
              child: ListView(
                key: const Key('chips'),
                scrollDirection: Axis.horizontal,
                children: [
                  for (var i = 0; i < 30; i++)
                    SizedBox(width: 80, child: Text('Chip $i')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await t.drag(find.byKey(const Key('chips')), const Offset(-400, 0));
    await t.pumpAndSettle();
    expect(backdrop(t), 0);
  });
}
