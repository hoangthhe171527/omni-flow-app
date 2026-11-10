import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/modules/inventory/application/inventory_providers.dart';
import 'package:omni_app/modules/inventory/domain/inventory_models.dart';
import 'package:omni_app/modules/inventory/domain/receive.dart';

/// API Kho giả cho widget test: dữ liệu trong bộ nhớ, ghi lại mọi lần ghi.
class FakeInventoryApi extends InventoryApi {
  FakeInventoryApi({
    List<InventoryUnit> units = const [],
    List<InventoryCustomer> customers = const [],
    List<OpenOrder> openOrders = const [],
    List<Lot> lots = const [],
    List<Supplier> suppliers = const [],
    List<MoneyAccount> accounts = const [],
    this.payResult,
    this.workshopSkipped = const [],
    this.multiLocation = false,
    List<StockLocation> locations = const [],
    Map<String, List<UnitPhoto>> photos = const {},
    this.tags = const [],
    Map<String, List<LedgerRow>> ledger = const {},
    List<SupplierDetail> supplierDetails = const [],
  }) : locations = [...locations],
       photos = {
         for (final e in photos.entries) e.key: [...e.value],
       },
       ledger = {...ledger},
       supplierDetails = [...supplierDetails],
       units = [...units],
       customers = [...customers],
       _openOrders = openOrders,
       lots = [...lots],
       suppliers = [...suppliers],
       _accounts = accounts,
       super(ApiClient(Dio()));

  final List<InventoryUnit> units;
  final List<InventoryCustomer> customers;
  final List<OpenOrder> _openOrders;

  final listCalls = <Map<String, Object?>>[];
  final updates = <(String, Map<String, Object?>)>[];
  final reserves = <Map<String, Object?>>[];
  final sells = <Map<String, Object?>>[];
  final created = <(String, String?)>[];

  final List<Lot> lots;
  final List<Supplier> suppliers;
  final List<MoneyAccount> _accounts;

  /// Lô trả về sau `payCosts` (null = lô cũ, chưa chốt).
  final Lot? payResult;

  /// Id cây server bỏ qua khi đưa vào xưởng (đang có việc tân trang mở).
  final List<String> workshopSkipped;
  final workshopSends = <Map<String, Object?>>[];

  // ---- Kho chuẩn hóa Đợt A ----
  final bool multiLocation;
  final List<StockLocation> locations;
  final Map<String, List<UnitPhoto>> photos;
  final List<String> tags;
  final Map<String, List<LedgerRow>> ledger;
  final List<SupplierDetail> supplierDetails;
  final moves = <Map<String, Object?>>[];
  final uploads = <(String, List<({String path, String name})>)>[];
  final deletedPhotos = <(String, String)>[];
  final covers = <(String, String)>[];
  final receives = <Map<String, Object?>>[];
  final claimUpdates = <(String, Map<String, Object?>)>[];
  final supplierUpdates = <(String, Map<String, Object?>)>[];
  final expected = <(String, num?)>[];

  final createdSuppliers = <String>[];
  final createdLots = <Map<String, Object?>>[];
  final pays = <Map<String, Object?>>[];
  final addedUnits = <(String, List<NewUnitInput>)>[];

  @override
  Future<UnitPage> listUnits({
    String? place,
    String? sale,
    String? category,
    String? lotId,
    String? customerId,
    String? locationId,
    String? q,
    int limit = 50,
    int offset = 0,
  }) async {
    listCalls.add({
      'place': place,
      'sale': sale,
      'q': q,
      'limit': limit,
      'location_id': locationId,
    });
    final all = [
      for (final u in units)
        if ((sale == null || sale.split(',').contains(u.sale.wire)) &&
            (locationId == null || u.locationId == locationId) &&
            (q == null ||
                '${u.maker} ${u.model} ${u.serial ?? ''}'
                    .toLowerCase()
                    .contains(q.toLowerCase())))
          u,
    ];
    return UnitPage(
      items: all.skip(offset).take(limit).toList(),
      total: all.length,
    );
  }

  @override
  Future<SendToWorkshopResult> sendToWorkshop({
    required String projectId,
    required List<String> unitIds,
  }) async {
    workshopSends.add({'project_id': projectId, 'unit_ids': unitIds});
    final skipped = [
      for (final id in unitIds)
        if (workshopSkipped.contains(id)) id,
    ];
    return (created: unitIds.length - skipped.length, skipped: skipped);
  }

  @override
  Future<List<Lot>> listLots() async => lots;

  @override
  Future<Lot> getLot(String id) async => lots.firstWhere((l) => l.id == id);

  @override
  Future<List<InventoryUnit>> lotUnits(String id) async => [
    for (final u in units)
      if (u.lotId == id) u,
  ];

  @override
  Future<List<Supplier>> listSuppliers() async => suppliers;

  @override
  Future<Supplier> createSupplier(String name) async {
    createdSuppliers.add(name);
    final s = Supplier(id: 'sup-new', name: name);
    suppliers.add(s);
    return s;
  }

  @override
  Future<Lot> createLot({
    required String code,
    String? supplierId,
    String? orderedAt,
    String? eta,
    double? rate,
    bool feesFromPrevious = true,
  }) async {
    createdLots.add({
      'code': code,
      'supplier_id': supplierId,
      'ordered_at': orderedAt,
      'eta': eta,
      'rate': rate,
      'fees_from_previous': feesFromPrevious,
    });
    final l = Lot(id: 'lot-new', code: code, supplierId: supplierId);
    lots.insert(0, l);
    return l;
  }

  @override
  Future<AddUnitsResult> addUnits(
    String lotId,
    List<NewUnitInput> units,
  ) async {
    addedUnits.add((lotId, units));
    return (
      lot: lots.firstWhere((l) => l.id == lotId),
      created: units.length,
      warnings: const <SerialWarning>[],
    );
  }

  @override
  Future<Lot> payCosts(
    String lotId, {
    required List<String> costIds,
    required String paidAt,
    String? moneyAccountId,
    Map<String, num>? amounts,
  }) async {
    pays.add({
      'lot_id': lotId,
      'cost_ids': costIds,
      'paid_at': paidAt,
      'money_account_id': moneyAccountId,
      'amounts': amounts,
    });
    return payResult ?? lots.firstWhere((l) => l.id == lotId);
  }

  @override
  Future<List<MoneyAccount>> moneyAccounts() async => _accounts;

  @override
  Future<UnitUpdateResult> updateUnit(
    String id,
    Map<String, Object?> fields,
  ) async {
    updates.add((id, fields));
    final i = units.indexWhere((u) => u.id == id);
    final old = units[i];
    final next = copyUnit(
      old,
      serial: fields.containsKey('serial')
          ? () => fields['serial'] as String?
          : null,
      note: fields.containsKey('note') ? () => fields['note'] as String? : null,
      defectTags: fields.containsKey('defect_tags')
          ? [...fields['defect_tags']! as List<String>]
          : null,
      place: fields['place'] == 'delivered' ? UnitPlace.delivered : null,
    );
    units[i] = next;
    return (unit: next, warnings: const <SerialWarning>[]);
  }

  @override
  Future<List<InventoryUnit>> reserve({
    required List<String> unitIds,
    String? customerId,
    bool retail = false,
    Map<String, num>? prices,
    num? deposit,
    String? note,
    String? depositPaidAt,
    String? moneyAccountId,
    String? expiresAt,
  }) async {
    reserves.add({
      'unit_ids': unitIds,
      'customer_id': customerId,
      'retail': retail,
      'prices': prices,
      'deposit': deposit,
      // Đợt B: chỉ ghi khi có — bài cũ so khớp cả map vẫn đúng.
      'deposit_paid_at': ?depositPaidAt,
      'money_account_id': ?moneyAccountId,
      'expires_at': ?expiresAt,
    });
    return const [];
  }

  @override
  Future<({String id, String code})> sell({
    required String customerId,
    required List<String> unitIds,
    Map<String, num>? prices,
    String? orderId,
    num? deposit,
    List<SellItem> items = const [],
  }) async {
    sells.add({
      'customer_id': customerId,
      'unit_ids': unitIds,
      'prices': prices,
      'order_id': orderId,
      if (items.isNotEmpty) 'items': [for (final i in items) i.toPayload()],
    });
    return (id: 'o1', code: 'DH-1043');
  }

  // ---------------- Kho chuẩn hóa Đợt B ----------------

  List<PriceTier> tiers = const [
    PriceTier(key: PriceTierKey.wholesale, name: 'Giá sỉ'),
    PriceTier(key: PriceTierKey.retail, name: 'Giá lẻ'),
    PriceTier(key: PriceTierKey.tier3),
  ];
  List<InvCategory> categories = const [];
  List<InvProduct> products = [];
  List<Reservation> reservations = const [];
  final productUpdates = <(String, String?, Map<PriceTierKey, num?>?)>[];
  final stockWrites = <(String, Map<String, Object?>)>[];
  final productQueries = <Map<String, Object?>>[];
  final reservationQueries = <ReservationStatus?>[];

  @override
  Future<List<PriceTier>> priceTiers() async => tiers;

  @override
  Future<List<InvCategory>> listCategories() async => categories;

  @override
  Future<List<InvProduct>> listProducts({
    String? categoryId,
    String? q,
    ProductTracking? tracking,
    int limit = 500,
  }) async {
    productQueries.add({
      'category_id': categoryId,
      'q': q,
      'tracking': tracking,
    });
    return [
      for (final p in products)
        if ((tracking == null || p.tracking == tracking) &&
            (categoryId == null || p.categoryId == categoryId) &&
            (q == null ||
                '${p.code} ${p.name}'.toLowerCase().contains(q.toLowerCase())))
          p,
    ];
  }

  InvProduct _replace(String id, InvProduct Function(InvProduct) f) {
    final i = products.indexWhere((p) => p.id == id);
    products[i] = f(products[i]);
    return products[i];
  }

  @override
  Future<InvProduct> updateProduct(
    String id, {
    String? name,
    Map<PriceTierKey, num?>? prices,
  }) async {
    productUpdates.add((id, name, prices));
    return _replace(
      id,
      (p) => copyProduct(
        p,
        name: name,
        // Bậc không gửi giữ giá cũ; gửi null là xoá (như API).
        prices: prices == null
            ? null
            : {
                for (final e in p.prices.entries)
                  if (!prices.containsKey(e.key)) e.key: e.value,
                for (final e in prices.entries)
                  if (e.value != null) e.key: e.value!.toDouble(),
              },
      ),
    );
  }

  @override
  Future<InvProduct> receiveStock({
    required String productId,
    required int qty,
    String? locationId,
    num? unitCost,
    String? note,
  }) async {
    stockWrites.add((
      'receive',
      {
        'product_id': productId,
        'qty': qty,
        'location_id': locationId,
        'unit_cost': unitCost,
      },
    ));
    return _replace(productId, (p) => copyProduct(p, onHand: p.onHand + qty));
  }

  @override
  Future<InvProduct> transferStock({
    required String productId,
    required String from,
    required String to,
    required int qty,
  }) async {
    stockWrites.add((
      'transfer',
      {'product_id': productId, 'from': from, 'to': to, 'qty': qty},
    ));
    return _replace(
      productId,
      (p) => copyProduct(
        p,
        stock: [
          for (final s in p.stock)
            (
              locationId: s.locationId,
              qty: s.locationId == from
                  ? s.qty - qty
                  : s.locationId == to
                  ? s.qty + qty
                  : s.qty,
            ),
          if (!p.stock.any((s) => s.locationId == to))
            (locationId: to, qty: qty),
        ],
      ),
    );
  }

  @override
  Future<({InvProduct product, int delta})> adjustStock({
    required String productId,
    required String locationId,
    required int qty,
    required String note,
  }) async {
    stockWrites.add((
      'adjust',
      {
        'product_id': productId,
        'location_id': locationId,
        'qty': qty,
        'note': note,
      },
    ));
    final old = products.firstWhere((p) => p.id == productId);
    final delta = qty - old.qtyAt(locationId);
    final next = _replace(
      productId,
      (p) => copyProduct(p, onHand: p.onHand + delta),
    );
    return (product: next, delta: delta);
  }

  @override
  Future<List<Reservation>> listReservations({
    ReservationStatus? status,
    int limit = 100,
  }) async {
    reservationQueries.add(status);
    return [
      for (final r in reservations)
        if (status == null || r.status == status) r,
    ];
  }

  @override
  Future<InventoryUnit> getUnit(String id) async =>
      units.firstWhere((u) => u.id == id);

  @override
  Future<List<OpenOrder>> openOrders(String customerId) async => _openOrders;

  // ---------------- Kho chuẩn hóa Đợt A ----------------

  @override
  Future<StockSummary> stockSummary() async =>
      StockSummary(multiLocation: multiLocation);

  @override
  Future<List<StockLocation>> listLocations() async => locations;

  @override
  Future<MoveResult> moveUnits({
    required List<String> unitIds,
    required String toLocationId,
  }) async {
    moves.add({'unit_ids': unitIds, 'to_location_id': toLocationId});
    final to = locations.firstWhere((l) => l.id == toLocationId);
    var moved = 0;
    for (var i = 0; i < units.length; i++) {
      final u = units[i];
      if (!unitIds.contains(u.id) || u.locationId == to.id) continue;
      units[i] = copyUnit(u, locationId: to.id, locationName: to.name);
      moved++;
    }
    return (
      units: [
        for (final u in units)
          if (unitIds.contains(u.id)) u,
      ],
      moved: moved,
      skipped: unitIds.length - moved,
    );
  }

  @override
  Future<List<LedgerRow>> unitLedger(String id) async => ledger[id] ?? const [];

  @override
  Future<List<UnitPhoto>> unitPhotos(String id) async => photos[id] ?? const [];

  @override
  Future<List<UnitPhoto>> uploadPhotos(
    String id,
    List<({String path, String name})> files,
  ) async {
    uploads.add((id, files));
    final list = photos.putIfAbsent(id, () => []);
    for (final f in files) {
      list.add(
        UnitPhoto(
          id: 'p${list.length + 1}',
          url: 'https://x.test/${f.name}',
          isCover: list.isEmpty,
        ),
      );
    }
    return list;
  }

  @override
  Future<List<UnitPhoto>> deletePhoto(String id, String photoId) async {
    deletedPhotos.add((id, photoId));
    photos[id]?.removeWhere((p) => p.id == photoId);
    return photos[id] ?? const [];
  }

  @override
  Future<List<UnitPhoto>> setCover(String id, String photoId) async {
    covers.add((id, photoId));
    photos[id] = [
      for (final p in photos[id] ?? const <UnitPhoto>[])
        UnitPhoto(
          id: p.id,
          url: p.url,
          fromTask: p.fromTask,
          isCover: p.id == photoId,
        ),
    ];
    return photos[id]!;
  }

  @override
  Future<List<String>> defectTags() async => tags;

  @override
  Future<({Lot lot, Map<String, int> counts})> receive(
    String lotId, {
    required String receivedAt,
    UnitCondition? condition,
    required List<ReceiveLine> results,
    String? locationId,
  }) async {
    receives.add({
      'lot_id': lotId,
      'received_at': receivedAt,
      'results': [for (final r in results) r.toPayload()],
      'location_id': locationId,
    });
    return (
      lot: lots.firstWhere((l) => l.id == lotId),
      counts: const {'ok': 0},
    );
  }

  @override
  Future<LotClaim> updateClaim(String id, ClaimInput input) async {
    claimUpdates.add((id, input.toPayload()));
    for (var i = 0; i < lots.length; i++) {
      final l = lots[i];
      final claims = l.claims;
      if (claims == null || !claims.any((c) => c.id == id)) continue;
      lots[i] = copyLot(
        l,
        claims: [
          for (final c in claims)
            c.id == id
                ? LotClaim(
                    id: c.id,
                    lotId: c.lotId,
                    unitId: c.unitId,
                    missing: c.missing,
                    resolution: input.resolution,
                    settled: input.settled,
                    amountJpy: input.amountJpy?.toDouble() ?? c.amountJpy,
                  )
                : c,
        ],
      );
    }
    return lots
        .expand((l) => l.claims ?? const <LotClaim>[])
        .firstWhere((c) => c.id == id);
  }

  @override
  Future<Lot> setExpectedJpy(String id, num? yen) async {
    expected.add((id, yen));
    final i = lots.indexWhere((l) => l.id == id);
    lots[i] = copyLot(lots[i], expectedJpy: yen?.toDouble());
    return lots[i];
  }

  @override
  Future<List<SupplierDetail>> listSupplierDetails() async => supplierDetails;

  @override
  Future<SupplierDetail> getSupplier(String id) async =>
      supplierDetails.firstWhere((s) => s.id == id);

  @override
  Future<SupplierDetail> updateSupplier(String id, SupplierInput input) async {
    final body = input.toPayload();
    supplierUpdates.add((id, body));
    final i = supplierDetails.indexWhere((s) => s.id == id);
    final old = supplierDetails[i];
    // Đọc lại như API: thân đã gửi + khoá chỉ đọc (mã, nợ).
    final next = SupplierDetail.fromJson({
      ...body,
      'id': old.id,
      'code': old.code,
      'debt_jpy': old.debtJpy,
      'overdue_jpy': old.overdueJpy,
      'prepaid_jpy': old.prepaidJpy,
      'open_lots': old.openLots,
    });
    supplierDetails[i] = next;
    return next;
  }

  @override
  Future<List<InventoryCustomer>> searchCustomers(String search) async {
    final q = search.trim().toLowerCase();
    return [
      for (final c in customers)
        if (q.isEmpty || c.name.toLowerCase().contains(q)) c,
    ];
  }

  @override
  Future<InventoryCustomer?> customerByPhone(String phone) async => null;

  @override
  Future<InventoryCustomer> createCustomer({
    required String name,
    String? phone,
  }) async {
    created.add((name, phone));
    final c = InventoryCustomer(id: 'new1', name: name, phone: phone ?? '');
    customers.add(c);
    return c;
  }
}

/// Bản sao cây với vài trường đổi — giữ mọi trường khác (API trả cả cây).
InventoryUnit copyUnit(
  InventoryUnit u, {
  ValueGetter<String?>? serial,
  ValueGetter<String?>? note,
  List<String>? defectTags,
  UnitPlace? place,
  String? locationId,
  String? locationName,
}) => InventoryUnit(
  id: u.id,
  lotId: u.lotId,
  lotCode: u.lotCode,
  lineNo: u.lineNo,
  category: u.category,
  maker: u.maker,
  model: u.model,
  serial: serial != null ? serial() : u.serial,
  color: u.color,
  listPrice: u.listPrice,
  place: place ?? u.place,
  condition: u.condition,
  sale: u.sale,
  retailHold: u.retailHold,
  customerId: u.customerId,
  customerName: u.customerName,
  reservedPrice: u.reservedPrice,
  orderId: u.orderId,
  receivedAt: u.receivedAt,
  note: note != null ? note() : u.note,
  yenPrice: u.yenPrice,
  costVnd: u.costVnd,
  workshop: u.workshop,
  locationId: locationId ?? u.locationId,
  locationName: locationName ?? u.locationName,
  defectTags: defectTags ?? u.defectTags,
  photoCount: u.photoCount,
  coverUrl: u.coverUrl,
);

/// Bản sao mã hàng với vài trường đổi.
InvProduct copyProduct(
  InvProduct p, {
  String? name,
  Map<PriceTierKey, double>? prices,
  int? onHand,
  List<LocationQty>? stock,
}) {
  final nextStock = stock ?? p.stock;
  return InvProduct(
    id: p.id,
    code: p.code,
    name: name ?? p.name,
    categoryId: p.categoryId,
    categoryName: p.categoryName,
    unit: p.unit,
    tracking: p.tracking,
    prices: prices ?? p.prices,
    fixedCost: p.fixedCost,
    archived: p.archived,
    onHand:
        onHand ??
        (stock == null ? p.onHand : nextStock.fold(0, (s, x) => s + x.qty)),
    available: onHand ?? p.available,
    stock: nextStock,
  );
}

/// Bản sao lô (các trường test dùng).
Lot copyLot(Lot l, {List<LotClaim>? claims, double? expectedJpy}) => Lot(
  id: l.id,
  code: l.code,
  supplierId: l.supplierId,
  supplierName: l.supplierName,
  status: l.status,
  receivedAt: l.receivedAt,
  units: l.units,
  inStock: l.inStock,
  costFinal: l.costFinal,
  rateApplied: l.rateApplied,
  costTotal: l.costTotal,
  dueJpy: l.dueJpy,
  costs: l.costs,
  expectedJpy: expectedJpy ?? l.expectedJpy,
  debtBaseJpy: l.debtBaseJpy,
  prepaidJpy: l.prepaidJpy,
  claims: claims ?? l.claims,
);
