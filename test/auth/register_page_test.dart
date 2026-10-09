import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/auth/application/password_strength.dart';
import 'package:omni_app/modules/auth/data/auth_onboarding_api.dart';
import 'package:omni_app/modules/auth/presentation/register_page.dart';
import 'package:omni_app/security/session/session_controller.dart';

class _FakeApi implements AuthOnboardingApi {
  Map<String, String>? registered;
  Object? failWith;

  @override
  Future<void> register({
    required String fullName,
    required String email,
    required String companyName,
    required String password,
  }) async {
    registered = {
      'fullName': fullName,
      'email': email,
      'companyName': companyName,
      'password': password,
    };
    if (failWith != null) throw failWith!;
  }

  @override
  Future<void> forgotPassword(String email) async {}
}

class _FakeSession extends SessionController {
  String? signedInAs;

  @override
  Future<void> login({required String email, required String password}) async {
    signedInAs = email;
  }
}

void main() {
  late _FakeApi api;
  late _FakeSession session;

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    api = _FakeApi();
    session = _FakeSession();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authOnboardingApiProvider.overrideWithValue(api),
          sessionControllerProvider.overrideWith(() => session),
        ],
        child: MaterialApp(
          theme: OmniTheme.light(),
          home: const RegisterPage(),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> fill(WidgetTester tester, {String password = 'Abcdef1!'}) async {
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Lan Anh');
    await tester.enterText(fields.at(1), 'lan@acme.vn');
    await tester.enterText(fields.at(2), 'Acme');
    await tester.enterText(fields.at(3), password);
    await tester.pump();
  }

  Future<void> tick(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const ValueKey('terms-checkbox')));
    await tester.tap(find.byKey(const ValueKey('terms-checkbox')));
    await tester.pump();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const ValueKey('register-submit')));
    await tester.tap(find.byKey(const ValueKey('register-submit')));
    await tester.pump();
    await tester.pump();
  }

  double submitOpacity(WidgetTester tester) => tester
      .widget<AnimatedOpacity>(find.byKey(const ValueKey('register-opacity')))
      .opacity;

  testWidgets('nút mờ .45 khi thiếu; đủ + tích thì rõ', (tester) async {
    await open(tester);
    expect(submitOpacity(tester), 0.45);

    await fill(tester);
    expect(submitOpacity(tester), 0.45, reason: 'chưa tích điều khoản');

    await tick(tester);
    expect(submitOpacity(tester), 1);
  });

  testWidgets('điền đủ + tích gọi API đúng tham số rồi đăng nhập', (
    tester,
  ) async {
    await open(tester);
    await fill(tester);
    await tick(tester);
    await submit(tester);

    expect(api.registered, {
      'fullName': 'Lan Anh',
      'email': 'lan@acme.vn',
      'companyName': 'Acme',
      'password': 'Abcdef1!',
    });
    expect(session.signedInAs, 'lan@acme.vn');
  });

  testWidgets('422 email hiện chữ lỗi dưới ô email, không đổ app', (
    tester,
  ) async {
    await open(tester);
    await fill(tester);
    await tick(tester);
    api.failWith = const ValidationException(
      'Dữ liệu chưa hợp lệ.',
      errors: {
        'email': ['Email đã được dùng.'],
        'password': ['Mật khẩu quá yếu.'],
      },
    );
    await submit(tester);

    expect(find.text('Email đã được dùng.'), findsOneWidget);
    expect(find.text('Mật khẩu quá yếu.'), findsOneWidget);
    expect(session.signedInAs, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('422 chỉ có message hiện trong hộp lỗi', (tester) async {
    await open(tester);
    await fill(tester);
    await tick(tester);
    api.failWith = const ValidationException('Không thể tạo workspace.');
    await submit(tester);

    expect(find.text('Không thể tạo workspace.'), findsOneWidget);
  });

  testWidgets('thanh độ mạnh đổi nhãn theo mật khẩu', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField).at(3), 'abcdefgh');
    await tester.pump();
    expect(find.text('Yếu'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(3), 'Abcdef1!');
    await tester.pump();
    expect(find.text('Mạnh'), findsOneWidget);
  });

  test('điểm mật khẩu: 8 ký tự, hoa+thường, số, ký tự đặc biệt', () {
    expect(passwordScore(''), 0);
    expect(passwordScore('abc'), 0);
    expect(passwordScore('abcdefgh'), 1);
    expect(passwordScore('Abcdefgh'), 2);
    expect(passwordScore('Abcdefg1'), 3);
    expect(passwordScore('Abcdef1!'), 4);
    expect(passwordLabel(0), 'Yếu');
    expect(passwordLabel(1), 'Yếu');
    expect(passwordLabel(2), 'Tạm');
    expect(passwordLabel(3), 'Khá');
    expect(passwordLabel(4), 'Mạnh');
  });
}
