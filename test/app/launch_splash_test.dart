import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/app/shell/launch_splash.dart';
import 'package:omni_app/app/shell/splash_page.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/design/theme/omni_theme.dart';

/// Hiệu ứng mở app: chạy MỘT lần mỗi lần khởi động, không bao giờ chặn màn
/// bên dưới dựng lên, và biến mất hẳn khi máy bật "giảm chuyển động".
void main() {
  setUp(LaunchSplash.resetForTest);

  Widget host({bool reduceMotion = false}) {
    return MaterialApp(
      theme: OmniTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: LaunchSplash(child: child!),
      ),
      home: const Scaffold(body: Text('màn đích')),
    );
  }

  testWidgets('lần mở đầu: phủ hiệu ứng, màn đích vẫn dựng ngay bên dưới', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    expect(find.byType(OmniSplash), findsOneWidget);
    // Router không phải chờ: màn đích đã có trong cây từ khung đầu tiên.
    expect(find.text('màn đích'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.byType(OmniSplash), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(OmniSplash), findsNothing);
    expect(find.text('màn đích'), findsOneWidget);
  });

  testWidgets('hiệu ứng kết thúc trong khoảng 2 giây', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump(const Duration(milliseconds: 1999));
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.byType(OmniSplash), findsNothing);
  });

  testWidgets('lần dựng thứ hai trong cùng tiến trình thì vào thẳng', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    // Cây bị dựng lại từ đầu (đổi tenant, đổi theme…) — không chạy lại.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(host());

    expect(find.byType(OmniSplash), findsNothing);
    expect(find.text('màn đích'), findsOneWidget);
  });

  testWidgets('giảm chuyển động: không có hiệu ứng nào', (tester) async {
    await tester.pumpWidget(host(reduceMotion: true));

    expect(find.byType(OmniSplash), findsNothing);
    expect(find.text('màn đích'), findsOneWidget);
  });

  testWidgets('màn chờ khôi phục phiên vẽ đúng khung hình cuối', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: OmniTheme.light(), home: const SplashPage()),
    );

    expect(find.text(OmniSplash.tagline), findsOneWidget);
    expect(find.bySemanticsLabel('Logo Viomni'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}
