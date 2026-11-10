import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/utils/json.dart';
import '../../customers/customers.dart';
import '../domain/inventory_format.dart';
import '../domain/inventory_models.dart';

final inventoryApiProvider = Provider<InventoryApi>((ref) {
  return InventoryApi(ref.watch(apiClientProvider));
});

/// Kết quả `PUT /units/{id}` — cây sau khi sửa + cảnh báo serial trùng.
typedef UnitUpdateResult = ({InventoryUnit unit, List<SerialWarning> warnings});

/// Kết quả `POST /tasks/from-units`: số việc đã tạo và id các cây bị bỏ qua
/// (đang có việc tân trang chưa xong).
typedef SendToWorkshopResult = ({int created, List<String> skipped});

/// Kết quả `POST /lots/{id}/units`.
typedef AddUnitsResult = ({Lot lot, int created, List<SerialWarning> warnings});

/// Client `/inventory/*` (capability `inventory`) + `POST /orders/from-units`
/// + tìm / tạo nhanh khách cho luồng bán. Đường dẫn tương đối với `/api/v1`.
///
/// Body ghi đúng tên khoá của controller API (`UnitController`,
/// `LotController`, `OrderController::fromUnits`).
class InventoryApi {
  InventoryApi(this._api);

  final ApiClient _api;

  static String _e(String id) => Uri.encodeComponent(id);

  static List<SerialWarning> _warnings(ApiEnvelope res) {
    final meta = res.raw['meta'];
    if (meta is! Map) return const [];
    return [
      for (final w in meta.cast<String, dynamic>().mapList('warnings'))
        SerialWarning.fromJson(w),
    ];
  }

  // ---------------- tồn kho ----------------

  /// `GET /inventory/units` — mặc định (không `place`/`lot_id`/`customer_id`)
  /// API trả hàng đang trong kho.
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
    final res = await _api.get(
      '/inventory/units',
      query: {
        'place': place,
        'sale': sale,
        'category': category,
        'lot_id': lotId,
        'customer_id': customerId,
        'q': q,
        'limit': limit,
        'offset': offset,
      },
    );
    final meta = res.raw['meta'];
    return UnitPage(
      items: res.list.map(InventoryUnit.fromJson).toList(),
      total: meta is Map
          ? meta.cast<String, dynamic>().intOr('total')
          : res.list.length,
    );
  }

  Future<InventoryUnit> getUnit(String id) async {
    final res = await _api.get('/inventory/units/${_e(id)}');
    return InventoryUnit.fromJson(res.object);
  }

  /// `PUT /inventory/units/{id}` — chỉ gửi khoá có trong [fields] (`serial`,
  /// `condition`, `list_price`, `yen_price`, `color`, `category`, `note`,
  /// `place`). Giá trị null = xoá.
  Future<UnitUpdateResult> updateUnit(
    String id,
    Map<String, Object?> fields,
  ) async {
    final res = await _api.put('/inventory/units/${_e(id)}', body: fields);
    return (unit: InventoryUnit.fromJson(res.object), warnings: _warnings(res));
  }

  /// `POST /inventory/units/reserve` — giữ / đặt trước cho khách, hoặc "Để
  /// bán lẻ" (`retail: true`, không khách). Cọc ghi vào cây đầu tiên.
  Future<List<InventoryUnit>> reserve({
    required List<String> unitIds,
    String? customerId,
    bool retail = false,
    Map<String, num>? prices,
    num? deposit,
    String? note,
  }) async {
    final res = await _api.post(
      '/inventory/units/reserve',
      body: {
        'unit_ids': unitIds,
        if (retail) 'retail': true,
        if (!retail) 'customer_id': customerId,
        if (prices != null && prices.isNotEmpty) 'prices': prices,
        if (!retail && deposit != null) 'deposit': deposit,
        'note': ?note,
      },
    );
    return res.list.map(InventoryUnit.fromJson).toList();
  }

  /// `POST /inventory/units/release` — bỏ giữ.
  Future<List<InventoryUnit>> release(List<String> unitIds) async {
    final res = await _api.post(
      '/inventory/units/release',
      body: {'unit_ids': unitIds},
    );
    return res.list.map(InventoryUnit.fromJson).toList();
  }

  // ---------------- nhà cung cấp ----------------

  Future<List<Supplier>> listSuppliers() async {
    final res = await _api.get('/inventory/suppliers');
    return res.list.map(Supplier.fromJson).toList();
  }

  /// `POST /inventory/suppliers` — mã (tối đa 30 ký tự) + tên đầy đủ.
  Future<Supplier> createSupplier(String name) async {
    final n = name.trim();
    final res = await _api.post(
      '/inventory/suppliers',
      body: {'code': n.length > 30 ? n.substring(0, 30).trim() : n, 'name': n},
    );
    return Supplier.fromJson(res.object);
  }

  // ---------------- lô ----------------

  /// `POST /inventory/lots` — lô mới ở trạng thái Đã đặt hàng. [rate] chỉ có
  /// tác dụng với quyền thanh toán lô; `fees_from_previous` chép thuế phí dự
  /// kiến của lô trước cùng nhà cung cấp.
  Future<Lot> createLot({
    required String code,
    String? supplierId,
    String? orderedAt,
    String? eta,
    double? rate,
    bool feesFromPrevious = true,
  }) async {
    final res = await _api.post(
      '/inventory/lots',
      body: {
        'code': code.trim(),
        'supplier_id': supplierId,
        'ordered_at': orderedAt,
        'eta': eta,
        'rate': ?rate,
        'fees_from_previous': feesFromPrevious,
      },
    );
    return Lot.fromJson(res.object);
  }

  Future<List<Lot>> listLots() async {
    final res = await _api.get('/inventory/lots');
    return res.list.map(Lot.fromJson).toList();
  }

  Future<Lot> getLot(String id) async {
    final res = await _api.get('/inventory/lots/${_e(id)}');
    return Lot.fromJson(res.object);
  }

  Future<List<InventoryUnit>> lotUnits(String id) async {
    final res = await _api.get('/inventory/lots/${_e(id)}/units');
    return res.list.map(InventoryUnit.fromJson).toList();
  }

  Future<AddUnitsResult> addUnits(
    String lotId,
    List<NewUnitInput> units,
  ) async {
    final res = await _api.post(
      '/inventory/lots/${_e(lotId)}/units',
      body: {'units': units.map((u) => u.toPayload()).toList()},
    );
    final meta = res.raw['meta'];
    return (
      lot: Lot.fromJson(res.object),
      created: meta is Map ? meta.cast<String, dynamic>().intOr('created') : 0,
      warnings: _warnings(res),
    );
  }

  /// `POST /inventory/lots/{id}/receive` — mặc định mọi cây "Đã nhận"; chỉ gửi
  /// cây thiếu / lỗi hoặc có serial bổ sung.
  Future<({Lot lot, Map<String, int> counts})> receive(
    String lotId, {
    required String receivedAt,
    UnitCondition? condition,
    required List<({String unitId, ReceiveResult result, String? serial})>
    results,
  }) async {
    final res = await _api.post(
      '/inventory/lots/${_e(lotId)}/receive',
      body: {
        'received_at': receivedAt,
        'condition': condition?.wire,
        'results': [
          for (final r in results)
            {'unit_id': r.unitId, 'result': r.result.wire, 'serial': ?r.serial},
        ],
      },
    );
    final meta = res.raw['meta'];
    return (
      lot: Lot.fromJson(res.object),
      counts: meta is Map
          ? meta.cast<String, dynamic>().countMap('counts')
          : const <String, int>{},
    );
  }

  /// `PUT /inventory/lots/{id}/rate` — số = sửa tay; null = dùng ước tính.
  Future<Lot> setRate(String lotId, num? rate) async {
    final res = await _api.put(
      '/inventory/lots/${_e(lotId)}/rate',
      body: {'rate': rate},
    );
    return Lot.fromJson(res.object);
  }

  Future<Lot> addCost(String lotId, CostInput input) async {
    final res = await _api.post(
      '/inventory/lots/${_e(lotId)}/costs',
      body: input.toPayload(),
    );
    return Lot.fromJson(res.object);
  }

  Future<Lot> updateCost(String costId, CostInput input) async {
    final res = await _api.put(
      '/inventory/lot-costs/${_e(costId)}',
      body: input.toPayload(),
    );
    return Lot.fromJson(res.object);
  }

  Future<Lot> deleteCost(String costId) async {
    final res = await _api.delete('/inventory/lot-costs/${_e(costId)}');
    return Lot.fromJson(res.object);
  }

  /// `POST /inventory/lots/{id}/costs/pay` — ghi đã trả nhiều khoản dự kiến
  /// cùng ngày, cùng nguồn tiền. [amounts]: số ₫ từng khoản (id → ₫).
  Future<Lot> payCosts(
    String lotId, {
    required List<String> costIds,
    required String paidAt,
    String? moneyAccountId,
    Map<String, num>? amounts,
  }) async {
    final res = await _api.post(
      '/inventory/lots/${_e(lotId)}/costs/pay',
      body: {
        'cost_ids': costIds,
        'paid_at': paidAt,
        'money_account_id': moneyAccountId,
        if (amounts != null && amounts.isNotEmpty) 'amounts': amounts,
      },
    );
    return Lot.fromJson(res.object);
  }

  Future<List<MoneyAccount>> moneyAccounts() async {
    final res = await _api.get('/inventory/money-accounts');
    return res.list.map(MoneyAccount.fromJson).toList();
  }

  // ---------------- xưởng ----------------

  /// `POST /tasks/from-units` `{project_id, unit_ids[]}` — đưa cây vào xưởng:
  /// mỗi cây một việc của kế hoạch (`TaskUnitController::fromUnits`). 201
  /// `{data: việc[], meta: {created, skipped}}`; 403 không quản lý được kế
  /// hoạch; 404 cây không còn.
  ///
  /// Gọi từ tầng data của Kho (như web) thay vì qua `TasksApi`: Kho chỉ cần
  /// hai con số trong `meta`, không cần kiểu `Task`.
  Future<SendToWorkshopResult> sendToWorkshop({
    required String projectId,
    required List<String> unitIds,
  }) async {
    final res = await _api.post(
      '/tasks/from-units',
      body: {'project_id': projectId, 'unit_ids': unitIds},
    );
    final meta = res.raw['meta'];
    final m = meta is Map
        ? meta.cast<String, dynamic>()
        : const <String, dynamic>{};
    return (
      // Thiếu `meta.created` (không nên xảy ra) thì đếm mảng việc trả về.
      created: m['created'] == null ? res.list.length : m.intOr('created'),
      skipped: m.strList('skipped'),
    );
  }

  // ---------------- bán ----------------

  /// `POST /orders/from-units` — tạo đơn mới cho khách, hoặc thêm vào đơn đang
  /// mở ([orderId]). Trả mã đơn.
  Future<({String id, String code})> sell({
    required String customerId,
    required List<String> unitIds,
    Map<String, num>? prices,
    String? orderId,
    num? deposit,
  }) async {
    final res = await _api.post(
      '/orders/from-units',
      body: {
        'customer_id': customerId,
        'unit_ids': unitIds,
        if (prices != null && prices.isNotEmpty) 'prices': prices,
        'order_id': ?orderId,
        if (deposit != null && deposit > 0) 'deposit': deposit,
      },
    );
    final o = res.object;
    return (id: o.strOr('id', ''), code: o.str('code') ?? o.strOr('id', ''));
  }

  /// Đơn còn mở (chưa huỷ / hoàn tất) của một khách.
  Future<List<OpenOrder>> openOrders(String customerId) async {
    final res = await _api.get(
      '/orders',
      query: {'customer_id': customerId, 'per_page': 20},
    );
    return [
      for (final o in res.list)
        if (o.str('status') != 'cancelled' && o.str('status') != 'completed')
          OpenOrder(
            id: o.strOr('id', ''),
            code: o.str('code') ?? o.strOr('id', ''),
            value: o.dbl('value') ?? 0,
          ),
    ];
  }

  /// Tìm khách theo tên / SĐT (`GET /customers?search=`).
  Future<List<InventoryCustomer>> searchCustomers(String search) async {
    final res = await _api.get(
      '/customers',
      query: {'search': search.trim(), 'page': 1, 'per_page': 6},
    );
    return [
      for (final row in res.list)
        if (Customer.fromJson(row) case final c)
          InventoryCustomer(id: c.id, name: c.name, phone: c.phone),
    ];
  }

  /// Khách đã có SĐT này (`GET /customers/check-duplicate`) — null nếu chưa
  /// có hoặc hồ sơ thuộc người khác (không mở được).
  Future<InventoryCustomer?> customerByPhone(String phone) async {
    if (InventoryFormat.digits(phone).length < 6) return null;
    final res = await _api.get(
      '/customers/check-duplicate',
      query: {'phone': phone.trim()},
    );
    final data = res.data;
    final match = data is List
        ? (data.isEmpty ? null : (data.first as Map).cast<String, dynamic>())
        : res.object;
    if (match == null || match.isEmpty || match['in_scope'] == false) {
      return null;
    }
    final id = match.str('id');
    if (id == null) return null;
    return InventoryCustomer(
      id: id,
      name: match.str('display_name') ?? match.strOr('legal_name', 'Khách'),
      phone: match.strOr('primary_contact_phone', phone.trim()),
    );
  }

  /// Tạo nhanh khách lẻ (`POST /customers`, `DIRECT_CLIENT`).
  Future<InventoryCustomer> createCustomer({
    required String name,
    String? phone,
  }) async {
    final n = name.trim();
    final p = phone?.trim() ?? '';
    final res = await _api.post(
      '/customers',
      body: {
        'legal_name': n,
        'display_name': n,
        'customer_type': 'DIRECT_CLIENT',
        'primary_contact_name': n,
        if (p.isNotEmpty) 'primary_contact_phone': p,
      },
    );
    final c = Customer.fromJson(res.object);
    return InventoryCustomer(
      id: c.id,
      name: c.name.isEmpty ? n : c.name,
      phone: c.phone.isEmpty ? p : c.phone,
    );
  }
}
