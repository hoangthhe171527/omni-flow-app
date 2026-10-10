import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omni_app/app/router/app_router.dart';
import 'package:omni_app/app/shell/directory_page.dart';
import 'package:omni_app/app/router/shell_routes.dart';
import 'package:omni_app/core/module/module_registry.dart';
import 'package:omni_app/core/storage/preferences_store.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/auth/application/login_controller.dart';
import 'package:omni_app/modules/auth/auth_module.dart';
import 'package:omni_app/modules/auth/presentation/workspace_page.dart';
import 'package:omni_app/modules/settings/application/appearance_providers.dart';
import 'package:omni_app/modules/settings/presentation/account_page.dart';
import 'package:omni_app/modules/settings/settings_module.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/auth_gateway.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fixed_background.dart';

/// Phiên giả giữ nguyên hành vi THẬT của `chooseWorkspace` / `selectTenant`
/// (chỉ đổi trạng thái), để kiểm router thật phản ứng ra sao.
class _Session extends SessionController {
  @override
  Session build() => Session(
    status: SessionStatus.authenticated,
    user: const SessionUser(id: 'u', fullName: 'Hoàng', email: 'h@x.vn'),
    tenant: const SessionTenant(id: 't-0', name: 'Xưởng đàn'),
    policy: const AccessPolicy({}),
  );

  @override
  void chooseWorkspace() {
    if (!state.isAuthenticated) return;
    state = const Session(status: SessionStatus.tenantPending);
  }

  @override
  Future<void> selectTenant(String tenantId) async {
    state = Session(
      status: SessionStatus.authenticated,
      user: const SessionUser(id: 'u', fullName: 'Hoàng', email: 'h@x.vn'),
      tenant: SessionTenant(id: tenantId, name: 'Không gian $tenantId'),
      policy: const AccessPolicy({}),
    );
  }
}

void main() {
  late ProviderContainer container;
  late GoRouter router;

  Future<void> pumpApp(WidgetTester t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    container = ProviderContainer(
      overrides: [
        modulesProvider.overrideWithValue(const [
          AuthModule(),
          SettingsModule(),
        ]),
        sharedPreferencesProvider.overrideWithValue(prefs),
        sessionControllerProvider.overrideWith(_Session.new),
        backgroundProvider.overrideWith(FixedBackground.new),
        tenantOptionsProvider.overrideWith(
          (ref) async => const [
            TenantOption(id: 't-0', name: 'Xưởng đàn'),
            TenantOption(id: 't-1', name: 'Cửa hàng B'),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);
    router = container.read(routerProvider);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: OmniTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('Đổi từ màn Tài khoản (đã push) → màn chọn, không còn Tài khoản '
      'bên dưới; chọn xong về màn chủ chứ không bật lại Tài khoản', (t) async {
    await pumpApp(t);
    // Màn chủ là "Thêm" (không có tab nào trong bộ module rút gọn).
    expect(find.byType(DirectoryPage), findsOneWidget);
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      ShellRoutes.morePath,
    );

    router.pushNamed(SettingsModule.account);
    await t.pumpAndSettle();
    expect(find.byType(AccountPage), findsOneWidget);

    await t.tap(find.text('Đổi'));
    await t.pumpAndSettle();

    expect(find.byType(WorkspacePage), findsOneWidget);
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AuthModule.workspacePath,
    );
    expect(find.byType(AccountPage, skipOffstage: false), findsNothing);
    // Ngăn xếp chỉ còn đúng một trang: không có gì để "back" về.
    expect(router.routerDelegate.currentConfiguration.matches.length, 1);

    await t.tap(find.text('Cửa hàng B'));
    await t.pumpAndSettle();

    expect(find.byType(AccountPage, skipOffstage: false), findsNothing);
    expect(find.byType(DirectoryPage), findsOneWidget);
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      ShellRoutes.morePath,
    );
  });
}
