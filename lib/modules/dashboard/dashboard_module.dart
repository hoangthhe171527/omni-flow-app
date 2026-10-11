import 'package:flutter/material.dart';

import '../../core/module/module_route.dart';
import '../../core/module/nav_destination.dart';
import '../../core/module/omni_module.dart';
import '../../security/guard/access_requirement.dart';
import 'dashboard_routes.dart';
import 'domain/dashboard_permissions.dart';
import 'presentation/dashboard_page.dart';

/// Tổng quan: doanh thu cộng dồn, Việc của tôi, Chờ phản hồi — tab đầu tiên.
class DashboardModule extends OmniModule {
  const DashboardModule();

  @override
  String get id => 'dashboard';

  @override
  String get title => 'Tổng quan';

  @override
  List<String> get permissions => DashboardPermissions.revenue;

  @override
  List<ModuleRoute> routes() => [
    ModuleRoute(
      path: DashboardRoutes.homePath,
      name: DashboardRoutes.home,
      access: const AccessRequirement.any(DashboardPermissions.anyRead),
      builder: (_, _) => const DashboardPage(),
    ),
  ];

  @override
  List<ModuleNavEntry> navEntries() => [
    ModuleNavEntry(
      moduleId: id,
      label: 'Tổng quan',
      subtitle: 'Doanh thu và việc hôm nay',
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart_rounded,
      routeName: DashboardRoutes.home,
      area: NavArea.work,
      weight: NavWeight.primary,
      order: 0,
      access: const AccessRequirement.any(DashboardPermissions.anyRead),
    ),
  ];
}
