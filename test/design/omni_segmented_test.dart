import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/design/theme/omni_theme.dart';

void main() {
  // Một ThemeData dùng chung: theme mới mỗi lần pump làm MaterialApp chạy
  // hiệu ứng đổi theme, che mất việc kiểm tra con trượt.
  final theme = OmniTheme.light(TargetPlatform.android);

  Widget host(Widget child, {bool reduce = false}) => MaterialApp(
    theme: theme,
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduce),
      child: Scaffold(
        body: Center(child: SizedBox(width: 360, child: child)),
      ),
    ),
  );

  testWidgets('chạm đoạn 2 gọi onChanged(1), mỗi đoạn cao ≥ 44', (t) async {
    var picked = -1;
    await t.pumpWidget(
      host(
        OmniSegmented(
          labels: const ['Khách hàng · 128', 'Cơ hội · 24'],
          index: 0,
          onChanged: (i) => picked = i,
        ),
      ),
    );
    await t.tap(find.text('Cơ hội · 24'));
    expect(picked, 1);
    expect(
      t.getSize(find.byType(OmniSegmented)).height,
      greaterThanOrEqualTo(44),
    );
    expect(find.bySemanticsLabel(RegExp('Khách hàng · 128')), findsOneWidget);
  });

  testWidgets('giảm chuyển động: con trượt tới nơi sau một pump', (t) async {
    Widget seg(int i) => host(
      OmniSegmented(labels: const ['A', 'B'], index: i, onChanged: (_) {}),
      reduce: true,
    );
    await t.pumpWidget(seg(0));
    await t.pumpWidget(seg(1));
    await t.pump();
    expect(t.hasRunningAnimations, isFalse);
  });

  testWidgets('vòng tiến độ ghi % bằng chữ ≥ 12', (t) async {
    await t.pumpWidget(
      host(const OmniProgressRing(percent: 60, color: Colors.orange)),
    );
    final text = t.widget<Text>(find.text('60%'));
    expect(text.style?.fontSize ?? 14, greaterThanOrEqualTo(12));
  });

  testWidgets('trợ năng: chạm ngữ nghĩa đổi đoạn', (t) async {
    final handle = t.ensureSemantics();
    var picked = -1;
    await t.pumpWidget(
      host(
        OmniSegmented(
          labels: const ['A', 'B'],
          index: 0,
          onChanged: (i) => picked = i,
        ),
      ),
    );
    t.semantics.tap(find.semantics.byLabel('B'));
    expect(picked, 1);
    handle.dispose();
  });

  testWidgets('mỗi đoạn có vùng chạm cao ≥ 44', (t) async {
    await t.pumpWidget(
      host(
        OmniSegmented(labels: const ['A', 'B'], index: 0, onChanged: (_) {}),
      ),
    );
    for (final l in ['A', 'B']) {
      final ink = find.ancestor(
        of: find.text(l),
        matching: find.byType(InkWell),
      );
      expect(t.getSize(ink).height, greaterThanOrEqualTo(44));
    }
  });

  testWidgets('index ngoài khoảng và % ngoài khoảng được kẹp', (t) async {
    await t.pumpWidget(
      host(
        OmniSegmented(labels: const ['A', 'B'], index: 9, onChanged: (_) {}),
      ),
    );
    expect(t.takeException(), isNull);
    await t.pumpWidget(
      host(const OmniProgressRing(percent: 150, color: Colors.orange)),
    );
    expect(find.bySemanticsLabel('Tiến độ 100%'), findsOneWidget);
  });
}
