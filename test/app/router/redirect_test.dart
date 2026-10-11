import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/app/router/app_router.dart';
import 'package:omni_app/core/module/module_registry.dart';
import 'package:omni_app/modules/auth/auth_module.dart';
import 'package:omni_app/modules/auth/presentation/forgot_password_page.dart';
import 'package:omni_app/modules/auth/presentation/register_page.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

/// Đăng ký và quên mật khẩu là trạm dừng của người CHƯA có tài khoản: redirect
/// không được đẩy họ về /login, và cũng không được nhớ chúng làm đích sau khi
/// đăng nhập.
void main() {
  Future<String> open(
    WidgetTester tester,
    SessionStatus status,
    String path,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        modulesProvider.overrideWithValue(const [AuthModule()]),
        sessionProvider.overrideWith((ref) => Session(status: status)),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(routerProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    router.go(path);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    return router.routerDelegate.currentConfiguration.uri.path;
  }

  testWidgets('chưa đăng nhập mở /register thì ở lại /register', (
    tester,
  ) async {
    final at = await open(tester, SessionStatus.unauthenticated, '/register');
    expect(at, '/register');
    expect(find.byType(RegisterPage), findsOneWidget);
  });

  testWidgets('chưa đăng nhập mở /forgot-password thì ở lại đó', (
    tester,
  ) async {
    final at = await open(
      tester,
      SessionStatus.unauthenticated,
      '/forgot-password',
    );
    expect(at, '/forgot-password');
    expect(find.byType(ForgotPasswordPage), findsOneWidget);
  });

  testWidgets('phiên hết hạn vẫn vào được /register', (tester) async {
    final at = await open(tester, SessionStatus.expired, '/register');
    expect(at, '/register');
  });
}
