import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omni_app/app/shell/app_shell.dart';
import 'package:omni_app/bootstrap.dart';
import 'package:omni_app/core/module/module_registry.dart';
import 'package:omni_app/core/nav/shell_bar_inset.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

/// Dựng `AppShell` thật trên một go_router tối giản: mỗi branch là một trang
/// trống, đủ để shell có `StatefulNavigationShell` mà không kéo cả app theo.
Future<void> pumpShell(WidgetTester tester, {Widget? firstPage}) async {
  final container = ProviderContainer(
    overrides: [
      modulesProvider.overrideWithValue(appModules),
      sessionProvider.overrideWithValue(
        Session(
          status: SessionStatus.authenticated,
          policy: AccessPolicy({
            'tasks.read',
            'inbox.read',
            'crm.customers.read',
            'crm.sales_opportunities.read',
          }),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);

  final branchCount = container.read(branchNavEntriesProvider).length + 1;
  final router = GoRouter(
    initialLocation: '/b0',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          for (var i = 0; i < branchCount; i++)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/b$i',
                  builder: (_, _) => i == 0 && firstPage != null
                      ? firstPage
                      : const SizedBox.expand(),
                ),
              ],
            ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('thanh tab có lớp kính mờ và body vẽ dưới nó', (tester) async {
    await pumpShell(tester);

    expect(
      find.descendant(
        of: find.byType(AppShell),
        matching: find.byType(BackdropFilter),
      ),
      findsOneWidget,
    );
    final scaffold = tester.widget<Scaffold>(
      find
          .descendant(
            of: find.byType(AppShell),
            matching: find.byType(Scaffold),
          )
          .first,
    );
    expect(scaffold.extendBody, isTrue);
  });

  testWidgets('nút nổi của màn gốc tab nằm trên thanh, không bị thanh đè', (
    tester,
  ) async {
    await pumpShell(
      tester,
      firstPage: Scaffold(
        floatingActionButton: ShellFabLift(
          child: FloatingActionButton.extended(
            onPressed: () {},
            label: const Text('Thêm'),
          ),
        ),
        body: const SizedBox.expand(),
      ),
    );

    final fab = tester.getRect(find.byType(FloatingActionButton));
    final bar = tester.getRect(find.byType(BackdropFilter));

    expect(fab.bottom, lessThanOrEqualTo(bar.top));
    // Chạm giữa nút phải trúng chính nút, không trúng thanh.
    expect(
      tester
          .hitTestOnBinding(fab.center)
          .path
          .any(
            (e) =>
                e.target is RenderBox &&
                e.target.runtimeType.toString().contains('Backdrop'),
          ),
      isFalse,
    );
  });

  testWidgets('ngoài shell, ShellFabLift không đệm gì', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          floatingActionButton: ShellFabLift(child: SizedBox(key: Key('f'))),
        ),
      ),
    );

    expect(ShellBarInset.barHeight, 62);
    final padding = tester.widget<Padding>(
      find.descendant(
        of: find.byType(ShellFabLift),
        matching: find.byType(Padding),
      ),
    );
    expect(padding.padding, EdgeInsets.zero);
  });
}
