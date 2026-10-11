import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  testWidgets('hiệu ứng kết thúc trong khoảng 2,5 giây', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump(const Duration(milliseconds: 2499));
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

  testWidgets('giảm chuyển động: không có lớp phủ', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(home: LaunchSplash(child: const Text('app'))),
      ),
    );
    expect(find.byType(OmniSplash), findsNothing);
    expect(find.text('app'), findsOneWidget);
  });

  testWidgets(
    'có BrandAnchor: logo kết thúc đúng vị trí đích rồi lớp phủ biến mất',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: LaunchSplash(
              child: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: BrandAnchor(child: SizedBox.square(dimension: 30)),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 2440));
      final logo = tester.getRect(find.byKey(const ValueKey('splash-logo')));
      final anchor = tester.getRect(find.byType(BrandAnchor));
      expect((logo.center - anchor.center).distance, lessThan(1.5));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(OmniSplash), findsNothing);
    },
  );

  testWidgets('không có BrandAnchor: mờ dần như cũ, không lỗi', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: LaunchSplash(child: const Text('đích'))),
      ),
    );
    await tester.pump(const Duration(milliseconds: 2600));
    expect(find.byType(OmniSplash), findsNothing);
    expect(find.text('đích'), findsOneWidget);
  });

  testWidgets('hai neo trong IndexedStack: logo đáp xuống neo đang hiện', (
    tester,
  ) async {
    // Tab 0 hiện (neo góc trên trái); tab 1 ẩn nhưng dựng SAU — nếu "dựng sau
    // thắng" thì logo bay nhầm về góc dưới phải.
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: LaunchSplash(
            child: Scaffold(
              body: IndexedStack(
                index: 0,
                children: const [
                  Align(
                    alignment: Alignment.topLeft,
                    child: BrandAnchor(
                      key: ValueKey('visible'),
                      child: SizedBox.square(dimension: 30),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: BrandAnchor(
                      key: ValueKey('hidden'),
                      child: SizedBox.square(dimension: 30),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 2440));
    final logo = tester.getRect(find.byKey(const ValueKey('splash-logo')));
    final anchor = tester.getRect(find.byKey(const ValueKey('visible')));
    expect((logo.center - anchor.center).distance, lessThan(1.5));
  });

  testWidgets('neo dạng header (logo + chữ): logo đáp vào ô vuông bên trái', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: LaunchSplash(
            child: const Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: BrandAnchor(
                  withWordmark: true,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox.square(
                        key: ValueKey('header-logo'),
                        dimension: 30,
                      ),
                      SizedBox(width: 8),
                      OmniWordmark(fontSize: 19),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 2440));
    final logo = tester.getRect(find.byKey(const ValueKey('splash-logo')));
    final target = tester.getRect(find.byKey(const ValueKey('header-logo')));
    expect((logo.center - target.center).distance, lessThan(1.5));
    expect(logo.width, closeTo(30, 1));
  });

  /// Màn đích đổi theo [where]: null = chưa có neo; khác null = neo ở đó.
  Widget movable(ValueNotifier<Alignment?> where) {
    return ProviderScope(
      child: MaterialApp(
        home: LaunchSplash(
          child: Scaffold(
            body: ValueListenableBuilder<Alignment?>(
              valueListenable: where,
              builder: (context, a, _) => a == null
                  ? const SizedBox.expand()
                  : Align(
                      alignment: a,
                      child: const BrandAnchor(
                        child: SizedBox.square(dimension: 30),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> pumpTo(WidgetTester tester, int fromMs, int toMs) async {
    for (var ms = fromMs; ms < toMs; ms += 20) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  testWidgets('neo dựng muộn (1900ms) vẫn được bay tới', (tester) async {
    final where = ValueNotifier<Alignment?>(null);
    await tester.pumpWidget(movable(where));
    await tester.pump(const Duration(milliseconds: 1900));
    where.value = Alignment.topLeft;
    await pumpTo(tester, 1900, 2440);
    final logo = tester.getRect(find.byKey(const ValueKey('splash-logo')));
    final anchor = tester.getRect(find.byType(BrandAnchor));
    expect((logo.center - anchor.center).distance, lessThan(1.5));
  });

  testWidgets('neo dời chỗ giữa lúc bay: khung cuối ở chỗ mới', (tester) async {
    final where = ValueNotifier<Alignment?>(Alignment.topLeft);
    await tester.pumpWidget(movable(where));
    await tester.pump(const Duration(milliseconds: 2000));
    where.value = Alignment.bottomRight;
    await pumpTo(tester, 2000, 2440);
    final logo = tester.getRect(find.byKey(const ValueKey('splash-logo')));
    final anchor = tester.getRect(find.byType(BrandAnchor));
    expect((logo.center - anchor.center).distance, lessThan(1.5));
  });

  testWidgets('neo biến mất giữa lúc bay: chuyển sang mờ dần, không lỗi', (
    tester,
  ) async {
    final where = ValueNotifier<Alignment?>(Alignment.topLeft);
    await tester.pumpWidget(movable(where));
    await tester.pump(const Duration(milliseconds: 2000));
    where.value = null;
    await pumpTo(tester, 2000, 2200);
    expect(
      find.ancestor(
        of: find.byType(OmniSplash),
        matching: find.byType(Opacity),
      ),
      findsWidgets,
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(OmniSplash), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('neo có chữ: chữ "Viomni" của splash bay vào sau logo', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: LaunchSplash(
            child: const Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: BrandAnchor(
                  withWordmark: true,
                  child: SizedBox(width: 110, height: 30),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 2440));
    final v = tester.getRect(
      find.descendant(of: find.byType(OmniSplash), matching: find.text('V')),
    );
    expect(v.left, closeTo(38, 2));
    expect(v.center.dy, closeTo(15, 3));
  });
}
