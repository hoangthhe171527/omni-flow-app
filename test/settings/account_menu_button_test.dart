import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/settings/presentation/widgets/account_menu_button.dart';
import 'package:omni_app/modules/settings/settings_module.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

void main() {
  Future<void> pump(
    WidgetTester t, {
    required bool tile,
    String? avatarUrl,
  }) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: Center(child: AccountMenuButton(tile: tile)),
          ),
        ),
        GoRoute(
          path: '/settings/account',
          name: SettingsModule.account,
          builder: (_, _) => const Scaffold(body: Text('ACCOUNT')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWithValue(
            Session(
              status: SessionStatus.authenticated,
              user: SessionUser(
                id: 'u',
                fullName: 'Trần Huy Hoàng',
                email: 'h@x.vn',
                avatarUrl: avatarUrl,
              ),
            ),
          ),
        ],
        child: MaterialApp.router(
          theme: OmniTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('avatar header tròn: mở menu nhanh; chọn Tài khoản mới chuyển', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    await pump(t, tile: true);
    await t.tap(find.bySemanticsLabel(RegExp('^Tài khoản')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('account-quick-menu')), findsOneWidget);
    expect(find.text('h@x.vn'), findsOneWidget);
    expect(find.text('ACCOUNT'), findsNothing);
    await t.tap(find.text('Tài khoản').last);
    await t.pumpAndSettle();
    expect(find.text('ACCOUNT'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('avatar header tròn: vùng chạm ≥ 44, phần vẽ 36', (t) async {
    final handle = t.ensureSemantics();
    await pump(t, tile: true);
    final size = t.getSize(find.bySemanticsLabel(RegExp('^Tài khoản')));
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
    expect(
      t.getSize(find.byKey(const ValueKey('account-avatar-face'))),
      const Size(36, 36),
    );
    expect(
      t
          .widget<Material>(find.byKey(const ValueKey('account-avatar-face')))
          .shape,
      isA<CircleBorder>(),
    );
    handle.dispose();
  });

  testWidgets('avatar header dùng URL ảnh thay vì luôn hiện chữ cái', (
    t,
  ) async {
    await pump(t, tile: true, avatarUrl: '/api/v1/auth/avatar/avatar-moi.jpg');

    final avatar = t.widget<OmniAvatar>(find.byType(OmniAvatar));
    expect(avatar.imageUrl, '/api/v1/auth/avatar/avatar-moi.jpg');
    expect(find.text('H'), findsNothing);
  });

  testWidgets('kiểu tròn: bấm avatar cũng mở menu nhanh', (t) async {
    await pump(t, tile: false);
    await t.tap(find.byType(InkResponse));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('account-quick-menu')), findsOneWidget);
    expect(find.text('ACCOUNT'), findsNothing);
    await t.tap(find.text('Tài khoản').last);
    await t.pumpAndSettle();
    expect(find.text('ACCOUNT'), findsOneWidget);
  });
}
