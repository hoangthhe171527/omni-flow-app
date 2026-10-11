import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/module/module_registry.dart';
import '../../core/module/module_route.dart';
import '../../core/nav/tab_order.dart';
import '../../modules/auth/auth_module.dart';
import '../../security/session/session.dart';
import '../../security/session/session_controller.dart';
import '../shell/app_shell.dart';
import '../shell/directory_page.dart';
import '../shell/splash_page.dart';
import 'access_boundary.dart';
import 'session_refresh.dart';
import 'shell_routes.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
  // Sống cùng router: một router mới (đổi quyền, đổi tenant) bắt đầu lại từ
  // trống, đúng như mong đợi.
  final pending = _PendingDestination();
  // Chỉ mục PRIMARY thành branch, và branch dựng từ danh sách KHÔNG lọc quyền.
  // Một tab phải giữ ngăn xếp điều hướng riêng, còn biến mọi mục thành branch
  // nghĩa là 20 module thành 20 navigator. Mục secondary là "chỗ để ghé" — mở
  // từ danh bạ, phủ lên shell, đóng lại là xong.
  final branchEntries = ref.watch(branchNavEntriesProvider);
  final moduleRoutes = ref.watch(moduleRoutesProvider);

  final tabRouteNames = branchEntries.map((e) => e.routeName).toSet();
  final tabRoutes = <String, ModuleRoute>{
    for (final route in moduleRoutes)
      if (tabRouteNames.contains(route.name)) route.name: route,
  };
  final overlayRoutes = moduleRoutes.where(
    (route) => !tabRouteNames.contains(route.name),
  );

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: ShellRoutes.splashPath,
    refreshListenable: ref.watch(sessionRefreshProvider),
    redirect: (context, state) => _redirect(ref, state, pending),
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
          for (final entry in branchEntries)
            StatefulShellBranch(
              routes: [
                if (tabRoutes[entry.routeName] case final route?)
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
                builder: (_, _) => const DirectoryPage(),
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

/// Nơi người dùng ĐỊNH tới, giữ lại trong lúc phiên còn đang khôi phục.
///
/// Không có nó thì mọi liên kết sâu đều mất: app khởi động ở trạng thái
/// `restoring`, redirect đẩy về splash và VỨT đích đến, rồi khi khôi phục xong
/// thì đưa về tab mặc định. Mở một công việc từ thông báo đẩy, tải lại trang
/// khi đang xem chi tiết, hay dán một đường dẫn — cả ba đều rơi về màn chủ.
///
/// Một ô nhớ THUẦN, không phải provider. Bản đầu dùng `StateProvider` và ghi
/// vào nó ngay trong `redirect`; Riverpod cấm sửa state giữa lúc build nên nó
/// ném "At least listener of the StateNotifier … threw an exception", và màn
/// hình đứng mãi ở khung xương. Redirect không cần thứ gì phản ứng — nó chỉ
/// cần một chỗ đặt tạm giữa hai lần gọi.
class _PendingDestination {
  /// URL đầy đủ chứ không chỉ đường dẫn khớp: bộ lọc và tham số truy vấn cũng
  /// là một phần của "chỗ tôi định tới".
  String? value;
}

/// Auth-state routing only. Permission routing is the [AccessBoundary]'s job —
/// splitting them keeps this function from growing into a second permission
/// system that has to be kept in sync with the first.
String? _redirect(Ref ref, GoRouterState state, _PendingDestination pending) {
  final session = ref.read(sessionProvider);
  final location = state.matchedLocation;

  final isSplash = location == ShellRoutes.splashPath;
  final isLogin = location == AuthModule.loginPath;
  final isWorkspace = location == AuthModule.workspacePath;
  // Các màn này là TRẠM DỪNG của chính luồng đăng nhập. Nhớ chúng làm đích đến
  // sẽ tạo ra một vòng: đăng nhập xong lại quay về màn đăng nhập.
  // Đăng ký và quên mật khẩu là trạm của người CHƯA có tài khoản: mở được khi
  // chưa đăng nhập, và cũng không được nhớ làm đích đến.
  final isOnboarding =
      location == AuthModule.registerPath || location == AuthModule.forgotPath;
  final isWayStation = isSplash || isLogin || isWorkspace || isOnboarding;

  if (!isWayStation && session.status != SessionStatus.authenticated) {
    pending.value = state.uri.toString();
  }

  return switch (session.status) {
    SessionStatus.restoring => isSplash ? null : ShellRoutes.splashPath,
    SessionStatus.unauthenticated || SessionStatus.expired =>
      (isLogin || isOnboarding) ? null : AuthModule.loginPath,
    SessionStatus.tenantPending =>
      isWorkspace ? null : AuthModule.workspacePath,
    SessionStatus.authenticated =>
      isWayStation ? _afterSignIn(ref, pending) : null,
  };
}

/// Chỗ đưa người dùng tới sau khi phiên sẵn sàng.
///
/// Đích đã ghi nhớ nếu có, và ghi nhớ đó dùng ĐÚNG MỘT LẦN — không xoá thì lần
/// đăng nhập sau lại nhảy tới một công việc từ phiên trước, giữa lúc người
/// dùng không hề bấm gì liên quan.
String _afterSignIn(Ref ref, _PendingDestination pending) {
  final destination = pending.value;
  if (destination == null) return landingPath(ref);

  pending.value = null;

  return destination;
}

/// Landing screen after sign-in: the first TAB (fixed order, see tab_order.dart)
/// this user can actually see. A rep with only inbox rights lands in the inbox.
/// With no tab at all, the first permitted primary entry (e.g. opportunities)
/// is used; only a user with nothing to show lands on "More".
@visibleForTesting
String landingPath(Ref ref) {
  final tabs = ref.read(tabEntriesProvider);
  final candidates = tabs.isNotEmpty
      ? tabs
      : ref.read(primaryNavEntriesProvider).take(1).toList();
  if (candidates.isEmpty) return ShellRoutes.morePath;

  final routes = ref.read(moduleRoutesProvider);
  for (final entry in candidates) {
    for (final route in routes) {
      if (route.name == entry.routeName) return route.path;
    }
  }
  return ShellRoutes.morePath;
}
