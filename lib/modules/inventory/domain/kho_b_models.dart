import 'package:flutter/foundation.dart';

import '../../../core/utils/json.dart';

/// Kiểu Kho chuẩn hóa Đợt B — đúng hình dạng `InventoryPresenter::product`,
/// `::reservation`, `CategoryController`, `InventorySettingsController`
/// (omni-flow-api PR #100, `docs/TNP_KHO_DOT_B_C.md` §1, §1.5).
///
/// Thêm trường ở đây phải thêm đủ ở `fromJson` + body của `InventoryApi`.

/// Bậc giá của mã hàng — thứ tự cố định như API.
enum PriceTierKey {
  wholesale('wholesale'),
  retail('retail'),
  tier3('tier3');

  const PriceTierKey(this.wire);
  final String wire;

  static PriceTierKey? parse(String? raw) {
    for (final k in values) {
      if (k.wire == raw) return k;
    }
    return null;
  }
}

/// Tên một bậc giá (`inv_settings.price_tiers`). `name == null` = bậc ẩn.
@immutable
class PriceTier {
  const PriceTier({required this.key, this.name});

  factory PriceTier.fromJson(Map<String, dynamic> j) =>
      PriceTier(key: PriceTierKey.parse(j.str('key'))!, name: j.str('name'));

  final PriceTierKey key;
  final String? name;

  /// Bậc mặc định khi API chưa có `price_tiers` (như web `activeTiers`).
  static const defaults = [
    PriceTier(key: PriceTierKey.wholesale, name: 'Giá sỉ'),
    PriceTier(key: PriceTierKey.retail, name: 'Giá lẻ'),
  ];

  /// Bậc đang dùng (có tên), đúng thứ tự cố định.
  static List<PriceTier> active(List<PriceTier>? tiers) {
    final list = tiers ?? defaults;
    return [
      for (final k in PriceTierKey.values)
        if (list.where((t) => t.key == k).firstOrNull case final t?)
          if ((t.name ?? '').trim().isNotEmpty) t,
    ];
  }

  /// Đọc `price_tiers` của `GET /inventory/settings`; khoá lạ bị bỏ.
  static List<PriceTier> listFrom(Map<String, dynamic> settings) => [
    for (final t in settings.mapList('price_tiers'))
      if (PriceTierKey.parse(t.str('key')) != null) PriceTier.fromJson(t),
  ];
}

/// Loại hàng (`GET /inventory/categories` — danh sách phẳng, cả đã lưu trữ).
@immutable
class InvCategory {
  const InvCategory({
    required this.id,
    required this.name,
    this.parentId,
    this.order = 0,
    this.archived = false,
  });

  factory InvCategory.fromJson(Map<String, dynamic> j) => InvCategory(
    id: j.strOr('id', ''),
    name: j.strOr('name', ''),
    parentId: j.str('parent_id'),
    order: j.intOr('order'),
    archived: j.str('archived_at') != null,
  );

  final String id;
  final String name;
  final String? parentId;
  final int order;
  final bool archived;
}

/// Một nút cây loại hàng theo thứ tự hiển thị, kèm đường dẫn tên cha.
typedef CategoryNode = ({InvCategory category, int depth, String path});

/// Cây loại hàng (cha rồi con, theo `order` rồi tên) — như web `categoryTree`.
/// Cha đã lưu trữ / không còn: đưa con lên gốc để loại con không biến mất.
List<CategoryNode> categoryTree(List<InvCategory> list) {
  final shown = [
    for (final c in list)
      if (!c.archived) c,
  ];
  final ids = {for (final c in shown) c.id};
  final byParent = <String?, List<InvCategory>>{};
  for (final c in shown) {
    final p = c.parentId != null && ids.contains(c.parentId)
        ? c.parentId
        : null;
    byParent.putIfAbsent(p, () => []).add(c);
  }
  final out = <CategoryNode>[];
  void walk(String? parent, int depth, String prefix) {
    final kids = [...?byParent[parent]]
      ..sort((a, b) {
        final o = a.order.compareTo(b.order);
        return o != 0 ? o : a.name.compareTo(b.name);
      });
    for (final c in kids) {
      final path = prefix.isEmpty ? c.name : '$prefix / ${c.name}';
      out.add((category: c, depth: depth, path: path));
      walk(c.id, depth + 1, path);
    }
  }

  walk(null, 0, '');
  return out;
}

enum ProductTracking {
  serial('serial'),
  qty('qty');

  const ProductTracking(this.wire);
  final String wire;

  static ProductTracking parse(String? raw) =>
      raw == 'qty' ? ProductTracking.qty : ProductTracking.serial;
}

/// Tồn của hàng số lượng ở một vị trí.
typedef LocationQty = ({String locationId, int qty});

/// Mã hàng (`InventoryPresenter::product`).
@immutable
class InvProduct {
  const InvProduct({
    required this.id,
    required this.code,
    required this.name,
    this.categoryId,
    this.categoryName,
    this.unit,
    this.tracking = ProductTracking.serial,
    this.prices = const {},
    this.fixedCost,
    this.archived = false,
    this.onHand = 0,
    this.available = 0,
    this.stock = const [],
  });

  factory InvProduct.fromJson(Map<String, dynamic> j) {
    final p = j.child('prices');
    return InvProduct(
      id: j.strOr('id', ''),
      code: j.strOr('code', ''),
      name: j.strOr('name', ''),
      categoryId: j.str('category_id'),
      categoryName: j.str('category_name'),
      unit: j.str('unit'),
      tracking: ProductTracking.parse(j.str('tracking')),
      prices: {for (final k in PriceTierKey.values) k: ?p.dbl(k.wire)},
      fixedCost: j.dbl('fixed_cost'),
      archived: j.str('archived_at') != null,
      onHand: j.intOr('on_hand'),
      available: j.intOr('available'),
      stock: [
        for (final s in j.mapList('stock'))
          (locationId: s.strOr('location_id', ''), qty: s.intOr('qty')),
      ],
    );
  }

  final String id;
  final String code;
  final String name;
  final String? categoryId;
  final String? categoryName;

  /// Đơn vị tính (Chiếc, Bộ…).
  final String? unit;
  final ProductTracking tracking;

  /// Giá theo bậc; bậc chưa có giá thì không có khoá.
  final Map<PriceTierKey, double> prices;

  /// Giá vốn ghim (chỉ với `inventory.cost`).
  final double? fixedCost;
  final bool archived;
  final int onHand;
  final int available;

  /// Tồn theo vị trí — chỉ hàng số lượng.
  final List<LocationQty> stock;

  bool get isQty => tracking == ProductTracking.qty;

  String get unitLabel => (unit ?? '').trim().isEmpty ? 'cái' : unit!.trim();

  double? priceOf(PriceTierKey k) => prices[k];

  int qtyAt(String locationId) =>
      stock.where((s) => s.locationId == locationId).firstOrNull?.qty ?? 0;
}

enum ReservationStatus {
  active('active', 'Đang giữ'),
  ordered('ordered', 'Đã vào đơn'),
  released('released', 'Đã bỏ giữ');

  const ReservationStatus(this.wire, this.label);
  final String wire;
  final String label;

  static ReservationStatus parse(String? raw) => values.firstWhere(
    (s) => s.wire == raw,
    orElse: () => ReservationStatus.active,
  );
}

/// Một cây trên phiếu giữ hàng.
@immutable
class ReservationLine {
  const ReservationLine({
    required this.unitId,
    this.label,
    this.serial,
    this.price,
  });

  factory ReservationLine.fromJson(Map<String, dynamic> j) => ReservationLine(
    unitId: j.strOr('unit_id', ''),
    label: j.str('label'),
    serial: j.str('serial'),
    price: j.dbl('price'),
  );

  final String unitId;
  final String? label;
  final String? serial;
  final double? price;
}

/// Cọc trên phiếu giữ: số, ngày nhận (Y-m-d), nguồn tiền.
@immutable
class ReservationDeposit {
  const ReservationDeposit({
    required this.amount,
    this.paidAt,
    this.moneyAccountId,
  });

  final double amount;
  final String? paidAt;
  final String? moneyAccountId;
}

/// Phiếu giữ hàng (`InventoryPresenter::reservation`).
@immutable
class Reservation {
  const Reservation({
    required this.id,
    this.status = ReservationStatus.active,
    this.customerId,
    this.customerName,
    this.lines = const [],
    this.total = 0,
    this.deposit,
    this.expiresAt,
    this.orderId,
    this.note,
    this.createdAt,
    this.releasedAt,
  });

  factory Reservation.fromJson(Map<String, dynamic> j) {
    final d = j['deposit'] is Map ? j.child('deposit') : null;
    return Reservation(
      id: j.strOr('id', ''),
      status: ReservationStatus.parse(j.str('status')),
      customerId: j.str('customer_id'),
      customerName: j.str('customer_name'),
      lines: [for (final l in j.mapList('units')) ReservationLine.fromJson(l)],
      total: j.dbl('total') ?? 0,
      deposit: d == null
          ? null
          : ReservationDeposit(
              amount: d.dbl('amount') ?? 0,
              paidAt: d.str('paid_at'),
              moneyAccountId: d.str('money_account_id'),
            ),
      expiresAt: j.str('expires_at'),
      orderId: j.str('order_id'),
      note: j.str('note'),
      createdAt: j.str('created_at'),
      releasedAt: j.str('released_at'),
    );
  }

  final String id;
  final ReservationStatus status;
  final String? customerId;
  final String? customerName;
  final List<ReservationLine> lines;
  final double total;
  final ReservationDeposit? deposit;

  /// Hạn giữ (Y-m-d) — chỉ để hiện, API chưa tự bỏ giữ.
  final String? expiresAt;
  final String? orderId;
  final String? note;
  final String? createdAt;
  final String? releasedAt;

  /// Hạn giữ đã qua (so theo ngày) khi phiếu còn đang giữ.
  bool expiredOn(DateTime today) {
    final e = DateTime.tryParse(expiresAt ?? '');
    if (e == null || status != ReservationStatus.active) return false;
    return DateTime(
      e.year,
      e.month,
      e.day,
    ).isBefore(DateTime(today.year, today.month, today.day));
  }
}

/// Một dòng hàng số lượng gửi kèm `POST /orders/from-units` (`items[]`).
@immutable
class SellItem {
  const SellItem({required this.productId, required this.qty, this.price});

  final String productId;
  final int qty;

  /// null = API lấy giá lẻ của mã hàng.
  final num? price;

  Map<String, Object?> toPayload() => {
    'product_id': productId,
    'qty': qty,
    'price': ?price,
  };
}
