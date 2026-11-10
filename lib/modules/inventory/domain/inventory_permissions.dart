import 'package:flutter/foundation.dart';

import '../../../security/permissions/access_policy.dart';
import '../../tasks/domain/task_permissions.dart';

/// Quyền Kho hàng (spec TNP_KHO_VA_HANG_SAP_VE §6, `routes.php` của Inventory).
abstract final class InventoryPermissions {
  static const read = 'inventory.read';
  static const write = 'inventory.write';
  static const reserve = 'inventory.reserve';
  static const cost = 'inventory.cost';
  static const lotPayments = 'inventory.lot_payments';

  /// Sửa hồ sơ nhà cung cấp (Kho chuẩn hóa Đợt A).
  static const suppliers = 'inventory.suppliers';

  /// Tạo đơn từ cây (`POST /orders/from-units`) cần thêm quyền ghi đơn.
  static const ordersWrite = 'orders.write';

  /// Khả năng API (`/auth/context` → `api_capabilities`). Thiếu = API cũ chưa
  /// có Kho: ẩn mọi lối vào, không gọi request nào.
  static const capability = 'inventory';

  /// Kho chuẩn hóa Đợt A — mỗi phần một capability riêng: API trước đợt A
  /// không có endpoint (gọi là 404), thiếu tên thì ẩn phần đó.
  static const capLocations = 'inventory.locations';
  static const capSuppliers = 'inventory.suppliers';
  static const capClaims = 'inventory.claims';
  static const capPhotos = 'inventory.photos';

  /// Thiết lập Kho: sửa mã hàng, tên bậc giá, đặt số thật (Đợt B).
  static const settings = 'inventory.settings';

  /// Kho chuẩn hóa Đợt B (TNP_KHO_DOT_B_C §1.5): loại + mã hàng, tồn theo số
  /// lượng (và dòng đơn số lượng), phiếu giữ hàng.
  static const capProducts = 'inventory.products';
  static const capStockQty = 'inventory.stock_qty';
  static const capReservations = 'inventory.reservations';

  /// Menu và route cùng một yêu cầu — deep link không lách được lớp ẩn.
  static const List<String> readOnly = [read];

  static const List<String> all = [
    read,
    write,
    reserve,
    cost,
    lotPayments,
    suppliers,
  ];
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
    this.workshop = false,
    this.locations = false,
    this.suppliers = false,
    this.editSuppliers = false,
    this.claims = false,
    this.photos = false,
    this.products = false,
    this.editProducts = false,
    this.stockQty = false,
    this.adjustStock = false,
    this.reservations = false,
  });

  /// [supports]: API có capability tên này không (`Session.apiSupports`).
  factory InventoryPerms.from({
    required bool capable,
    required AccessPolicy policy,
    bool Function(String capability)? supports,
  }) {
    bool has(String slug) => capable && policy.can(slug);
    bool api(String cap) => capable && (supports?.call(cap) ?? false);
    final read = has(InventoryPermissions.read);
    final capSuppliers = read && api(InventoryPermissions.capSuppliers);
    final products = read && api(InventoryPermissions.capProducts);
    final stockQty = products && api(InventoryPermissions.capStockQty);
    final settings = has(InventoryPermissions.settings);
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
      workshop: read && policy.can(TaskPermissions.write),
      locations: read && api(InventoryPermissions.capLocations),
      suppliers: capSuppliers,
      editSuppliers: capSuppliers && has(InventoryPermissions.suppliers),
      claims: read && api(InventoryPermissions.capClaims),
      photos: read && api(InventoryPermissions.capPhotos),
      products: products,
      editProducts: products && settings,
      stockQty: stockQty,
      adjustStock: stockQty && settings,
      reservations: read && api(InventoryPermissions.capReservations),
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

  /// Đưa cây vào xưởng (`POST /tasks/from-units`): quyền tạo việc
  /// (`tasks.write`) cộng xem Kho. Server kiểm thêm quyền quản lý kế hoạch.
  final bool workshop;

  /// Đợt A: API có vị trí / chuyển cây / thẻ kho (`inventory.locations`).
  final bool locations;

  /// Đợt A: API có màn Nhà cung cấp (`inventory.suppliers`) — đọc.
  final bool suppliers;

  /// Sửa hồ sơ nhà cung cấp: capability + quyền `inventory.suppliers`.
  final bool editSuppliers;

  /// Đợt A: khoản đòi cây thiếu / lỗi và tổng ¥ dự kiến (`inventory.claims`).
  final bool claims;

  /// Đợt A: ảnh và nhãn lỗi của cây (`inventory.photos`).
  final bool photos;

  /// Đợt B: Danh mục hàng (loại, mã hàng, bậc giá) — `inventory.products`.
  final bool products;

  /// Sửa tên / giá mã hàng: thêm quyền `inventory.settings`.
  final bool editProducts;

  /// Đợt B: tồn theo số lượng + dòng đơn số lượng (`inventory.stock_qty`).
  /// Nhập / chuyển cần thêm [write].
  final bool stockQty;

  /// Đặt số thật sau kiểm đếm: `inventory.settings`.
  final bool adjustStock;

  /// Đợt B: phiếu giữ hàng, ngày nhận cọc, nguồn tiền, hạn giữ
  /// (`inventory.reservations`).
  final bool reservations;

  /// Mở được sheet "Bán / Đặt trước".
  bool get canSellOrReserve => reserve || sell;
}
