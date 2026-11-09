import 'package:dio/dio.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/modules/inventory/application/inventory_providers.dart';
import 'package:omni_app/modules/inventory/domain/inventory_models.dart';

/// API Kho giả cho widget test: dữ liệu trong bộ nhớ, ghi lại mọi lần ghi.
class FakeInventoryApi extends InventoryApi {
  FakeInventoryApi({
    List<InventoryUnit> units = const [],
    List<InventoryCustomer> customers = const [],
    List<OpenOrder> openOrders = const [],
  }) : units = [...units],
       customers = [...customers],
       _openOrders = openOrders,
       super(ApiClient(Dio()));

  final List<InventoryUnit> units;
  final List<InventoryCustomer> customers;
  final List<OpenOrder> _openOrders;

  final listCalls = <Map<String, Object?>>[];
  final updates = <(String, Map<String, Object?>)>[];
  final reserves = <Map<String, Object?>>[];
  final sells = <Map<String, Object?>>[];
  final created = <(String, String?)>[];

  @override
  Future<UnitPage> listUnits({
    String? place,
    String? sale,
    String? category,
    String? lotId,
    String? customerId,
    String? q,
    int limit = 50,
    int offset = 0,
  }) async {
    listCalls.add({'place': place, 'sale': sale, 'q': q, 'limit': limit});
    final all = [
      for (final u in units)
        if ((sale == null || u.sale.wire == sale) &&
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
  Future<List<Lot>> listLots() async => const [];

  @override
  Future<UnitUpdateResult> updateUnit(
    String id,
    Map<String, Object?> fields,
  ) async {
    updates.add((id, fields));
    final i = units.indexWhere((u) => u.id == id);
    final old = units[i];
    final next = InventoryUnit(
      id: old.id,
      lotId: old.lotId,
      lotCode: old.lotCode,
      maker: old.maker,
      model: old.model,
      serial: fields.containsKey('serial')
          ? fields['serial'] as String?
          : old.serial,
      listPrice: old.listPrice,
      place: old.place,
      condition: old.condition,
      sale: old.sale,
      category: old.category,
      receivedAt: old.receivedAt,
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
  }) async {
    reserves.add({
      'unit_ids': unitIds,
      'customer_id': customerId,
      'retail': retail,
      'prices': prices,
      'deposit': deposit,
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
  }) async {
    sells.add({
      'customer_id': customerId,
      'unit_ids': unitIds,
      'prices': prices,
      'order_id': orderId,
    });
    return (id: 'o1', code: 'DH-1043');
  }

  @override
  Future<List<OpenOrder>> openOrders(String customerId) async => _openOrders;

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
