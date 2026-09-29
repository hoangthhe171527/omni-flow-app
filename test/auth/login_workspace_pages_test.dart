import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/design/tokens/tokens.dart';
import 'package:omni_app/modules/auth/application/login_controller.dart';
import 'package:omni_app/modules/auth/presentation/login_page.dart';
import 'package:omni_app/modules/auth/presentation/workspace_page.dart';
import 'package:omni_app/security/session/auth_gateway.dart';

class _FailedLogin extends LoginController {
  @override
  LoginState build() =>
      const LoginState(error: 'Email hoặc mật khẩu không đúng.');
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
    testWidgets('khối mực mang logo và lời chào, biểu mẫu bên dưới', (
      tester,
    ) async {
      await pump(tester, const LoginPage(), const []);

      final mark = tester.widget<OmniBrandMark>(find.byType(OmniBrandMark));
      expect(mark.onInk, isTrue);
      expect(find.text('Chào mừng trở lại'), findsOneWidget);
      expect(find.text('Email làm việc'), findsOneWidget);
      expect(find.text('Mật khẩu'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Đăng nhập'), findsOneWidget);
      expect(find.text('Quên mật khẩu'), findsOneWidget);
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
