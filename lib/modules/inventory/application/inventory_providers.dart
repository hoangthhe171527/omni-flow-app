import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../security/session/session_controller.dart';
import '../data/inventory_api.dart';
import '../domain/inventory_format.dart';
import '../domain/inventory_models.dart';
import '../domain/inventory_permissions.dart';

export '../data/inventory_api.dart'
    show AddUnitsResult, InventoryApi, UnitUpdateResult, inventoryApiProvider;

/// Quyền Kho của phiên hiện tại. Thiếu capability `inventory` → mọi quyền false.
final inventoryPermsProvider = Provider<InventoryPerms>((ref) {
  final session = ref.watch(sessionProvider);
  return InventoryPerms.from(
    capable: session.apiSupports(InventoryPermissions.capability),
    policy: session.policy,
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

// ---------------------------------------------------------------- tồn kho

enum StockSegment { available, reserved }

@immutable
class StockFilter {
  const StockFilter({
    this.segment = StockSegment.available,
    this.query = '',
    this.category,
    this.lotId,
    this.lotCode,
    this.age,
  });

  final StockSegment segment;
  final String query;
  final String? category;
  final String? lotId;
  final String? lotCode;
  final AgeBucket? age;

  bool get narrowed =>
      query.trim().isNotEmpty ||
      category != null ||
      lotId != null ||
      age != null;

  StockFilter copyWith({
    StockSegment? segment,
    String? query,
    ValueGetter<String?>? category,
    ValueGetter<String?>? lotId,
    ValueGetter<String?>? lotCode,
    ValueGetter<AgeBucket?>? age,
  }) => StockFilter(
    segment: segment ?? this.segment,
    query: query ?? this.query,
    category: category != null ? category() : this.category,
    lotId: lotId != null ? lotId() : this.lotId,
    lotCode: lotCode != null ? lotCode() : this.lotCode,
    age: age != null ? age() : this.age,
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

class StockController extends AutoDisposeAsyncNotifier<StockState> {
  static const pageSize = 50;

  Future<UnitPage> _fetch(StockFilter f, int offset) => ref
      .read(inventoryApiProvider)
      .listUnits(
        place: UnitPlace.inStock.wire,
        sale: f.segment == StockSegment.available
            ? UnitSale.available.wire
            : UnitSale.reserved.wire,
        category: f.category,
        lotId: f.lotId,
        q: f.query.trim().isEmpty ? null : f.query.trim(),
        limit: pageSize,
        offset: offset,
      );

  @override
  Future<StockState> build() async {
    ref.watch(inventoryRevisionProvider);
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
      final keep =
          c.place == UnitPlace.inStock &&
          (seg == StockSegment.available
              ? c.sale == UnitSale.available
              : c.sale == UnitSale.reserved);
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
    if (!ref.watch(inventoryPermsProvider).read) return 0;
    final page = await ref
        .watch(inventoryApiProvider)
        .listUnits(
          place: UnitPlace.inStock.wire,
          sale: seg == StockSegment.available
              ? UnitSale.available.wire
              : UnitSale.reserved.wire,
          limit: 1,
        );
    return page.total;
  },
);

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
      ref.watch(inventoryRevisionProvider);
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

final moneyAccountsProvider = FutureProvider.autoDispose<List<MoneyAccount>>((
  ref,
) async {
  if (!ref.watch(inventoryPermsProvider).pay) return const [];
  return ref.watch(inventoryApiProvider).moneyAccounts();
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
