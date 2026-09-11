import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/design/tokens/tokens.dart';

/// `OmniBackdrop` vẽ đúng nền theo tên và theo chế độ sáng/tối, và KHÔNG vẽ
/// gì khi không có tên — màn giữ nguyên như trước khi có tính năng.
void main() {
  Widget host(String? name, {bool dark = false}) => MaterialApp(
    // Nhãn DEBUG của MaterialApp cũng là một CustomPaint — tắt để finder
    // chỉ thấy hoạ tiết của chính OmniBackdrop.
    debugShowCheckedModeBanner: false,
    theme: OmniTheme.light(TargetPlatform.android),
    darkTheme: OmniTheme.dark(TargetPlatform.android),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    home: OmniBackdrop(name: name, child: const Text('nội dung')),
  );

  Finder gradientBox() => find.byWidgetPredicate(
    (w) =>
        w is DecoratedBox && (w.decoration as BoxDecoration?)?.gradient != null,
  );

  testWidgets('null thì trả thẳng con, không vẽ gì', (tester) async {
    await tester.pumpWidget(host(null));

    expect(find.text('nội dung'), findsOneWidget);
    expect(gradientBox(), findsNothing);
    expect(find.byType(CustomPaint), findsNothing);
  });

  testWidgets('tên lạ cũng như null', (tester) async {
    await tester.pumpWidget(host('go-oc-cho'));

    expect(gradientBox(), findsNothing);
  });

  testWidgets('có tên thì gradient đúng chế độ + hoạ tiết', (tester) async {
    await tester.pumpWidget(host('walnut'));
    final box = tester.widget<DecoratedBox>(gradientBox());
    final g = (box.decoration as BoxDecoration).gradient! as LinearGradient;
    expect(
      g.colors.first,
      OmniBackdrops.specOf('walnut', Brightness.light)!.top,
    );
    expect(find.byType(CustomPaint), findsOneWidget);

    await tester.pumpWidget(host('walnut', dark: true));
    // MaterialApp chuyển theme có hiệu ứng; khung đầu vẫn là màu sáng.
    await tester.pumpAndSettle();
    final dark = tester.widget<DecoratedBox>(gradientBox());
    final gd = (dark.decoration as BoxDecoration).gradient! as LinearGradient;
    expect(
      gd.colors.first,
      OmniBackdrops.specOf('walnut', Brightness.dark)!.top,
    );
  });

  testWidgets('nền không hoạ tiết thì không có CustomPaint', (tester) async {
    await tester.pumpWidget(host('dawn'));

    expect(gradientBox(), findsOneWidget);
    expect(find.byType(CustomPaint), findsNothing);
  });
}
