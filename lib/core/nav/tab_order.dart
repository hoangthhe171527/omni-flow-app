import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../modules/customers/routes.dart';
import '../../modules/plans/routes.dart';
import '../module/module_registry.dart';
import '../module/nav_destination.dart';

/// Thanh tab theo bản thiết kế đã duyệt: Tổng quan · Hộp thư · Khách · Việc
/// (+ "Tất cả" do shell tự thêm). Cố định — người dùng không ghim nữa;
/// quyền vẫn lọc ở [primaryNavEntriesProvider].
const tabRouteOrder = <String>[
  'dashboard.home',
  'inbox.list',
  CustomerRoutes.list,
  PlanRoutes.teams,
];

/// Chỉ giữ mục thuộc thanh tab, theo đúng [tabRouteOrder], tối đa 4.
List<ModuleNavEntry> orderTabs(List<ModuleNavEntry> allowed) {
  final byRoute = {for (final e in allowed) e.routeName: e};

  return [for (final r in tabRouteOrder) ?byRoute[r]];
}

final tabEntriesProvider = Provider<List<ModuleNavEntry>>(
  (ref) => orderTabs(ref.watch(primaryNavEntriesProvider)),
);
