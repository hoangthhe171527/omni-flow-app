import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
    expect(find.text('Quên mật khẩu?'), findsOneWidget);
    expect(
      find.text('Nhập email, Viomni gửi liên kết đặt lại.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), 'khong-phai-email');
    await tester.tap(find.text('Gửi liên kết'));
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

    await tester.tap(find.text('Gửi liên kết'));
    await tester.pump();
    await tester.pump();
    expect(api.sent, ['lan@acme.vn']);
  });

  testWidgets('hợp lệ: gọi API, "Đã gửi liên kết", 3 bước, đếm ngược 30 giây', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'lan@acme.vn');
    await tester.tap(find.text('Gửi liên kết'));
    await tester.pump();
    await tester.pump();

    expect(api.sent, ['lan@acme.vn']);
    expect(find.text('Đã gửi liên kết'), findsOneWidget);
    expect(
      find.text('Kiểm tra hộp thư lan@acme.vn', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Mở email từ Viomni'), findsOneWidget);
    expect(find.text('Bấm "Đặt lại mật khẩu"'), findsOneWidget);
    expect(find.text('Đăng nhập bằng mật khẩu mới'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Dùng email khác'), findsOneWidget);
    // Nút chính là "Gửi lại", khoá trong lúc đếm ngược.
    final resend = find.widgetWithText(FilledButton, 'Gửi lại sau 30 giây');
    expect(resend, findsOneWidget);
    expect(tester.widget<FilledButton>(resend).onPressed, isNull);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Gửi lại sau 29 giây'), findsOneWidget);
    // Chuyển cảnh xong: chỉ còn một nút chính.
    expect(find.byType(FilledButton), findsOneWidget);

    await tester.pump(const Duration(seconds: 29));
    expect(find.widgetWithText(FilledButton, 'Gửi lại'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Gửi lại'));
    await tester.pump();
    await tester.pump();
    expect(api.sent, ['lan@acme.vn', 'lan@acme.vn']);
    expect(find.text('Gửi lại sau 30 giây'), findsOneWidget);
  });

  testWidgets(
    'gửi xong: ô hình chuyển xanh lá; giảm chuyển động thì đứng yên',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      api = _FakeApi();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authOnboardingApiProvider.overrideWithValue(api)],
          child: MaterialApp(
            theme: OmniTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: const ForgotPasswordPage(initialEmail: 'lan@acme.vn'),
          ),
        ),
      );
      // Chờ con trỏ cuộn vào chỗ (ô email tự focus) rồi mới xét.
      await tester.pump(const Duration(milliseconds: 500));
      // Con trỏ nhấp nháy của ô đang focus cũng là một ticker: bỏ focus rồi
      // mới xét.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      // Màn tĩnh: không sóng, không vệt sáng chạy.
      expect(tester.hasRunningAnimations, isFalse);

      await tester.tap(find.text('Gửi liên kết'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Đã gửi liên kết'), findsOneWidget);
      // Đổi trạng thái tức thì: dấu ✓ đã hiện đủ, phong bì đã đi.
      final check = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.byIcon(LucideIcons.check),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(check.opacity, 1);
    },
  );

  testWidgets('chân màn "Nhớ ra rồi? Đăng nhập"', (tester) async {
    await open(tester);
    expect(find.text('Nhớ ra rồi? '), findsOneWidget);
    expect(find.text('Đăng nhập'), findsOneWidget);
  });

  testWidgets('Dùng email khác quay lại ô email', (tester) async {
    await open(tester, initialEmail: 'lan@acme.vn');
    await tester.tap(find.text('Gửi liên kết'));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Dùng email khác'));
    // Ô hình có sóng lặp mãi: bơm khoảng cố định thay vì settle.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Quên mật khẩu?'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
