import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/auth/application/password_strength.dart';
import 'package:omni_app/modules/auth/application/login_controller.dart';
import 'package:omni_app/modules/auth/data/auth_onboarding_api.dart';
import 'package:omni_app/modules/auth/presentation/register_page.dart';
import 'package:omni_app/modules/auth/presentation/widgets/auth_widgets.dart';
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

/// Lỗi Google còn sót từ màn đăng nhập: chỉ lần dựng đầu có lỗi.
class _StaleGoogleError extends LoginController {
  static bool seeded = false;

  @override
  LoginState build() {
    if (seeded) return const LoginState();
    seeded = true;
    return const LoginState(error: 'Không thể đăng nhập bằng Google.');
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

  Future<void> submit(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const ValueKey('register-submit')));
    await tester.tap(find.byKey(const ValueKey('register-submit')));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('lỗi Google còn sót từ màn đăng nhập không hiện ở màn đăng ký', (
    tester,
  ) async {
    _StaleGoogleError.seeded = false;
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        authOnboardingApiProvider.overrideWithValue(_FakeApi()),
        sessionControllerProvider.overrideWith(_FakeSession.new),
        loginControllerProvider.overrideWith(_StaleGoogleError.new),
      ],
    );
    addTearDown(container.dispose);
    expect(
      container.read(loginControllerProvider).error,
      'Không thể đăng nhập bằng Google.',
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: OmniTheme.light(),
          home: const RegisterPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Không thể đăng nhập bằng Google.'), findsNothing);
    expect(find.text('Chính sách bảo mật'), findsOneWidget);
  });

  testWidgets('nút luôn bấm được; thiếu gì báo ngay dưới ô đó, không gọi API', (
    tester,
  ) async {
    await open(tester);
    final button = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const ValueKey('register-submit')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNotNull);

    await submit(tester);

    expect(find.text('Vui lòng nhập họ tên'), findsOneWidget);
    expect(find.text('Vui lòng nhập email'), findsOneWidget);
    expect(find.text('Vui lòng nhập tên công ty'), findsOneWidget);
    expect(find.text('Mật khẩu cần ít nhất 8 ký tự'), findsOneWidget);
    expect(api.registered, isNull);
  });

  testWidgets('không còn ô tích; dòng pháp lý dưới nút', (tester) async {
    await open(tester);

    expect(find.byKey(const ValueKey('terms-checkbox')), findsNothing);
    expect(find.text('Tạo tài khoản là đồng ý '), findsOneWidget);
    expect(find.text('Chính sách bảo mật'), findsOneWidget);
    final button = tester.getBottomLeft(
      find.byKey(const ValueKey('register-submit')),
    );
    expect(
      tester.getTopLeft(find.text('Chính sách bảo mật')).dy,
      greaterThan(button.dy),
    );
  });

  testWidgets(
    'ô gộp theo nhóm BẠN · CÔNG TY · BẢO MẬT; Google dưới nút chính',
    (tester) async {
      await open(tester);

      expect(find.text('BẠN'), findsOneWidget);
      expect(find.text('CÔNG TY'), findsOneWidget);
      expect(find.text('BẢO MẬT'), findsOneWidget);
      expect(find.byType(AuthFieldGroup), findsNWidgets(3));
      // Họ tên + email chung một nhóm.
      expect(
        find.descendant(
          of: find.byType(AuthFieldGroup).first,
          matching: find.byType(TextField),
        ),
        findsNWidgets(2),
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('google-sign-in'))).dy,
        greaterThan(
          tester
              .getBottomLeft(find.byKey(const ValueKey('register-submit')))
              .dy,
        ),
      );
      // Quỹ đạo nhỏ trang trí góc trên phải, không chặn chạm.
      final orbit = tester.getCenter(find.byType(OmniOrbit));
      expect(orbit.dx, greaterThan(390 / 2));
      expect(orbit.dy, lessThan(120));
    },
  );

  testWidgets('điền đủ gọi API đúng tham số rồi đăng nhập', (tester) async {
    await open(tester);
    await fill(tester);
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
    api.failWith = const ValidationException('Không thể tạo workspace.');
    await submit(tester);

    expect(find.text('Không thể tạo workspace.'), findsOneWidget);
  });

  testWidgets('thanh độ mạnh: số vạch sáng theo mật khẩu, nhãn đọc màn hình', (
    tester,
  ) async {
    await open(tester);
    Color? bar(int i) =>
        ((tester
                    .widget<AnimatedContainer>(
                      find.byKey(ValueKey('strength-bar-$i')),
                    )
                    .decoration
                as BoxDecoration?)
            ?.color);

    await tester.enterText(find.byType(TextField).at(3), 'abcdefgh');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.bySemanticsLabel('Độ mạnh mật khẩu: Yếu'), findsOneWidget);
    final weak = bar(0);
    expect(bar(1), isNot(weak));

    await tester.enterText(find.byType(TextField).at(3), 'Abcdef1!');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.bySemanticsLabel('Độ mạnh mật khẩu: Mạnh'), findsOneWidget);
    // Bốn vạch cùng một màu (xanh lá), khác màu của mức Yếu.
    expect(bar(3), bar(0));
    expect(bar(0), isNot(weak));
  });

  testWidgets('đã gõ rồi bấm ‹ → hỏi trước khi bỏ, "Tiếp tục" ở lại', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(find.byType(TextField).first, 'Nguyễn An');
    await tester.pump();
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Bỏ thông tin đã nhập?'), findsOneWidget);
    await tester.tap(find.text('Tiếp tục'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Bỏ thông tin đã nhập?'), findsNothing);
    expect(find.text('Nguyễn An'), findsOneWidget);
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
