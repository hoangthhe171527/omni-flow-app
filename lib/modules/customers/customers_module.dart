import 'package:flutter/material.dart';

import '../../core/module/module_route.dart';
import '../../core/module/nav_destination.dart';
import '../../core/module/omni_module.dart';
import '../../security/guard/access_requirement.dart';
import 'domain/customer_permissions.dart';
import 'presentation/customer_detail_page.dart';
import 'presentation/customer_form_page.dart';
import 'presentation/customers_page.dart';

class CustomersModule extends OmniModule {
  const CustomersModule();

  static const list = 'customers.list';
  static const detail = 'customers.detail';
  static const create = 'customers.create';
  static const edit = 'customers.edit';

  @override
  String get id => 'customers';

  @override
  String get title => 'Khách hàng';

  @override
  List<String> get permissions => CustomerPermissions.all;

  @override
  List<ModuleRoute> routes() => [
    ModuleRoute(
      path: '/customers',
      name: list,
      access: const AccessRequirement.any(CustomerPermissions.anyRead),
      builder: (_, _) => const CustomersPage(),
    ),
    // Declared before `/customers/:id` so "new" is never read as an id.
    ModuleRoute(
      path: '/customers/new',
      name: create,
      rootNavigator: true,
      access: const AccessRequirement.any([CustomerPermissions.create]),
      builder: (_, _) => const CustomerFormPage(),
    ),
    ModuleRoute(
      path: '/customers/:id',
      name: detail,
      rootNavigator: true,
      access: const AccessRequirement.any(CustomerPermissions.anyRead),
      builder: (_, state) =>
          CustomerDetailPage(customerId: state.pathParameters['id']!),
    ),
    ModuleRoute(
      path: '/customers/:id/edit',
      name: edit,
      rootNavigator: true,
      access: const AccessRequirement.any([CustomerPermissions.update]),
      builder: (_, state) =>
          CustomerFormPage(customerId: state.pathParameters['id']!),
    ),
  ];

  @override
  List<ModuleNavEntry> navEntries() => const [
    ModuleNavEntry(
      moduleId: 'customers',
      label: 'Khách hàng',
      subtitle: 'Danh bạ và lịch sử liên hệ',
      icon: Icons.people_outline_rounded,
      selectedIcon: Icons.people_rounded,
      routeName: list,
      area: NavArea.sales,
      weight: NavWeight.primary,
      order: 10,
      access: AccessRequirement.any(CustomerPermissions.anyRead),
    ),
  ];
}
