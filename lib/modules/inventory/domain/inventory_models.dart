import 'package:flutter/foundation.dart';

import '../../../core/utils/json.dart';
import 'kho_models.dart';

export 'kho_models.dart';

/// Kiểu Kho hàng — đúng hình dạng API (`InventoryPresenter`, omni-flow-api PR #90,
/// spec TNP_KHO_VA_HANG_SAP_VE §7b). Trường tiền là `null` khi người xem thiếu
/// quyền (`inventory.cost` / `inventory.lot_payments`): API bỏ hẳn khoá.
///
/// Thêm trường ở đây phải thêm đủ ở `fromJson` + chỗ ghi (`toPayload` / body
/// của `InventoryApi`) — thiếu một chỗ là mất dữ liệu lặng.

enum LotStatus {
  ordered('ordered', 'Đã đặt hàng'),
  inTransit('in_transit', 'Đang về'),
  received('received', 'Đã về kho');

  const LotStatus(this.wire, this.label);

  final String wire;
  final String label;

  static LotStatus parse(String? raw) => switch (raw) {
    'in_transit' => LotStatus.inTransit,
    'received' => LotStatus.received,
    _ => LotStatus.ordered,
  };
}

enum UnitPlace {
  incoming('incoming'),
  inStock('in_stock'),
  delivered('delivered');

  const UnitPlace(this.wire);

  final String wire;

  static UnitPlace parse(String? raw) => switch (raw) {
    'in_stock' => UnitPlace.inStock,
    'delivered' => UnitPlace.delivered,
    _ => UnitPlace.incoming,
  };
}

enum UnitSale {
  available('available'),
  reserved('reserved'),
  sold('sold');

  const UnitSale(this.wire);

  final String wire;

  static UnitSale parse(String? raw) => switch (raw) {
    'reserved' => UnitSale.reserved,
    'sold' => UnitSale.sold,
    _ => UnitSale.available,
  };
}

/// Tình trạng cây. `null` trên dây = "Chưa kiểm".
enum UnitCondition {
  sealed('sealed', 'Nguyên thùng'),
  refurbishing('refurbishing', 'Đang làm'),
  ready('ready', 'Sẵn sàng'),
  defective('defective', 'Lỗi'),
  missing('missing', 'Không thấy');

  const UnitCondition(this.wire, this.label);

  final String wire;
  final String label;

  static const noneLabel = 'Chưa kiểm';

  static UnitCondition? parse(String? raw) {
    for (final c in values) {
      if (c.wire == raw) return c;
    }
    return null;
  }

  static String labelOf(UnitCondition? c) => c?.label ?? noneLabel;

  /// Tình trạng ban đầu khi nhận hàng (API chỉ nhận 3 giá trị này).
  static const receivable = [sealed, refurbishing, ready];
}

/// Loại khoản trả lô (`LotCosting::GOODS_KINDS` + `FEE_KINDS`).
enum CostKind {
  goodsOutside('goods_outside', 'Trả ngoài invoice'),
  goodsInvoice('goods_invoice', 'Tiền hàng theo invoice'),
  importTax('import_tax', 'Thuế nhập khẩu'),
  lcc('lcc', 'Phí LCC'),
  customsOutside('customs_outside', 'Chi ngoài HQ'),
  customsService('customs_service', 'Phí dịch vụ HQ'),
  container('container', 'Phí hạ cont'),
  bankFee('bank_fee', 'Phí thanh toán'),
  other('other', 'Chi phí khác');

  const CostKind(this.wire, this.label);

  final String wire;
  final String label;

  bool get isGoods => this == goodsOutside || this == goodsInvoice;

  static const fees = [
    importTax,
    lcc,
    customsOutside,
    customsService,
    container,
    bankFee,
    other,
  ];

  static CostKind parse(String? raw) {
    for (final k in values) {
      if (k.wire == raw) return k;
    }
    return other;
  }
}

enum CostStatus {
  paid('paid', 'Đã trả'),
  planned('planned', 'Dự kiến');

  const CostStatus(this.wire, this.label);

  final String wire;
  final String label;

  static CostStatus parse(String? raw) =>
      raw == 'planned' ? CostStatus.planned : CostStatus.paid;
}

@immutable
class LotCost {
  const LotCost({
    required this.id,
    required this.lotId,
    required this.kind,
    this.label = '',
    this.amountJpy,
    this.amountVnd,
    this.fx,
    this.status = CostStatus.paid,
    this.paidAt,
    this.moneyAccountId,
    this.note,
  });

  factory LotCost.fromJson(Map<String, dynamic> j) => LotCost(
    id: j.strOr('id', ''),
    lotId: j.strOr('lot_id', ''),
    kind: CostKind.parse(j.str('kind')),
    label: j.strOr('label', ''),
    amountJpy: j.dbl('amount_jpy'),
    amountVnd: j.dbl('amount_vnd'),
    fx: j.dbl('fx'),
    status: CostStatus.parse(j.str('status')),
    paidAt: j.str('paid_at'),
    moneyAccountId: j.str('money_account_id'),
    note: j.str('note'),
  );

  final String id;
  final String lotId;
  final CostKind kind;
  final String label;
  final double? amountJpy;
  final double? amountVnd;
  final double? fx;
  final CostStatus status;
  final String? paidAt;
  final String? moneyAccountId;
  final String? note;

  bool get isGoods => kind.isGoods;

  /// Tên hiển thị: nhãn người nhập, không có thì tên loại.
  String get title => label.trim().isEmpty ? kind.label : label.trim();
}

/// Nội dung ghi một khoản (`POST /lots/{id}/costs`, `PUT /lot-costs/{id}`).
@immutable
class CostInput {
  const CostInput({
    required this.kind,
    required this.status,
    this.label,
    this.amountJpy,
    this.amountVnd,
    this.paidAt,
    this.moneyAccountId,
    this.note,
  });

  final CostKind kind;
  final CostStatus status;
  final String? label;
  final double? amountJpy;
  final double? amountVnd;
  final String? paidAt;
  final String? moneyAccountId;
  final String? note;

  Map<String, dynamic> toPayload() => {
    'kind': kind.wire,
    'status': status.wire,
    'label': label,
    // Thuế & phí không có ¥ — API cũng tự xoá, gửi null cho rõ.
    'amount_jpy': kind.isGoods ? amountJpy : null,
    'amount_vnd': amountVnd,
    'paid_at': status == CostStatus.paid ? paidAt : null,
    'money_account_id': moneyAccountId,
    'note': note,
  };
}

@immutable
class RateLog {
  const RateLog({
    required this.at,
    required this.reason,
    this.from,
    this.to,
    this.units,
    this.deltaVnd,
  });

  factory RateLog.fromJson(Map<String, dynamic> j) => RateLog(
    at: j.strOr('at', ''),
    reason: j.strOr('reason', ''),
    from: j.dbl('from'),
    to: j.dbl('to'),
    units: j['units'] == null ? null : j.intOr('units'),
    deltaVnd: j.dbl('delta_vnd'),
  );

  final String at;
  final String reason;
  final double? from;
  final double? to;
  final int? units;
  final double? deltaVnd;

  String get reasonLabel => switch (reason) {
    'auto_final' => 'Tự chốt giá vốn',
    'provisional_edit' => 'Sửa tỷ lệ tạm',
    'cost_changed' => 'Ước tính lại',
    'units_changed' => 'Thêm cây',
    _ => reason,
  };
}

@immutable
class Lot {
  const Lot({
    required this.id,
    required this.code,
    this.supplierId,
    this.supplierName,
    this.status = LotStatus.ordered,
    this.orderedAt,
    this.eta,
    this.receivedAt,
    this.note,
    this.units = 0,
    this.reserved = 0,
    this.sold = 0,
    this.inStock = 0,
    this.costFinal = false,
    this.plannedCount = 0,
    this.createdAt,
    this.yenTotal,
    this.rateApplied,
    this.rateManual = false,
    this.rateFinal,
    this.rateEstimate,
    this.costTotal,
    this.costFinalAt,
    this.invoiceJpy,
    this.paidVnd,
    this.plannedVnd,
    this.paidJpy,
    this.dueJpy,
    this.lastFx,
    this.costs,
    this.rateLogs,
    this.expectedJpy,
    this.debtBaseJpy,
    this.prepaidJpy,
    this.claims,
  });

  factory Lot.fromJson(Map<String, dynamic> j) => Lot(
    id: j.strOr('id', ''),
    code: j.strOr('code', ''),
    supplierId: j.str('supplier_id'),
    supplierName: j.str('supplier_name'),
    status: LotStatus.parse(j.str('status')),
    orderedAt: j.str('ordered_at'),
    eta: j.str('eta'),
    receivedAt: j.str('received_at'),
    note: j.str('note'),
    units: j.intOr('units'),
    reserved: j.intOr('reserved'),
    sold: j.intOr('sold'),
    inStock: j.intOr('in_stock'),
    costFinal: j.str('cost_state') == 'final',
    plannedCount: j.intOr('planned_count'),
    createdAt: j.str('created_at'),
    yenTotal: j.dbl('yen_total'),
    rateApplied: j.dbl('rate_applied'),
    rateManual: j.flag('rate_manual'),
    rateFinal: j.dbl('rate_final'),
    rateEstimate: j.dbl('rate_estimate'),
    costTotal: j.dbl('cost_total'),
    costFinalAt: j.str('cost_final_at'),
    invoiceJpy: j.dbl('invoice_jpy'),
    paidVnd: j.dbl('paid_vnd'),
    plannedVnd: j.dbl('planned_vnd'),
    paidJpy: j.dbl('paid_jpy'),
    dueJpy: j.dbl('due_jpy'),
    lastFx: j.dbl('last_fx'),
    costs: j['costs'] is List
        ? [for (final c in j.mapList('costs')) LotCost.fromJson(c)]
        : null,
    rateLogs: j['rate_logs'] is List
        ? [for (final r in j.mapList('rate_logs')) RateLog.fromJson(r)]
        : null,
    expectedJpy: j.dbl('expected_jpy'),
    debtBaseJpy: j.dbl('debt_base_jpy'),
    prepaidJpy: j.dbl('prepaid_jpy'),
    // API trước Đợt A không có khoá: null (ẩn nhóm), khác `[]` = chưa có khoản.
    claims: j['claims'] is List
        ? [for (final c in j.mapList('claims')) LotClaim.fromJson(c)]
        : null,
  );

  final String id;
  final String code;
  final String? supplierId;
  final String? supplierName;
  final LotStatus status;
  final String? orderedAt;
  final String? eta;
  final String? receivedAt;
  final String? note;
  final int units;
  final int reserved;
  final int sold;
  final int inStock;

  /// `cost_state == final`: giá vốn đã chốt bằng tỷ lệ thật.
  final bool costFinal;
  final int plannedCount;
  final String? createdAt;

  // ---- chỉ có với `inventory.cost` ----
  final double? yenTotal;
  final double? rateApplied;
  final bool rateManual;
  final double? rateFinal;
  final double? rateEstimate;
  final double? costTotal;
  final String? costFinalAt;

  // ---- chỉ có với `inventory.lot_payments` ----
  final double? invoiceJpy;
  final double? paidVnd;
  final double? plannedVnd;
  final double? paidJpy;
  final double? dueJpy;
  final double? lastFx;
  final List<LotCost>? costs;
  final List<RateLog>? rateLogs;

  // ---- Kho chuẩn hóa Đợt A (API cũ không có khoá → null) ----
  /// Tổng ¥ dự kiến của lô (sửa được khi có quyền thanh toán lô).
  final double? expectedJpy;

  /// Phải trả nhà cung cấp sau khoản được trừ.
  final double? debtBaseJpy;

  /// Trả dư (nợ không âm, phần dư tách ra đây).
  final double? prepaidJpy;

  /// Khoản đòi nhà cung cấp cho cây thiếu / lỗi.
  final List<LotClaim>? claims;

  /// Cây có khách (đặt trước hoặc đã vào đơn) — dùng cho vạch đặt trước.
  int get withCustomer => reserved + sold;

  String get title => supplierName == null || supplierName!.isEmpty
      ? code
      : '$code · $supplierName';
}

/// Một việc xưởng của cây (`workshop[]`, `UnitWork::forUnits` bên API) — Kho
/// đọc từ Công việc lúc trả lời, mới nhất trước.
@immutable
class UnitWork {
  const UnitWork({
    required this.taskId,
    this.title = '',
    this.projectId,
    this.projectName,
    this.role = refurbish,
    this.state = todo,
    this.done = 0,
    this.total = 0,
    this.step,
    this.assigneeNames = const [],
    this.completedAt,
  });

  factory UnitWork.fromJson(Map<String, dynamic> j) => UnitWork(
    taskId: j.strOr('task_id', ''),
    title: j.strOr('title', ''),
    projectId: j.str('project_id'),
    projectName: j.str('project_name'),
    role: j.strOr('role', refurbish),
    state: j.strOr('state', todo),
    done: j.intOr('done'),
    total: j.intOr('total'),
    step: j.str('step'),
    assigneeNames: j.strList('assignee_names'),
    completedAt: j.str('completed_at'),
  );

  static const refurbish = 'refurbish';
  static const warranty = 'warranty';
  static const todo = 'todo';
  static const doing = 'doing';
  static const doneState = 'done';

  final String taskId;
  final String title;
  final String? projectId;
  final String? projectName;

  /// `refurbish` (tân trang) | `warranty` (bảo hành).
  final String role;

  /// `todo` | `doing` | `done` (`WorkState::of`).
  final String state;

  /// Số công đoạn đã xong / tổng.
  final int done;
  final int total;

  /// Công đoạn chưa xong đầu tiên; null khi đã xong hết hoặc không có.
  final String? step;
  final List<String> assigneeNames;
  final String? completedAt;

  bool get isDone => state == doneState;

  /// Việc tân trang chưa xong — cây chỉ có MỘT việc như vậy tại một thời điểm.
  bool get isOpenRefurbish => role == refurbish && !isDone;

  String get roleLabel => role == warranty ? 'Bảo hành' : 'Tân trang';

  /// 0–1 cho vạch tiến độ; việc xong luôn đầy.
  double get progress =>
      isDone ? 1 : (total <= 0 ? 0 : (done / total).clamp(0, 1).toDouble());

  /// "Xong" / "8/10" / "" (việc không có công đoạn).
  String get progressLabel => isDone
      ? 'Xong'
      : total > 0
      ? '$done/$total'
      : '';

  /// "Nắp cong · Thanh Hòa, Ngọc Trâm" / "Đã hoàn thiện".
  String get subtitle => isDone
      ? 'Đã hoàn thiện'
      : [
          ?step,
          if (assigneeNames.isNotEmpty) assigneeNames.join(', '),
        ].join(' · ');
}

@immutable
class InventoryUnit {
  const InventoryUnit({
    required this.id,
    required this.lotId,
    this.lotCode,
    this.lineNo = 0,
    this.category,
    this.maker = '',
    this.model = '',
    this.serial,
    this.color,
    this.size,
    this.listPrice,
    this.place = UnitPlace.incoming,
    this.condition,
    this.sale = UnitSale.available,
    this.retailHold = false,
    this.customerId,
    this.customerName,
    this.reservedPrice,
    this.deposit,
    this.reservedAt,
    this.orderId,
    this.receivedAt,
    this.note,
    this.yenPrice,
    this.costVnd,
    this.workshop,
    this.locationId,
    this.locationName,
    this.locationKind,
    this.deliveredAt,
    this.defectTags,
    this.photoCount,
    this.coverUrl,
  });

  factory InventoryUnit.fromJson(Map<String, dynamic> j) => InventoryUnit(
    id: j.strOr('id', ''),
    lotId: j.strOr('lot_id', ''),
    lotCode: j.str('lot_code'),
    lineNo: j.intOr('line_no'),
    category: j.str('category'),
    maker: j.strOr('maker', ''),
    model: j.strOr('model', ''),
    serial: j.str('serial'),
    color: j.str('color'),
    size: j.str('size'),
    listPrice: j.dbl('list_price'),
    place: UnitPlace.parse(j.str('place')),
    condition: UnitCondition.parse(j.str('condition')),
    sale: UnitSale.parse(j.str('sale')),
    retailHold: j.flag('retail_hold'),
    customerId: j.str('customer_id'),
    customerName: j.str('customer_name'),
    reservedPrice: j.dbl('reserved_price'),
    deposit: j.dbl('deposit'),
    reservedAt: j.str('reserved_at'),
    orderId: j.str('order_id'),
    receivedAt: j.str('received_at'),
    note: j.str('note'),
    yenPrice: j.dbl('yen_price'),
    costVnd: j.dbl('cost_vnd'),
    // API cũ không có khoá: null (ẩn nhóm Xưởng), khác với `[]` = chưa vào xưởng.
    workshop: j['workshop'] is List
        ? [for (final w in j.mapList('workshop')) UnitWork.fromJson(w)]
        : null,
    locationId: j.str('location_id'),
    locationName: j.str('location_name'),
    locationKind: j.str('location_kind'),
    deliveredAt: j.str('delivered_at'),
    // API trước Đợt A không có khoá: null, khác `[]` = chưa gắn nhãn.
    defectTags: j['defect_tags'] is List ? j.strList('defect_tags') : null,
    photoCount: j['photo_count'] == null ? null : j.intOr('photo_count'),
    coverUrl: j.str('cover_url'),
  );

  final String id;
  final String lotId;
  final String? lotCode;
  final int lineNo;
  final String? category;
  final String maker;
  final String model;
  final String? serial;
  final String? color;
  final String? size;
  final double? listPrice;
  final UnitPlace place;
  final UnitCondition? condition;
  final UnitSale sale;
  final bool retailHold;
  final String? customerId;
  final String? customerName;
  final double? reservedPrice;
  final double? deposit;
  final String? reservedAt;
  final String? orderId;
  final String? receivedAt;
  final String? note;

  // ---- chỉ có với `inventory.cost` ----
  final double? yenPrice;
  final double? costVnd;

  /// Việc xưởng của cây, mới nhất trước. null = API chưa có Kho nối Xưởng.
  final List<UnitWork>? workshop;

  // ---- Kho chuẩn hóa Đợt A (API cũ không có khoá → null) ----
  final String? locationId;
  final String? locationName;

  /// `warehouse` | `showroom` | `partner`.
  final String? locationKind;
  final String? deliveredAt;

  /// Nhãn lỗi (trong danh sách `GET /inventory/settings`).
  final List<String>? defectTags;
  final int? photoCount;

  /// Ảnh đại diện (URL công khai `GET /inventory/media/...`).
  final String? coverUrl;

  /// Cây đang có việc tân trang chưa xong — không đưa vào xưởng lần nữa
  /// (server cũng bỏ qua: `CreateWorkshopTasks`).
  bool get hasOpenRefurbish => workshop?.any((w) => w.isOpenRefurbish) ?? false;

  /// Chữ ngắn về xưởng cho dòng cây lúc chọn nhiều: `8/10` (việc tân trang
  /// đang mở), "Xong" (đã tân trang xong), "Chưa vào xưởng". null = API cũ.
  String? get workshopLabel {
    final list = workshop;
    if (list == null) return null;
    for (final w in list) {
      if (w.isOpenRefurbish) {
        return w.total > 0 ? w.progressLabel : 'Ở xưởng';
      }
    }
    return list.any((w) => w.role == UnitWork.refurbish)
        ? 'Xong'
        : 'Chưa vào xưởng';
  }

  String get name => '$maker $model'.trim();

  /// Giá đề xuất khi bán: giá đã chốt lúc giữ, không thì giá niêm yết.
  double get suggestedPrice => reservedPrice ?? listPrice ?? 0;

  bool get hasCustomer => sale != UnitSale.available;
}

@immutable
class Supplier {
  const Supplier({required this.id, required this.name});

  factory Supplier.fromJson(Map<String, dynamic> j) => Supplier(
    id: j.strOr('id', ''),
    name: j.str('name') ?? j.strOr('code', ''),
  );

  final String id;
  final String name;
}

@immutable
class MoneyAccount {
  const MoneyAccount({required this.id, required this.name});

  factory MoneyAccount.fromJson(Map<String, dynamic> j) =>
      MoneyAccount(id: j.strOr('id', ''), name: j.strOr('name', ''));

  final String id;
  final String name;
}

/// Khách rút gọn cho luồng bán (id + tên + SĐT).
@immutable
class InventoryCustomer {
  const InventoryCustomer({
    required this.id,
    required this.name,
    this.phone = '',
  });

  final String id;
  final String name;
  final String phone;
}

/// Đơn còn mở của một khách (cho "Thêm vào đơn đang mở").
@immutable
class OpenOrder {
  const OpenOrder({required this.id, required this.code, this.value = 0});

  final String id;
  final String code;
  final double value;
}

/// Một dòng nhập cây (`POST /lots/{id}/units`).
@immutable
class NewUnitInput {
  const NewUnitInput({
    required this.maker,
    required this.model,
    this.category,
    this.serial,
    this.color,
    this.yenPrice,
    this.listPrice,
    this.qty = 1,
    this.note,
  });

  final String maker;
  final String model;
  final String? category;
  final String? serial;
  final String? color;
  final double? yenPrice;
  final double? listPrice;
  final int qty;
  final String? note;

  Map<String, dynamic> toPayload() => {
    'maker': maker.trim(),
    'model': model.trim(),
    if (category != null && category!.trim().isNotEmpty)
      'category': category!.trim(),
    // Nhiều cây giống nhau thì chưa có serial (API cũng bỏ qua).
    if (qty == 1 && serial != null && serial!.isNotEmpty) 'serial': serial,
    if (color != null && color!.trim().isNotEmpty) 'color': color!.trim(),
    'yen_price': ?yenPrice,
    'list_price': ?listPrice,
    'qty': qty,
    if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
  };
}

/// Kết quả nhận một cây (`POST /lots/{id}/receive` → `results[]`).
enum ReceiveResult {
  ok('ok', 'Đã nhận'),
  missing('missing', 'Thiếu'),
  defect('defect', 'Lỗi');

  const ReceiveResult(this.wire, this.label);

  final String wire;
  final String label;
}

/// Trang tồn kho (`GET /units` → `data` + `meta.total`).
@immutable
class UnitPage {
  const UnitPage({required this.items, required this.total});

  final List<InventoryUnit> items;
  final int total;
}

/// Cảnh báo trả kèm khi ghi (`meta.warnings`): serial trùng cây cùng hãng.
@immutable
class SerialWarning {
  const SerialWarning({required this.code, this.serial, this.index});

  factory SerialWarning.fromJson(Map<String, dynamic> j) => SerialWarning(
    code: j.strOr('code', ''),
    serial: j.str('serial'),
    index: j['index'] == null ? null : j.intOr('index'),
  );

  final String code;
  final String? serial;
  final int? index;
}

/// Câu báo sau "Đưa vào xưởng" (`POST /tasks/from-units` → `meta`): số việc đã
/// tạo và số cây bị bỏ qua vì đang có việc tân trang chưa xong.
String sendToWorkshopMessage(({int created, List<String> skipped}) r) {
  final s = r.skipped.length;
  if (r.created == 0) {
    return 'Không tạo việc nào: $s cây đang có việc tân trang.';
  }
  return s > 0
      ? 'Đã tạo ${r.created} việc xưởng, bỏ qua $s cây đang có việc tân trang.'
      : 'Đã tạo ${r.created} việc xưởng.';
}
