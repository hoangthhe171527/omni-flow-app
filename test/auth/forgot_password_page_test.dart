import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/auth/data/auth_onboarding_api.dart';
import 'package:omni_app/modules/auth/presentation/forgot_password_page.dart';

class _FakeApi implements AuthOnboardingApi {
  final sent = <String>[];

  @override
  Future<void> forgotPassword(String email) async => sent.add(email);

  @override
  Future<void> register({
    required String fullName,
    required String email,
    required String companyName,
    required String password,
  }) async {}
}

void main() {
  late _FakeApi api;

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    api = _FakeApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authOnboardingApiProvider.overrideWithValue(api)],
        child: MaterialApp(
          theme: OmniTheme.light(),
          home: const ForgotPasswordPage(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('email sai định dạng báo "Email chưa hợp lệ", không gọi API', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Quên mật khẩu?'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'khong-phai-email');
    await tester.tap(find.text('Gửi liên kết'));
    await tester.pump();

    expect(find.text('Email chưa hợp lệ'), findsOneWidget);
    expect(api.sent, isEmpty);
  });

  testWidgets('hợp lệ: gọi API, hiện "Kiểm tra email", đếm ngược 30 giây', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'lan@acme.vn');
    await tester.tap(find.text('Gửi liên kết'));
    await tester.pump();
    await tester.pump();

    expect(api.sent, ['lan@acme.vn']);
    expect(find.text('Kiểm tra email'), findsOneWidget);
    expect(find.text('Đã gửi tới lan@acme.vn'), findsOneWidget);
    expect(find.text('Mở ứng dụng email'), findsOneWidget);
    expect(find.text('Gửi lại sau 30 giây'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Gửi lại sau 29 giây'), findsOneWidget);

    await tester.pump(const Duration(seconds: 29));
    expect(find.text('Gửi lại email'), findsOneWidget);

    await tester.tap(find.text('Gửi lại email'));
    await tester.pump();
    await tester.pump();
    expect(api.sent, ['lan@acme.vn', 'lan@acme.vn']);
    expect(find.text('Gửi lại sau 30 giây'), findsOneWidget);
  });
}
