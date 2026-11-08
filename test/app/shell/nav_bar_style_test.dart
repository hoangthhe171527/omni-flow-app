import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/components/omni_glass.dart';
import 'package:go_router/go_router.dart';
import 'package:omni_app/app/shell/app_shell.dart';
import 'package:omni_app/bootstrap.dart';
import 'package:omni_app/core/module/module_registry.dart';
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
  testWidgets('thanh tab là viên kính nổi, mép dưới mờ dần, body vẽ dưới nó', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await pumpShell(tester);

    // Viên kính (OmniGlass) + dải mờ dần ở mép dưới (OmniScrollEdge). Dải mép
    // còn MỘT lớp làm mờ (trước 3 — rà soát hiệu năng 08/11/2026: mỗi lớp đè
    // nội dung cuộn phải vẽ lại mỗi khung).
    expect(
      find.descendant(
        of: find.byType(AppShell),
        matching: find.byType(OmniGlass),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AppShell),
        matching: find.byType(OmniScrollEdge),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AppShell),
        matching: find.byType(BackdropFilter),
      ),
      findsNWidgets(2),
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
}
