import 'package:flutter/material.dart';

import '../../core/module/module_route.dart';
import '../../core/module/nav_destination.dart';
import '../../core/module/omni_module.dart';
import '../../security/guard/access_requirement.dart';
import 'domain/finance_permissions.dart';
import 'presentation/expense_summary_page.dart';
import 'presentation/finance_catalog_page.dart';
import 'presentation/expenses_page.dart';
import 'routes.dart';

export 'routes.dart';

/// Phân hệ **Tài chính & Chi phí** (`finance.expenses`, `finance.summary`).
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
      access: const AccessRequirement.all(FinancePermissions.adminOnly),
      builder: (_, _) => const ExpensesPage(),
    ),
    ModuleRoute(
      path: FinanceRoutes.expenseSummaryPath,
      name: FinanceRoutes.expenseSummary,
      rootNavigator: true,
      access: const AccessRequirement.all(FinancePermissions.adminOnly),
      builder: (_, _) => const ExpenseSummaryPage(),
    ),
    ModuleRoute(
      path: FinanceRoutes.catalogPath,
      name: FinanceRoutes.catalog,
      rootNavigator: true,
      access: const AccessRequirement.all(FinancePermissions.adminOnly),
      builder: (_, _) => const FinanceCatalogPage(),
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
      area: NavArea.finance,
      weight: NavWeight.secondary,
      order: 25,
      access: AccessRequirement.all(FinancePermissions.adminOnly),
    ),
    ModuleNavEntry(
      moduleId: 'finance',
      label: 'Tổng hợp chi phí',
      subtitle: 'Tổng hợp và phân tích chi phí theo tháng, quý, năm',
      icon: Icons.pie_chart_outline_rounded,
      selectedIcon: Icons.pie_chart_rounded,
      routeName: FinanceRoutes.expenseSummary,
      area: NavArea.finance,
      weight: NavWeight.secondary,
      order: 26,
      access: AccessRequirement.all(FinancePermissions.adminOnly),
    ),
    ModuleNavEntry(
      moduleId: 'finance',
      label: 'Danh mục chi',
      subtitle: 'Nhóm chi và nguồn tiền',
      icon: Icons.sell_outlined,
      selectedIcon: Icons.sell_rounded,
      routeName: FinanceRoutes.catalog,
      area: NavArea.finance,
      weight: NavWeight.secondary,
      order: 27,
      access: AccessRequirement.all(FinancePermissions.adminOnly),
    ),
  ];
}
