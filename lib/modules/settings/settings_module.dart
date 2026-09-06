import 'package:flutter/material.dart';

import '../../core/module/module_route.dart';
import '../../core/module/nav_destination.dart';
import '../../core/module/omni_module.dart';
import 'presentation/my_permissions_page.dart';

/// Account-level screens. Open to everyone — a user is always allowed to see
/// who they are and what they can do.
class SettingsModule extends OmniModule {
  const SettingsModule();

  static const myPermissions = 'settings.permissions';

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
  ];
}
