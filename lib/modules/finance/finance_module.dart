import 'package:flutter/material.dart';

import '../../core/module/module_route.dart';
import '../../core/module/nav_destination.dart';
import '../../core/module/omni_module.dart';
import '../../security/guard/access_requirement.dart';
import 'domain/finance_permissions.dart';
import 'presentation/expenses_page.dart';
import 'routes.dart';

export 'routes.dart';

/// Phân hệ **Sổ chi phí** (`finance.expenses`).
class FinanceModule extends OmniModule {
  const FinanceModule();

  @override
  String get id => 'finance';

  @override
  String get title => 'Sổ chi phí';

  @override
  List<String> get permissions => FinancePermissions.all;

  @override
  List<ModuleRoute> routes() => [
    ModuleRoute(
      path: FinanceRoutes.expensesPath,
      name: FinanceRoutes.expenses,
      rootNavigator: true,
      access: const AccessRequirement.any(FinancePermissions.anyRead),
      builder: (_, _) => const ExpensesPage(),
    ),
  ];

  @override
  List<ModuleNavEntry> navEntries() => const [
    ModuleNavEntry(
      moduleId: 'finance',
      label: 'Sổ chi phí',
      subtitle: 'Ghi chép và theo dõi chi phí theo tháng',
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet_rounded,
      routeName: FinanceRoutes.expenses,
      area: NavArea.admin,
      weight: NavWeight.secondary,
      order: 25,
      access: AccessRequirement.any(FinancePermissions.anyRead),
    ),
  ];
}
