/// Tên và đường dẫn route của Kho hàng — file hằng số, không import gì, để
/// module khác (và shell) lấy tên route mà không kéo theo cả module.
abstract final class InventoryRoutes {
  static const stock = 'inventory.stock';
  static const stockPath = '/inventory/stock';

  static const lots = 'inventory.lots';
  static const lotsPath = '/inventory/lots';

  static const lot = 'inventory.lot';
  static const lotPath = '/inventory/lots/:lotId';

  static const receive = 'inventory.receive';
  static const receivePath = '/inventory/lots/:lotId/receive';

  static const suppliers = 'inventory.suppliers';
  static const suppliersPath = '/inventory/suppliers';

  static const supplier = 'inventory.supplier';
  static const supplierPath = '/inventory/suppliers/:supplierId';

  // Kho chuẩn hóa Đợt B.
  static const catalog = 'inventory.catalog';
  static const catalogPath = '/inventory/catalog';

  static const reservations = 'inventory.reservations';
  static const reservationsPath = '/inventory/reservations';

  // Kho chuẩn hóa Đợt C.
  static const counts = 'inventory.counts';
  static const countsPath = '/inventory/counts';

  static const delivered = 'inventory.delivered';
  static const deliveredPath = '/inventory/delivered';

  // Đơn hàng theo cây (TNP_DON_HANG_THEO_CAY §6).
  static const orders = 'inventory.orders';
  static const ordersPath = '/inventory/orders';

  static const order = 'inventory.order';
  static const orderPath = '/inventory/orders/:orderId';
}
