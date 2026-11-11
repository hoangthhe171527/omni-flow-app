import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../security/session/session_controller.dart';
import '../../plans/application/plans_providers.dart';
import '../../tasks/application/tasks_providers.dart';
import '../data/inventory_api.dart';
import '../domain/inventory_format.dart';
import '../domain/inventory_models.dart';
import '../domain/inventory_permissions.dart';

export '../data/inventory_api.dart'
    show
        AddUnitsResult,
        InventoryApi,
        MoveResult,
        SendToWorkshopResult,
        UnitUpdateResult,
        inventoryApiProvider;

/// Quyền Kho của phiên hiện tại. Thiếu capability `inventory` → mọi quyền false.
final inventoryPermsProvider = Provider<InventoryPerms>((ref) {
  final session = ref.watch(sessionProvider);
  return InventoryPerms.from(
    capable: session.apiSupports(InventoryPermissions.capability),
    policy: session.policy,
    supports: session.apiSupports,
  );
});

/// Ngày hôm nay — override trong test để tuổi tồn cố định.
final inventoryTodayProvider = Provider<DateTime>((ref) => DateTime.now());

/// Tăng sau mỗi lần ghi (giữ hàng, nhận hàng, thêm cây, khoản trả…) — mọi
/// provider đọc dữ liệu Kho theo dõi số này nên tải lại cùng lúc, không màn
/// nào còn số cũ.
final inventoryRevisionProvider = StateProvider<int>((ref) => 0);

void bumpInventory(WidgetRef ref) =>
    ref.read(inventoryRevisionProvider.notifier).state++;

/// Dữ liệu cây đổi vì Kho ghi ([inventoryRevisionProvider]) HOẶC vì một việc
/// xưởng đổi trạng thái ([unitWorkRevisionProvider] — server đổi tình trạng cây
/// theo việc). Mọi provider đọc cây theo dõi qua đây.
void _watchUnits(Ref ref) {
  ref.watch(inventoryRevisionProvider);
  ref.watch(unitWorkRevisionProvider);
}

/// Kế hoạch đưa cây vào được: đang chạy và người này quản lý được (như web —
/// server trả 403 cho kế hoạch không quản lý được).
typedef WorkshopPlan = ({String id, String name});

final workshopPlansProvider = FutureProvider.autoDispose<List<WorkshopPlan>>((
  ref,
) async {
  if (!ref.watch(inventoryPermsProvider).workshop) return const [];
  final manageAll = ref.watch(taskAccessProvider).isAssigner;
  final me = ref.watch(sessionProvider.select((s) => s.user?.id));
  final teams = await ref.watch(teamsWithPlansProvider.future);
  return [
    for (final t in teams)
      // `plans` chỉ gồm kế hoạch đang chạy (đã đóng / lưu trữ nằm riêng).
      for (final p in t.plans)
        if (manageAll || (me != null && p.roleOf(me).canManagePlan))
          (id: p.id, name: p.name),
  ];
});

// ---------------------------------------------------------------- tồn kho

/// `missing` = cây "Không thấy" sau kiểm kê (mọi trạng thái bán) — API chỉ trả
/// chúng khi lọc `condition=missing` (capability `inventory.found`).
enum StockSegment { available, reserved, missing }

/// Tham số `sale` / `condition` của `GET /units` cho từng phân đoạn.
({String? sale, String? condition}) _segmentQuery(
  StockSegment seg,
) => switch (seg) {
  StockSegment.available => (sale: UnitSale.available.wire, condition: null),
  StockSegment.reserved => (sale: heldSaleWire, condition: null),
  StockSegment.missing => (sale: null, condition: UnitCondition.missing.wire),
};

@immutable
class StockFilter {
  const StockFilter({
    this.segment = StockSegment.available,
    this.query = '',
    this.category,
    this.lotId,
    this.lotCode,
    this.age,
    this.locationId,
    this.locationName,
  });

  final StockSegment segment;
  final String query;
  final String? category;
  final String? lotId;
  final String? lotCode;
  final AgeBucket? age;

  /// Lọc vị trí — chỉ khi tenant có từ hai vị trí (Đợt A).
  final String? locationId;
  final String? locationName;

  bool get narrowed =>
      query.trim().isNotEmpty ||
      category != null ||
      lotId != null ||
      age != null ||
      locationId != null;

  StockFilter copyWith({
    StockSegment? segment,
    String? query,
    ValueGetter<String?>? category,
    ValueGetter<String?>? lotId,
    ValueGetter<String?>? lotCode,
    ValueGetter<AgeBucket?>? age,
    ValueGetter<String?>? locationId,
    ValueGetter<String?>? locationName,
  }) => StockFilter(
    segment: segment ?? this.segment,
    query: query ?? this.query,
    category: category != null ? category() : this.category,
    lotId: lotId != null ? lotId() : this.lotId,
    lotCode: lotCode != null ? lotCode() : this.lotCode,
    age: age != null ? age() : this.age,
    locationId: locationId != null ? locationId() : this.locationId,
    locationName: locationName != null ? locationName() : this.locationName,
  );
}

final stockFilterProvider = StateProvider.autoDispose<StockFilter>(
  (ref) => const StockFilter(),
);

@immutable
class StockState {
  const StockState({
    required this.items,
    required this.total,
    this.loadingMore = false,
  });

  final List<InventoryUnit> items;

  /// `meta.total` của API — tổng cây khớp bộ lọc máy chủ.
  final int total;
  final bool loadingMore;

  bool get hasMore => items.length < total;

  StockState copyWith({
    List<InventoryUnit>? items,
    int? total,
    bool? loadingMore,
  }) => StockState(
    items: items ?? this.items,
    total: total ?? this.total,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

/// "Đã có khách" = đang giữ HOẶC đã vào đơn mà chưa giao (như web). Chỉ gửi
/// `reserved` thì cây vừa tạo đơn biến mất khỏi cả hai tab.
final heldSaleWire = '${UnitSale.reserved.wire},${UnitSale.sold.wire}';

class StockController extends AutoDisposeAsyncNotifier<StockState> {
  static const pageSize = 50;

  Future<UnitPage> _fetch(StockFilter f, int offset) => ref
      .read(inventoryApiProvider)
      .listUnits(
        place: UnitPlace.inStock.wire,
        sale: _segmentQuery(f.segment).sale,
        condition: _segmentQuery(f.segment).condition,
        category: f.category,
        lotId: f.lotId,
        locationId: f.locationId,
        q: f.query.trim().isEmpty ? null : f.query.trim(),
        limit: pageSize,
        offset: offset,
      );

  @override
  Future<StockState> build() async {
    _watchUnits(ref);
    final f = ref.watch(stockFilterProvider);
    if (!ref.watch(inventoryPermsProvider).read) {
      return const StockState(items: [], total: 0);
    }
    final page = await _fetch(f, 0);
    return StockState(items: page.items, total: page.total);
  }

  Future<void> loadMore() async {
    final cur = state.valueOrNull;
    if (cur == null || cur.loadingMore || !cur.hasMore) return;
    state = AsyncData(cur.copyWith(loadingMore: true));
    try {
      final page = await _fetch(
        ref.read(stockFilterProvider),
        cur.items.length,
      );
      // Trong lúc chờ, bộ lọc đổi (danh sách đã tải lại): bỏ trang này, không
      // dán cây của bộ lọc cũ vào danh sách mới.
      final now = state.valueOrNull;
      if (now == null || !identical(now.items, cur.items)) {
        if (now != null && now.loadingMore) {
          state = AsyncData(now.copyWith(loadingMore: false));
        }
        return;
      }
      final seen = {for (final u in cur.items) u.id};
      state = AsyncData(
        cur.copyWith(
          items: [
            ...cur.items,
            ...page.items.where((u) => !seen.contains(u.id)),
          ],
          total: page.total,
          loadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncData(cur.copyWith(loadingMore: false));
      rethrow;
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  /// Thay cây vừa sửa tại chỗ (serial, tình trạng, giá) — không tải lại cả
  /// danh sách, không mất vị trí cuộn. Cây không còn khớp phân đoạn thì rút.
  void patch(Iterable<InventoryUnit> changed) {
    final cur = state.valueOrNull;
    if (cur == null) return;
    final seg = ref.read(stockFilterProvider).segment;
    final byId = {for (final u in changed) u.id: u};
    var removed = 0;
    final next = <InventoryUnit>[];
    for (final u in cur.items) {
      final c = byId[u.id];
      if (c == null) {
        next.add(u);
        continue;
      }
      final lost = c.condition == UnitCondition.missing;
      final keep =
          c.place == UnitPlace.inStock &&
          switch (seg) {
            StockSegment.available => !lost && c.sale == UnitSale.available,
            StockSegment.reserved => !lost && c.sale == UnitSale.reserved,
            StockSegment.missing => lost,
          };
      if (keep) {
        next.add(c);
      } else {
        removed++;
      }
    }
    state = AsyncData(cur.copyWith(items: next, total: cur.total - removed));
  }
}

final stockProvider =
    AutoDisposeAsyncNotifierProvider<StockController, StockState>(
      StockController.new,
    );

/// Số cây trong kho theo trạng thái bán (`limit: 1`, chỉ đọc `meta.total`).
final stockCountProvider = FutureProvider.autoDispose.family<int, StockSegment>(
  (ref, seg) async {
    ref.watch(inventoryRevisionProvider);
    final perms = ref.watch(inventoryPermsProvider);
    if (!perms.read || (seg == StockSegment.missing && !perms.missing)) {
      return 0;
    }
    final q = _segmentQuery(seg);
    final page = await ref
        .watch(inventoryApiProvider)
        .listUnits(
          place: UnitPlace.inStock.wire,
          sale: q.sale,
          condition: q.condition,
          limit: 1,
        );
    return page.total;
  },
);

// ------------------------------------------------- vị trí, ảnh, thẻ kho (Đợt A)

/// Tenant có từ hai vị trí (`GET /units/summary` → `multi_location`): chỉ khi
/// đó mới có lọc vị trí, chọn nơi nhận, chuyển cây (spec §5). API thiếu
/// capability `inventory.locations` → false, không gọi request.
final multiLocationProvider = FutureProvider.autoDispose<bool>((ref) async {
  ref.watch(inventoryRevisionProvider);
  if (!ref.watch(inventoryPermsProvider).locations) return false;
  final s = await ref.watch(inventoryApiProvider).stockSummary();
  return s.multiLocation;
});

/// Vị trí đang dùng (chưa lưu trữ), mặc định đứng đầu.
final locationsProvider = FutureProvider.autoDispose<List<StockLocation>>((
  ref,
) async {
  ref.watch(inventoryRevisionProvider);
  if (!ref.watch(inventoryPermsProvider).locations) return const [];
  final all = await ref.watch(inventoryApiProvider).listLocations();
  return [
    for (final l in all)
      if (!l.archived && l.isDefault) l,
    for (final l in all)
      if (!l.archived && !l.isDefault) l,
  ];
});

/// Thẻ kho của một cây.
final unitLedgerProvider = FutureProvider.autoDispose
    .family<List<LedgerRow>, String>((ref, id) async {
      _watchUnits(ref);
      if (!ref.watch(inventoryPermsProvider).locations) return const [];
      return ref.watch(inventoryApiProvider).unitLedger(id);
    });

/// Ảnh của một cây (ảnh kho + ảnh thợ chụp trong việc xưởng).
final unitPhotosProvider = FutureProvider.autoDispose
    .family<List<UnitPhoto>, String>((ref, id) async {
      _watchUnits(ref);
      if (!ref.watch(inventoryPermsProvider).photos) return const [];
      return ref.watch(inventoryApiProvider).unitPhotos(id);
    });

/// Nhãn lỗi của tenant (chưa thiết lập thì API trả sáu nhãn mặc định).
final defectTagsProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  if (!ref.watch(inventoryPermsProvider).photos) return const [];
  return ref.watch(inventoryApiProvider).defectTags();
});

// ---------------------------------------------------------------- lô

final lotsProvider = FutureProvider.autoDispose<List<Lot>>((ref) async {
  ref.watch(inventoryRevisionProvider);
  if (!ref.watch(inventoryPermsProvider).read) return const [];
  return ref.watch(inventoryApiProvider).listLots();
});

final lotProvider = FutureProvider.autoDispose.family<Lot, String>((
  ref,
  id,
) async {
  ref.watch(inventoryRevisionProvider);
  return ref.watch(inventoryApiProvider).getLot(id);
});

final lotUnitsProvider = FutureProvider.autoDispose
    .family<List<InventoryUnit>, String>((ref, id) async {
      _watchUnits(ref);
      return ref.watch(inventoryApiProvider).lotUnits(id);
    });

/// Nhà cung cấp (cho "Tạo lô").
final suppliersProvider = FutureProvider.autoDispose<List<Supplier>>((
  ref,
) async {
  ref.watch(inventoryRevisionProvider);
  if (!ref.watch(inventoryPermsProvider).read) return const [];
  return ref.watch(inventoryApiProvider).listSuppliers();
});

/// Hồ sơ nhà cung cấp (màn Nhà cung cấp, Đợt A).
final supplierDetailsProvider =
    FutureProvider.autoDispose<List<SupplierDetail>>((ref) async {
      ref.watch(inventoryRevisionProvider);
      if (!ref.watch(inventoryPermsProvider).suppliers) return const [];
      return ref.watch(inventoryApiProvider).listSupplierDetails();
    });

final supplierProvider = FutureProvider.autoDispose
    .family<SupplierDetail, String>((ref, id) async {
      ref.watch(inventoryRevisionProvider);
      return ref.watch(inventoryApiProvider).getSupplier(id);
    });

final moneyAccountsProvider = FutureProvider.autoDispose<List<MoneyAccount>>((
  ref,
) async {
  if (!ref.watch(inventoryPermsProvider).pay) return const [];
  return ref.watch(inventoryApiProvider).moneyAccounts();
});

// ------------------------------------- Đợt B: danh mục, hàng số lượng, giữ

/// Bậc giá đang dùng (có tên). API thiếu `inventory.products` → rỗng (ẩn
/// chọn bậc giá).
final priceTiersProvider = FutureProvider.autoDispose<List<PriceTier>>((
  ref,
) async {
  ref.watch(inventoryRevisionProvider);
  if (!ref.watch(inventoryPermsProvider).products) return const [];
  return PriceTier.active(await ref.watch(inventoryApiProvider).priceTiers());
});

/// Loại hàng (cả đã lưu trữ — lọc ở chỗ dùng qua [categoryTree]).
final categoriesProvider = FutureProvider.autoDispose<List<InvCategory>>((
  ref,
) async {
  ref.watch(inventoryRevisionProvider);
  if (!ref.watch(inventoryPermsProvider).products) return const [];
  return ref.watch(inventoryApiProvider).listCategories();
});

/// Bộ lọc màn Danh mục hàng.
typedef CatalogFilter = ({String? categoryId, String query});

final catalogFilterProvider = StateProvider.autoDispose<CatalogFilter>(
  (ref) => (categoryId: null, query: ''),
);

/// Mã hàng theo bộ lọc của Danh mục hàng.
final productsProvider = FutureProvider.autoDispose<List<InvProduct>>((
  ref,
) async {
  _watchUnits(ref);
  if (!ref.watch(inventoryPermsProvider).products) return const [];
  final f = ref.watch(catalogFilterProvider);
  final q = f.query.trim();
  return ref
      .watch(inventoryApiProvider)
      .listProducts(categoryId: f.categoryId, q: q.isEmpty ? null : q);
});

/// Hàng số lượng bán được (cho "Thêm hàng số lượng" trong sheet bán).
final qtyProductsProvider = FutureProvider.autoDispose<List<InvProduct>>((
  ref,
) async {
  ref.watch(inventoryRevisionProvider);
  if (!ref.watch(inventoryPermsProvider).stockQty) return const [];
  return ref
      .watch(inventoryApiProvider)
      .listProducts(tracking: ProductTracking.qty);
});

/// Phiếu giữ hàng theo trạng thái (null = tất cả).
final reservationsProvider = FutureProvider.autoDispose
    .family<List<Reservation>, ReservationStatus?>((ref, status) async {
      _watchUnits(ref);
      if (!ref.watch(inventoryPermsProvider).reservations) return const [];
      return ref.watch(inventoryApiProvider).listReservations(status: status);
    });

/// Đơn còn mở của khách (cho "Thêm vào đơn đang mở").
final openOrdersProvider = FutureProvider.autoDispose
    .family<List<OpenOrder>, String>((ref, customerId) async {
      if (!ref.watch(inventoryPermsProvider).sell) return const [];
      return ref.watch(inventoryApiProvider).openOrders(customerId);
    });

final customerSearchProvider = FutureProvider.autoDispose
    .family<List<InventoryCustomer>, String>((ref, q) async {
      return ref.watch(inventoryApiProvider).searchCustomers(q);
    });

// ------------------------------- Đợt C: hàng đã giao, kiểm kê, phiếu xuất

/// Bộ lọc Hàng đã giao: chữ tìm (serial, model, khách) + số cây đã tải.
typedef DeliveredQuery = ({String q, int limit});

/// Cây đã giao cho khách, mới giao trước (`GET /units?place=delivered`).
final deliveredProvider = FutureProvider.autoDispose
    .family<UnitPage, DeliveredQuery>((ref, f) async {
      _watchUnits(ref);
      if (!ref.watch(inventoryPermsProvider).delivered) {
        return const UnitPage(items: [], total: 0);
      }
      final q = f.q.trim();
      return ref
          .watch(inventoryApiProvider)
          .listUnits(
            place: UnitPlace.delivered.wire,
            q: q.isEmpty ? null : q,
            limit: f.limit,
          );
    });

/// Phiên kiểm kê của một vị trí, mới nhất trước.
final countsProvider = FutureProvider.autoDispose
    .family<List<StockCount>, String>((ref, locationId) async {
      ref.watch(inventoryRevisionProvider);
      if (!ref.watch(inventoryPermsProvider).counts) return const [];
      return ref.watch(inventoryApiProvider).listCounts(locationId: locationId);
    });

/// Cây theo sổ ở một vị trí (để tick khi kiểm kê).
final countUnitsProvider = FutureProvider.autoDispose
    .family<List<InventoryUnit>, String>((ref, locationId) async {
      _watchUnits(ref);
      if (!ref.watch(inventoryPermsProvider).counts) return const [];
      return ref.watch(inventoryApiProvider).countUnits(locationId);
    });

/// Phiếu xuất theo số phiếu.
final slipProvider = FutureProvider.autoDispose.family<Slip, String>((
  ref,
  no,
) async {
  return ref.watch(inventoryApiProvider).getSlip(no);
});
