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
}
