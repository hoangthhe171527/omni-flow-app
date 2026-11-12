import 'package:flutter/material.dart';

import '../../core/module/module_route.dart';
import '../../core/module/nav_destination.dart';
import '../../core/module/omni_module.dart';
import '../../security/guard/access_requirement.dart';
import 'domain/inventory_permissions.dart';
import 'presentation/catalog_page.dart';
import 'presentation/counts_page.dart';
import 'presentation/delivered_page.dart';
import 'presentation/order_units_page.dart';
import 'presentation/lot_detail_page.dart';
import 'presentation/lots_page.dart';
import 'presentation/receive_page.dart';
import 'presentation/reservations_page.dart';
import 'presentation/stock_page.dart';
import 'presentation/suppliers_page.dart';
import 'routes.dart';

export 'routes.dart';

/// Phân hệ **Kho hàng**: Tồn kho theo serial, Hàng sắp về (lô), Nhận hàng,
/// Nhà cung cấp (Đợt A — lối vào từ Hàng sắp về và từ lô).
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
    // Kho chuẩn hóa Đợt A: màn ẩn nội dung khi API thiếu `inventory.suppliers`.
    ModuleRoute(
      path: InventoryRoutes.suppliersPath,
      name: InventoryRoutes.suppliers,
      rootNavigator: true,
      access: const AccessRequirement.all(InventoryPermissions.readOnly),
      builder: (_, _) => const SuppliersPage(),
    ),
    ModuleRoute(
      path: InventoryRoutes.supplierPath,
      name: InventoryRoutes.supplier,
      rootNavigator: true,
      access: const AccessRequirement.all(InventoryPermissions.readOnly),
      builder: (_, state) =>
          SupplierDetailPage(supplierId: state.pathParameters['supplierId']!),
    ),
    // Kho chuẩn hóa Đợt B: màn ẩn nội dung khi API thiếu `inventory.products`
    // / `inventory.reservations`.
    ModuleRoute(
      path: InventoryRoutes.catalogPath,
      name: InventoryRoutes.catalog,
      rootNavigator: true,
      access: const AccessRequirement.all(InventoryPermissions.readOnly),
      builder: (_, _) => const CatalogPage(),
    ),
    ModuleRoute(
      path: InventoryRoutes.reservationsPath,
      name: InventoryRoutes.reservations,
      rootNavigator: true,
      access: const AccessRequirement.all(InventoryPermissions.readOnly),
      builder: (_, _) => const ReservationsPage(),
    ),
    // Kho chuẩn hóa Đợt C: màn ẩn nội dung khi API thiếu `inventory.counts`
    // / `inventory.returns`.
    ModuleRoute(
      path: InventoryRoutes.countsPath,
      name: InventoryRoutes.counts,
      rootNavigator: true,
      access: const AccessRequirement.all(InventoryPermissions.readOnly),
      builder: (_, _) => const CountsPage(),
    ),
    ModuleRoute(
      path: InventoryRoutes.deliveredPath,
      name: InventoryRoutes.delivered,
      rootNavigator: true,
      access: const AccessRequirement.all(InventoryPermissions.readOnly),
      builder: (_, _) => const DeliveredPage(),
    ),
    ModuleRoute(
      path: InventoryRoutes.orderPath,
      name: InventoryRoutes.order,
      rootNavigator: true,
      access: const AccessRequirement.all(InventoryPermissions.readOnly),
      builder: (_, state) =>
          OrderUnitsPage(orderId: state.pathParameters['orderId']!),
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
