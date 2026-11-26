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

  Future<void> open(WidgetTester tester, {String? initialEmail}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    api = _FakeApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authOnboardingApiProvider.overrideWithValue(api)],
        child: MaterialApp(
          theme: OmniTheme.light(),
          home: ForgotPasswordPage(initialEmail: initialEmail),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('email sai định dạng báo "Email chưa hợp lệ", không gọi API', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Quên mật khẩu'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'khong-phai-email');
    await tester.tap(find.text('Gửi liên kết đặt lại'));
    await tester.pump();

    expect(find.text('Email chưa hợp lệ'), findsOneWidget);
    expect(api.sent, isEmpty);
  });

  testWidgets('điền sẵn email mang từ màn đăng nhập, bàn phím bật sẵn', (
    tester,
  ) async {
    await open(tester, initialEmail: 'lan@acme.vn');

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'lan@acme.vn');
    expect(field.autofocus, isTrue);

    await tester.tap(find.text('Gửi liên kết đặt lại'));
    await tester.pump();
    await tester.pump();
    expect(api.sent, ['lan@acme.vn']);
  });

  testWidgets('hợp lệ: gọi API, hiện "Kiểm tra email", đếm ngược 0:30', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'lan@acme.vn');
    await tester.tap(find.text('Gửi liên kết đặt lại'));
    await tester.pump();
    await tester.pump();

    expect(api.sent, ['lan@acme.vn']);
    expect(find.text('Kiểm tra email'), findsOneWidget);
    expect(
      find.text('Liên kết đặt lại đã gửi tới\nlan@acme.vn', findRichText: true),
      findsOneWidget,
    );
    // Một nút chính duy nhất; gửi lại và đổi email là nút chữ.
    expect(
      find.widgetWithText(FilledButton, 'Mở ứng dụng email'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, 'Dùng email khác'), findsOneWidget);
    expect(find.text('Gửi lại sau 0:30'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Gửi lại sau 0:29'), findsOneWidget);
    // Chuyển cảnh xong: chỉ còn một nút chính.
    expect(find.byType(FilledButton), findsOneWidget);

    await tester.pump(const Duration(seconds: 29));
    expect(find.text('Gửi lại email'), findsOneWidget);

    await tester.tap(find.text('Gửi lại email'));
    await tester.pump();
    await tester.pump();
    expect(api.sent, ['lan@acme.vn', 'lan@acme.vn']);
    expect(find.text('Gửi lại sau 0:30'), findsOneWidget);
  });

  testWidgets('Dùng email khác quay lại ô email', (tester) async {
    await open(tester, initialEmail: 'lan@acme.vn');
    await tester.tap(find.text('Gửi liên kết đặt lại'));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Dùng email khác'));
    await tester.pumpAndSettle();
    expect(find.text('Quên mật khẩu'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
