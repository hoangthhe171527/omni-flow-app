import 'package:flutter/material.dart';

import '../../core/module/module_route.dart';
import '../../core/module/nav_destination.dart';
import '../../core/module/omni_module.dart';
import '../../security/guard/access_requirement.dart';
import 'domain/inventory_permissions.dart';
import 'presentation/lot_detail_page.dart';
import 'presentation/lots_page.dart';
import 'presentation/receive_page.dart';
import 'presentation/stock_page.dart';
import 'routes.dart';

export 'routes.dart';

/// Phân hệ **Kho hàng**: Tồn kho theo serial, Hàng sắp về (lô), Nhận hàng.
///
/// Route và mục menu cùng đòi `inventory.read`; capability `inventory` của API
/// lọc thêm ở danh bạ (`directory_page.dart`) và trong từng màn — API cũ chưa
/// có Kho thì không hiện lối vào, không gọi request nào.
class InventoryModule extends OmniModule {
  const InventoryModule();

  static const moduleId = 'inventory';

  @override
  String get id => moduleId;

  @override
  String get title => 'Kho hàng';

  @override
  List<String> get permissions => InventoryPermissions.all;

  @override
  List<ModuleRoute> routes() => [
    ModuleRoute(
      path: InventoryRoutes.stockPath,
      name: InventoryRoutes.stock,
      access: const AccessRequirement.all(InventoryPermissions.readOnly),
      builder: (_, _) => const StockPage(),
    ),
    ModuleRoute(
      path: InventoryRoutes.lotsPath,
      name: InventoryRoutes.lots,
      access: const AccessRequirement.all(InventoryPermissions.readOnly),
      builder: (_, _) => const LotsPage(),
    ),
    ModuleRoute(
      path: InventoryRoutes.receivePath,
      name: InventoryRoutes.receive,
      rootNavigator: true,
      access: const AccessRequirement.all([InventoryPermissions.write]),
      builder: (_, state) => ReceivePage(lotId: state.pathParameters['lotId']!),
    ),
    ModuleRoute(
      path: InventoryRoutes.lotPath,
      name: InventoryRoutes.lot,
      rootNavigator: true,
      access: const AccessRequirement.all(InventoryPermissions.readOnly),
      builder: (_, state) =>
          LotDetailPage(lotId: state.pathParameters['lotId']!),
    ),
  ];

  @override
  List<ModuleNavEntry> navEntries() => const [
    ModuleNavEntry(
      moduleId: moduleId,
      label: 'Tồn kho',
      subtitle: 'Tìm serial, giữ hàng, bán từ kho',
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2_rounded,
      routeName: InventoryRoutes.stock,
      area: NavArea.sales,
      weight: NavWeight.secondary,
      order: 40,
      access: AccessRequirement.all(InventoryPermissions.readOnly),
    ),
    ModuleNavEntry(
      moduleId: moduleId,
      label: 'Hàng sắp về',
      subtitle: 'Lô đang về, đặt trước, nhận hàng',
      icon: Icons.local_shipping_outlined,
      selectedIcon: Icons.local_shipping_rounded,
      routeName: InventoryRoutes.lots,
      area: NavArea.sales,
      weight: NavWeight.secondary,
      order: 41,
      access: AccessRequirement.all(InventoryPermissions.readOnly),
    ),
  ];
}
