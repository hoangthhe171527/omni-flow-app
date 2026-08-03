import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/module/module_registry.dart';
import '../../core/module/module_route.dart';
import '../../modules/auth/auth_module.dart';
import '../../security/session/session.dart';
import '../../security/session/session_controller.dart';
import '../shell/app_shell.dart';
import '../shell/more_page.dart';
import '../shell/splash_page.dart';
import 'access_boundary.dart';
import 'session_refresh.dart';
import 'shell_routes.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
  final destinations = ref.watch(declaredDestinationsProvider);
  final moduleRoutes = ref.watch(moduleRoutesProvider);

  // Routes that back a bottom-bar tab become shell branches (each keeps its own
  // navigation stack); everything else is pushed full-screen over the shell.
  final tabRouteNames = destinations.map((d) => d.routeName).toSet();
  final tabRoutes = <String, ModuleRoute>{
    for (final route in moduleRoutes)
      if (tabRouteNames.contains(route.name)) route.name: route,
  };
  final overlayRoutes =
      moduleRoutes.where((route) => !tabRouteNames.contains(route.name));

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: ShellRoutes.splashPath,
    refreshListenable: ref.watch(sessionRefreshProvider),
    redirect: (context, state) => _redirect(ref, state),
    routes: [
      GoRoute(
        path: ShellRoutes.splashPath,
        name: ShellRoutes.splash,
        builder: (_, _) => const SplashPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          for (final destination in destinations)
            StatefulShellBranch(
              routes: [
                if (tabRoutes[destination.routeName] case final route?)
                  _toGoRoute(route, rootKey),
              ],
            ),
          // The "Thêm" tab belongs to the shell, not to a module: it is where
          // every module's non-tab entries surface.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: ShellRoutes.morePath,
                name: ShellRoutes.more,
                builder: (_, _) => const MorePage(),
              ),
            ],
          ),
        ],
      ),
      for (final route in overlayRoutes) _toGoRoute(route, rootKey),
    ],
  );
});

GoRoute _toGoRoute(ModuleRoute route, GlobalKey<NavigatorState> rootKey) {
  return GoRoute(
    path: route.path,
    name: route.name,
    parentNavigatorKey: route.rootNavigator ? rootKey : null,
    builder: (context, state) => AccessBoundary(
      requirement: route.access,
      child: route.builder(context, state),
    ),
    routes: [for (final child in route.children) _toGoRoute(child, rootKey)],
  );
}

/// Auth-state routing only. Permission routing is the [AccessBoundary]'s job —
/// splitting them keeps this function from growing into a second permission
/// system that has to be kept in sync with the first.
String? _redirect(Ref ref, GoRouterState state) {
  final session = ref.read(sessionProvider);
  final location = state.matchedLocation;

  final isSplash = location == ShellRoutes.splashPath;
  final isLogin = location == AuthModule.loginPath;
  final isWorkspace = location == AuthModule.workspacePath;

  return switch (session.status) {
    SessionStatus.restoring => isSplash ? null : ShellRoutes.splashPath,
    SessionStatus.unauthenticated ||
    SessionStatus.expired =>
      isLogin ? null : AuthModule.loginPath,
    SessionStatus.tenantPending => isWorkspace ? null : AuthModule.workspacePath,
    SessionStatus.authenticated =>
      (isLogin || isWorkspace || isSplash) ? _homePath(ref) : null,
  };
}

/// Landing screen after sign-in: the first tab this user can actually see. A
/// rep with only inbox rights lands in the inbox; a finance-only user does not
/// land on a blank permission wall.
String _homePath(Ref ref) {
  final visible = ref.read(visibleDestinationsProvider);
  if (visible.isEmpty) return ShellRoutes.morePath;

  final routes = ref.read(moduleRoutesProvider);
  for (final destination in visible) {
    for (final route in routes) {
      if (route.name == destination.routeName) return route.path;
    }
  }
  return ShellRoutes.morePath;
}
