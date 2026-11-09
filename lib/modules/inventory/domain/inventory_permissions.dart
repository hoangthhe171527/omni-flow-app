import 'package:flutter/foundation.dart';

import '../../../security/permissions/access_policy.dart';

/// Quyền Kho hàng (spec TNP_KHO_VA_HANG_SAP_VE §6, `routes.php` của Inventory).
abstract final class InventoryPermissions {
  static const read = 'inventory.read';
  static const write = 'inventory.write';
  static const reserve = 'inventory.reserve';
  static const cost = 'inventory.cost';
  static const lotPayments = 'inventory.lot_payments';

  /// Tạo đơn từ cây (`POST /orders/from-units`) cần thêm quyền ghi đơn.
  static const ordersWrite = 'orders.write';

  /// Khả năng API (`/auth/context` → `api_capabilities`). Thiếu = API cũ chưa
  /// có Kho: ẩn mọi lối vào, không gọi request nào.
  static const capability = 'inventory';

  /// Menu và route cùng một yêu cầu — deep link không lách được lớp ẩn.
  static const List<String> readOnly = [read];

  static const List<String> all = [read, write, reserve, cost, lotPayments];
}

/// Quyền Kho của người đang đăng nhập — cùng cách tính với web
/// (`useInventoryPerms`). Thiếu capability → mọi quyền false.
@immutable
class InventoryPerms {
  const InventoryPerms({
    this.read = false,
    this.write = false,
    this.reserve = false,
    this.cost = false,
    this.pay = false,
    this.sell = false,
  });

  factory InventoryPerms.from({
    required bool capable,
    required AccessPolicy policy,
  }) {
    bool has(String slug) => capable && policy.can(slug);
    final read = has(InventoryPermissions.read);
    return InventoryPerms(
      read: read,
      write: read && has(InventoryPermissions.write),
      reserve: read && has(InventoryPermissions.reserve),
      cost: read && has(InventoryPermissions.cost),
      pay: read && has(InventoryPermissions.lotPayments),
      sell:
          read &&
          has(InventoryPermissions.reserve) &&
          has(InventoryPermissions.ordersWrite),
    );
  }

  static const none = InventoryPerms();

  /// Có capability + `inventory.read` — được vào Kho.
  final bool read;

  /// Tạo lô, thêm cây, sửa serial/tình trạng/giá niêm yết, nhận hàng.
  final bool write;

  /// Giữ / đặt trước / bỏ giữ.
  final bool reserve;

  /// Thấy giá nhập ¥, giá vốn, tỷ lệ.
  final bool cost;

  /// Thấy / ghi thanh toán lô, sửa tỷ lệ tạm.
  final bool pay;

  /// Tạo đơn từ cây (cần thêm `orders.write`).
  final bool sell;

  /// Mở được sheet "Bán / Đặt trước".
  bool get canSellOrReserve => reserve || sell;
}
