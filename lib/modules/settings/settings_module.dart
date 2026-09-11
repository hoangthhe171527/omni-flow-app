import 'package:flutter/material.dart';

import '../../core/module/module_route.dart';
import '../../core/module/nav_destination.dart';
import '../../core/module/omni_module.dart';
import 'presentation/background_page.dart';
import 'presentation/my_permissions_page.dart';
import 'presentation/notification_settings_page.dart';

/// Account-level screens. Open to everyone — a user is always allowed to see
/// who they are and what they can do.
class SettingsModule extends OmniModule {
  const SettingsModule();

  static const myPermissions = 'settings.permissions';
  static const notifications = 'settings.notifications';
  static const background = 'settings.background';

  @override
  String get id => 'settings';

  @override
  String get title => 'Tài khoản';

  @override
  List<ModuleRoute> routes() => [
    ModuleRoute(
      path: '/settings/permissions',
      name: myPermissions,
      rootNavigator: true,
      builder: (_, _) => const MyPermissionsPage(),
    ),
    ModuleRoute(
      path: '/settings/notifications',
      name: notifications,
      rootNavigator: true,
      builder: (_, _) => const NotificationSettingsPage(),
    ),
    ModuleRoute(
      path: '/settings/background',
      name: background,
      rootNavigator: true,
      builder: (_, _) => const BackgroundPage(),
    ),
  ];

  @override
  List<ModuleNavEntry> navEntries() => const [
    ModuleNavEntry(
      moduleId: 'settings',
      label: 'Quyền của tôi',
      subtitle: 'Xem những gì bạn được phép làm',
      icon: Icons.shield_outlined,
      selectedIcon: Icons.shield_rounded,
      routeName: myPermissions,
      area: NavArea.account,
      weight: NavWeight.secondary,
      order: 10,
    ),
    ModuleNavEntry(
      moduleId: 'settings',
      label: 'Nền',
      subtitle: 'Chọn nền cho chat và bảng dự án',
      icon: Icons.wallpaper_outlined,
      selectedIcon: Icons.wallpaper_rounded,
      routeName: background,
      area: NavArea.account,
      weight: NavWeight.secondary,
      order: 15,
    ),
    ModuleNavEntry(
      moduleId: 'settings',
      label: 'Thông báo',
      subtitle: 'Chọn khi nào máy được rung',
      icon: Icons.notifications_outlined,
      selectedIcon: Icons.notifications_rounded,
      routeName: notifications,
      area: NavArea.account,
      weight: NavWeight.secondary,
      order: 20,
    ),
  ];
}
