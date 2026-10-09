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
  LoginState build() =>
      const LoginState(error: 'Email hoặc mật khẩu không đúng.');
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
    testWidgets('logo neo cho màn mở app, lời chào, hai ô và nút', (
      tester,
    ) async {
      await pump(tester, const LoginPage(), const []);

      final mark = tester.widget<OmniBrandMark>(find.byType(OmniBrandMark));
      expect(mark.size, 64);
      expect(mark.onInk, isNull);
      final anchor = tester.widget<BrandAnchor>(find.byType(BrandAnchor));
      expect(anchor.withWordmark, isFalse);
      expect(find.text('Chào mừng trở lại'), findsOneWidget);
      expect(find.text('Email làm việc'), findsOneWidget);
      expect(find.text('Mật khẩu'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Đăng nhập'), findsOneWidget);
      expect(find.text('Tiếp tục với Google'), findsOneWidget);
      expect(find.text('hoặc'), findsOneWidget);
      expect(find.text('Quên mật khẩu?'), findsOneWidget);
      expect(find.text('Đăng ký'), findsOneWidget);
      expect(find.text('Quyền riêng tư'), findsNothing);
      expect(find.text('Hỗ trợ'), findsNothing);
      expect(find.textContaining('xử lý công việc'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Google nằm dưới nút Đăng nhập', (tester) async {
      await pump(tester, const LoginPage(), const []);

      final login = find.widgetWithText(FilledButton, 'Đăng nhập');
      final google = find.byKey(const ValueKey('google-sign-in'));
      expect(
        tester.getTopLeft(google).dy > tester.getTopLeft(login).dy,
        isTrue,
      );
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
      final before = tester.getTopLeft(find.text('Email làm việc')).dx;
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final after = tester.getTopLeft(find.text('Email làm việc')).dx;
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
            builder: (_, _) => const Text('trang-quen'),
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
      expect(find.text('trang-quen'), findsOneWidget);
    });

    testWidgets('ô giữ tên truy cập được khi đã có chữ', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, const LoginPage(), const []);

      await tester.enterText(find.byType(TextField).first, 'a@b.vn');
      await tester.enterText(find.byType(TextField).last, 'matkhau');
      await tester.pump();

      expect(find.bySemanticsLabel('Email làm việc'), findsWidgets);
      expect(
        tester.getSemantics(find.byType(TextField).first).label,
        contains('Email làm việc'),
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

      expect(find.text('Chọn không gian làm việc'), findsOneWidget);
      expect(find.text('XDH'), findsOneWidget);
      expect(find.text('24 nhân viên · Gói Pro'), findsOneWidget);
      expect(find.text('SHO'), findsOneWidget);
      expect(find.text('Đăng xuất'), findsOneWidget);
      expect(find.byType(OmniBrandMark), findsOneWidget);
    });
  });
}
