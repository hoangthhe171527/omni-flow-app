import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/app/omni_app.dart';
import 'package:omni_app/app/router/app_router.dart';
import 'package:omni_app/app/shell/app_shell.dart';
import 'package:omni_app/bootstrap.dart';
import 'package:omni_app/design/components/omni_states.dart';
import 'package:omni_app/modules/auth/presentation/login_page.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bản demo (kiểm thử khép kín): mở app là vào thẳng workspace mẫu, không qua
/// màn đăng nhập, và mọi màn chính tải được dữ liệu từ máy chủ trong RAM.
///
/// Chạy kèm ảnh chụp từng màn (để nhìn bằng mắt):
///   flutter test test/demo/demo_app_test.dart --dart-define=DEMO_SHOTS=true --update-goldens
const _shots = bool.fromEnvironment('DEMO_SHOTS');

const _screens = <String, String>{
  'trang-chu': '/home',
  'hop-thu': '/inbox',
  'viec': '/tasks',
  'khach-hang': '/customers',
  'co-hoi': '/opportunities',
  'tien-do': '/timeline',
  'doi-nhom': '/teams',
  'nhan-vien': '/team',
  'kenh': '/channels',
  'thong-bao': '/notifications',
  'them': '/more',
};

Future<void> _loadFonts() async {
  final loader = FontLoader('Be Vietnam Pro');
  for (final f in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    final bytes = File('assets/fonts/BeVietnamPro-$f.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
  final icons = File(
    'D:/_tools/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
  );
  if (icons.existsSync()) {
    final iconLoader = FontLoader('MaterialIcons');
    iconLoader.addFont(
      Future.value(ByteData.view(icons.readAsBytesSync().buffer)),
    );
    await iconLoader.load();
  }
}

/// Đợi các lượt "mạng" giả (180 ms mỗi lượt) và hoạt ảnh — không dùng
/// pumpAndSettle vì app có bộ đếm giờ chạy mãi (làm mới định kỳ).
Future<void> _settle(WidgetTester tester, {int steps = 25}) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  setUpAll(() async {
    // Phông thật cả khi không chụp: phông Ahem mặc định của test rộng hơn,
    // làm tràn hàng giả (RenderFlex overflow) ở những chỗ phông thật vừa khít.
    await _loadFonts();
    await initializeDateFormatting('vi_VN');
  });

  testWidgets('bản demo vào thẳng app và mọi màn chính tải được dữ liệu', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final overrides = await appOverrides(prefs, demo: true);

    await tester.pumpWidget(
      ProviderScope(overrides: overrides, child: const OmniApp()),
    );
    await _settle(tester, steps: 40);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(OmniApp)),
    );
    expect(
      container.read(sessionProvider).status,
      SessionStatus.authenticated,
      reason: 'phiên demo phải tự đăng nhập',
    );
    expect(find.byType(LoginPage), findsNothing);
    expect(find.byType(AppShell), findsOneWidget);

    final router = container.read(routerProvider);
    for (final entry in _screens.entries) {
      router.go(entry.value);
      await _settle(tester);

      expect(tester.takeException(), isNull, reason: entry.key);
      expect(
        find.byType(OmniErrorView),
        findsNothing,
        reason: '${entry.key} (${entry.value}) hiện lỗi tải dữ liệu',
      );
      expect(find.byType(LoginPage), findsNothing, reason: entry.key);
      if (_shots) {
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/demo-${entry.key}.png'),
        );
      }
    }
    // Chỉ để biết router còn sống sau vòng duyệt.
    expect(router, isA<GoRouter>());
  });
}
