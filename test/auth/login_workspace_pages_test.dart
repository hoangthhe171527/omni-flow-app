import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/design/tokens/tokens.dart';
import 'package:omni_app/modules/auth/application/login_controller.dart';
import 'package:omni_app/modules/auth/auth_module.dart';
import 'package:omni_app/modules/auth/presentation/login_page.dart';
import 'package:omni_app/modules/auth/presentation/workspace_page.dart';
import 'package:omni_app/security/session/auth_gateway.dart';

class _FailedLogin extends LoginController {
  @override
  LoginState build() => const LoginState(
    error: 'Email hoặc mật khẩu không đúng.',
    wrongCredentials: true,
  );
}

class _OfflineLogin extends LoginController {
  @override
  LoginState build() => const LoginState(error: 'Không có kết nối mạng.');
}

class _RecordingGoogleLogin extends LoginController {
  bool called = false;

  @override
  LoginState build() => const LoginState();

  @override
  Future<bool> submitWithGoogle() async {
    called = true;
    return true;
  }
}

class _SlowLogin extends LoginController {
  int submits = 0;
  final finish = Completer<void>();

  @override
  LoginState build() => const LoginState();

  @override
  Future<bool> submit({required String email, required String password}) async {
    submits++;
    state = const LoginState(submittingMethod: LoginMethod.password);
    await finish.future;
    state = const LoginState();
    return true;
  }
}

void main() {
  Future<void> pump(WidgetTester tester, Widget page, List<Override> o) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: o,
        child: MaterialApp(theme: OmniTheme.light(), home: page),
      ),
    );
    await tester.pump();
  }

  group('đăng nhập', () {
    testWidgets('logo trần neo cho màn mở app, tiêu đề, hai ô và nút', (
      tester,
    ) async {
      await pump(tester, const LoginPage(), const []);

      final mark = tester.widget<OmniBrandMark>(find.byType(OmniBrandMark));
      expect(mark.size, 56);
      // Logo trong app không đóng khung — khung chỉ dành cho icon app.
      expect(mark.framed, isFalse);
      final anchor = tester.widget<BrandAnchor>(find.byType(BrandAnchor));
      expect(anchor.withWordmark, isFalse);
      expect(find.text('Đăng nhập Viomni'), findsOneWidget);
      expect(find.text('Chào mừng trở lại'), findsNothing);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Mật khẩu'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Đăng nhập'), findsOneWidget);
      expect(find.text('Tiếp tục với Google'), findsOneWidget);
      expect(find.text('hoặc'), findsOneWidget);
      expect(find.text('Quên mật khẩu?'), findsOneWidget);
      expect(find.text('Đăng ký'), findsOneWidget);
      expect(find.text('Chính sách bảo mật'), findsOneWidget);
      expect(find.text('Quyền riêng tư'), findsNothing);
      expect(find.text('Hỗ trợ'), findsNothing);
      expect(find.textContaining('xử lý công việc'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Google lên đầu, trên ô email và nút Đăng nhập', (
      tester,
    ) async {
      await pump(tester, const LoginPage(), const []);

      final login = find.widgetWithText(FilledButton, 'Đăng nhập');
      final google = find.byKey(const ValueKey('google-sign-in'));
      final email = find.byType(TextField).first;
      expect(
        tester.getTopLeft(google).dy,
        lessThan(tester.getTopLeft(email).dy),
      );
      expect(
        tester.getTopLeft(email).dy,
        lessThan(tester.getTopLeft(login).dy),
      );
    });

    testWidgets('bàn phím bật thì thu logo, giữ tiêu đề', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: OmniTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(viewInsets: const EdgeInsets.only(bottom: 336)),
              child: child!,
            ),
            home: const LoginPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OmniBrandMark), findsNothing);
      expect(find.text('Đăng nhập Viomni'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Đang gõ email: nút Đăng nhập nằm trọn trên bàn phím.
      await tester.tap(find.byType(TextField).first);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      final button = tester.getRect(
        find.widgetWithText(FilledButton, 'Đăng nhập'),
      );
      expect(button.bottom, lessThanOrEqualTo(844 - 336));
      expect(
        tester.getRect(find.byType(TextField).first).top,
        greaterThanOrEqualTo(0),
      );
    });

    testWidgets('Đăng ký và Chính sách bảo mật nằm ở chân màn', (tester) async {
      await pump(tester, const LoginPage(), const []);

      final login = tester.getBottomLeft(
        find.widgetWithText(FilledButton, 'Đăng nhập'),
      );
      final register = tester.getTopLeft(find.text('Đăng ký'));
      // Chân màn: cách nút chính một khoảng, nằm ở phần tư dưới màn 844.
      expect(register.dy - login.dy, greaterThan(40));
      expect(register.dy, greaterThan(844 * 0.75));
      expect(tester.takeException(), isNull);
    });

    testWidgets('để trống rồi bấm Đăng nhập hiện lỗi dưới ô', (tester) async {
      await pump(tester, const LoginPage(), const []);

      await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
      await tester.pump();

      expect(find.text('Vui lòng nhập email'), findsOneWidget);
      expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    Future<double> shakeDx(WidgetTester tester, {required bool reduced}) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: OmniTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: child!,
            ),
            home: const LoginPage(),
          ),
        ),
      );
      final before = tester.getTopLeft(find.byType(TextField).first).dx;
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final after = tester.getTopLeft(find.byType(TextField).first).dx;
      await tester.pumpAndSettle();
      return after - before;
    }

    testWidgets('lỗi làm ô rung khi chuyển động bật', (tester) async {
      expect(await shakeDx(tester, reduced: false), isNot(0));
    });

    testWidgets('tắt chuyển động thì lỗi không rung', (tester) async {
      expect(await shakeDx(tester, reduced: true), 0);
    });

    testWidgets('Quên mật khẩu và Đăng ký điều hướng theo tên route', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const LoginPage()),
          GoRoute(
            path: '/register',
            name: AuthModule.register,
            builder: (_, _) => const Text('trang-dang-ky'),
          ),
          GoRoute(
            path: '/forgot-password',
            name: AuthModule.forgot,
            builder: (_, state) => Text('trang-quen:${state.extra}'),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: OmniTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Đăng ký'));
      await tester.pumpAndSettle();
      expect(find.text('trang-dang-ky'), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quên mật khẩu?'));
      await tester.pumpAndSettle();
      expect(find.text('trang-quen:null'), findsOneWidget);

      // Đã gõ email thì mang sang, khỏi gõ lại.
      router.pop();
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, ' lan@acme.vn ');
      await tester.tap(find.text('Quên mật khẩu?'));
      await tester.pumpAndSettle();
      expect(find.text('trang-quen:lan@acme.vn'), findsOneWidget);
    });

    testWidgets('ô giữ tên truy cập được khi đã có chữ', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, const LoginPage(), const []);

      await tester.enterText(find.byType(TextField).first, 'a@b.vn');
      await tester.enterText(find.byType(TextField).last, 'matkhau');
      await tester.pump();

      expect(find.bySemanticsLabel('Email'), findsWidgets);
      expect(
        tester.getSemantics(find.byType(TextField).first).label,
        contains('Email'),
      );
      expect(find.bySemanticsLabel('Mật khẩu'), findsWidgets);
      expect(
        tester.getSemantics(find.byType(TextField).last).label,
        contains('Mật khẩu'),
      );
      handle.dispose();
    });

    testWidgets('hai ô khai báo gợi ý tự điền trong một nhóm', (tester) async {
      await pump(tester, const LoginPage(), const []);

      expect(find.byType(AutofillGroup), findsOneWidget);
      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(fields.first.autofillHints, contains(AutofillHints.username));
      expect(fields.first.autofillHints, contains(AutofillHints.email));
      expect(fields.last.autofillHints, contains(AutofillHints.password));
    });

    testWidgets('bấm Xong trên bàn phím khi đang gửi không gửi lần hai', (
      tester,
    ) async {
      final controller = _SlowLogin();
      await pump(tester, const LoginPage(), [
        loginControllerProvider.overrideWith(() => controller),
      ]);
      await tester.enterText(find.byType(TextField).first, 'a@b.vn');
      await tester.enterText(find.byType(TextField).last, 'matkhau');

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(controller.submits, 1);
      controller.finish.complete();
      await tester.pump();
    });

    testWidgets('nút Google gọi đúng luồng đăng nhập riêng', (tester) async {
      final controller = _RecordingGoogleLogin();
      await pump(tester, const LoginPage(), [
        loginControllerProvider.overrideWith(() => controller),
      ]);

      await tester.tap(find.byKey(const ValueKey('google-sign-in')));
      await tester.pump();

      expect(controller.called, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('lỗi đăng nhập hiện trong hộp đỏ nhạt', (tester) async {
      await pump(tester, const LoginPage(), [
        loginControllerProvider.overrideWith(_FailedLogin.new),
      ]);

      final box = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('Email hoặc mật khẩu không đúng.'),
              matching: find.byType(Container),
            )
            .first,
      );
      expect((box.decoration! as BoxDecoration).color, OmniColors.dangerSoft);
      // Lỗi chỉ hiện một chỗ, kèm lối sửa.
      expect(find.text('Email hoặc mật khẩu không đúng.'), findsOneWidget);
      expect(find.text('Đặt lại mật khẩu'), findsOneWidget);
    });

    testWidgets('lỗi mạng không mời đặt lại mật khẩu', (tester) async {
      await pump(tester, const LoginPage(), [
        loginControllerProvider.overrideWith(_OfflineLogin.new),
      ]);

      expect(find.text('Không có kết nối mạng.'), findsOneWidget);
      expect(find.text('Đặt lại mật khẩu'), findsNothing);
    });

    testWidgets('nút mắt nói cả trạng thái mật khẩu', (tester) async {
      await pump(tester, const LoginPage(), const []);

      expect(find.byTooltip('Hiện mật khẩu'), findsOneWidget);
      await tester.tap(find.byTooltip('Hiện mật khẩu'));
      await tester.pump();
      expect(find.byTooltip('Ẩn mật khẩu'), findsOneWidget);
    });
  });

  group('chọn không gian làm việc', () {
    final tenants = [
      const TenantOption(
        id: 't1',
        name: 'Xưởng đàn Hoàng Gia',
        code: 'XDH',
        memberCount: 24,
        planLabel: 'Gói Pro',
      ),
      const TenantOption(id: 't2', name: 'Showroom Piano Sài Gòn'),
    ];

    testWidgets('mỗi không gian một thẻ, có chữ viết tắt và dòng phụ', (
      tester,
    ) async {
      await pump(tester, const WorkspacePage(), [
        tenantOptionsProvider.overrideWith((ref) async => tenants),
      ]);
      await tester.pump();

      expect(find.text('Chọn công ty'), findsOneWidget);
      expect(find.text('XDH'), findsOneWidget);
      expect(find.text('24 nhân viên · Gói Pro'), findsOneWidget);
      // Không có mã: hai chữ đầu của tên.
      expect(find.text('SP'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Đăng xuất'), findsOneWidget);
      // Đã đăng nhập: logo chỉ ở đăng nhập / mở app.
      expect(find.byType(OmniBrandMark), findsNothing);
    });
  });
}
