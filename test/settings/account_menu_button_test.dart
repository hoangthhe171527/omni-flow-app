import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/settings/presentation/widgets/account_menu_button.dart';
import 'package:omni_app/modules/settings/settings_module.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

void main() {
  Future<void> pump(WidgetTester t, {required bool tile}) async {
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
            const Session(
              status: SessionStatus.authenticated,
              user: SessionUser(
                id: 'u',
                fullName: 'Trần Huy Hoàng',
                email: 'h@x.vn',
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

  testWidgets('ô vuông: bấm avatar mở màn Tài khoản, không bật menu', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    await pump(t, tile: true);
    await t.tap(find.bySemanticsLabel(RegExp('^Tài khoản')));
    await t.pumpAndSettle();
    expect(find.text('ACCOUNT'), findsOneWidget);
    expect(find.byType(PopupMenuItem<String>), findsNothing);
    handle.dispose();
  });

  testWidgets('ô vuông: vùng chạm ≥ 44, phần vẽ 36', (t) async {
    final handle = t.ensureSemantics();
    await pump(t, tile: true);
    final size = t.getSize(find.bySemanticsLabel(RegExp('^Tài khoản')));
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
    expect(
      t.getSize(
        find
            .ancestor(of: find.text('H'), matching: find.byType(Material))
            .first,
      ),
      const Size(36, 36),
    );
    handle.dispose();
  });

  testWidgets('kiểu tròn: bấm avatar cũng mở màn Tài khoản', (t) async {
    await pump(t, tile: false);
    await t.tap(find.byType(InkResponse));
    await t.pumpAndSettle();
    expect(find.text('ACCOUNT'), findsOneWidget);
    expect(find.byType(PopupMenuItem<String>), findsNothing);
  });
}
