import 'package:flutter/foundation.dart';

import '../../../core/utils/json.dart';

/// Kho chuẩn hóa Đợt C — đúng hình dạng API (`InventoryPresenter::unit` /
/// `::count`, `SlipController::present`, omni-flow-api PR #101, spec
/// TNP_KHO_DOT_B_C §2.1, §2.4, §2.5, §2.8). App chỉ đọc hóa đơn và phiếu xuất;
/// ghi kiểm kê và trả hàng.

/// Trạng thái hóa đơn bán của cây (`invoice.status`).
enum InvoiceStatus {
  pending('pending', 'Chưa xuất'),
  issued('issued', 'Đã xuất'),
  notRequired('not_required', 'Không xuất');

  const InvoiceStatus(this.wire, this.label);

  final String wire;
  final String label;

  static InvoiceStatus parse(String? raw) => switch (raw) {
    'issued' => InvoiceStatus.issued,
    'not_required' => InvoiceStatus.notRequired,
    _ => InvoiceStatus.pending,
  };
}

/// Hóa đơn bán trên cây đã bán. null trên cây = bán trước khi có tính năng.
@immutable
class UnitInvoice {
  const UnitInvoice({required this.status, this.no, this.date});

  static UnitInvoice? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final j = raw.cast<String, dynamic>();
    return UnitInvoice(
      status: InvoiceStatus.parse(j.str('status')),
      no: j.str('no'),
      date: j.str('date'),
    );
  }

  final InvoiceStatus status;
  final String? no;

  /// Y-m-d.
  final String? date;
}

/// Trạng thái phiên kiểm kê.
enum CountStatus {
  open('open', 'Đang kiểm'),
  submitted('submitted', 'Chờ duyệt'),
  approved('approved', 'Đã duyệt');

  const CountStatus(this.wire, this.label);

  final String wire;
  final String label;

  static CountStatus parse(String? raw) => switch (raw) {
    'submitted' => CountStatus.submitted,
    'approved' => CountStatus.approved,
    _ => CountStatus.open,
  };
}

/// Cây không thấy khi chốt (`missing_units[]`).
typedef CountMissingUnit = ({String unitId, String? label, String? serial});

/// Phiên kiểm kê một vị trí (`count`).
@immutable
class StockCount {
  const StockCount({
    required this.id,
    required this.locationId,
    this.locationName,
    this.status = CountStatus.open,
    this.seenUnitIds = const [],
    this.qty = const {},
    this.missingUnitIds = const [],
    this.missingUnits = const [],
    this.missingCount,
    this.qtyDeltas = const {},
    this.note,
    this.createdAt,
    this.submittedAt,
    this.approvedAt,
  });

  factory StockCount.fromJson(Map<String, dynamic> j) {
    final result = j['result'] is Map
        ? (j['result'] as Map).cast<String, dynamic>()
        : null;
    return StockCount(
      id: j.strOr('id', ''),
      locationId: j.strOr('location_id', ''),
      locationName: j.str('location_name'),
      status: CountStatus.parse(j.str('status')),
      seenUnitIds: j.strList('seen_unit_ids'),
      qty: {
        for (final r in j.mapList('qty'))
          if (r.str('product_id') != null) r.str('product_id')!: r.intOr('qty'),
      },
      missingUnitIds: j.strList('missing_unit_ids'),
      missingUnits: [
        for (final m in j.mapList('missing_units'))
          (
            unitId: m.strOr('unit_id', ''),
            label: m.str('label'),
            serial: m.str('serial'),
          ),
      ],
      missingCount: result?.intOr('missing_units'),
      qtyDeltas: {
        if (result != null)
          for (final d in result.mapList('qty_deltas'))
            if (d.str('product_id') != null)
              d.str('product_id')!: d.intOr('delta'),
      },
      note: j.str('note'),
      createdAt: j.str('created_at'),
      submittedAt: j.str('submitted_at'),
      approvedAt: j.str('approved_at'),
    );
  }

  final String id;
  final String locationId;
  final String? locationName;
  final CountStatus status;
  final List<String> seenUnitIds;

  /// Số đếm hàng số lượng: mã hàng → số.
  final Map<String, int> qty;
  final List<String> missingUnitIds;
  final List<CountMissingUnit> missingUnits;

  /// Kết quả sau khi duyệt (null = chưa duyệt).
  final int? missingCount;

  /// Chênh lệch số lượng đã ghi sổ khi duyệt: mã hàng → chênh.
  final Map<String, int> qtyDeltas;
  final String? note;
  final String? createdAt;
  final String? submittedAt;
  final String? approvedAt;
}

/// Một dòng phiếu xuất.
@immutable
class SlipLine {
  const SlipLine({
    this.unitId,
    this.productId,
    this.code,
    required this.name,
    this.serial,
    this.unit = 'Chiếc',
    this.qty = 1,
    this.price,
    this.amount,
  });

  factory SlipLine.fromJson(Map<String, dynamic> j) => SlipLine(
    unitId: j.str('unit_id'),
    productId: j.str('product_id'),
    code: j.str('code'),
    name: j.strOr('name', ''),
    serial: j.str('serial'),
    unit: j.strOr('unit', 'Chiếc'),
    qty: j.intOr('qty', 1),
    price: j.dbl('price'),
    amount: j.dbl('amount'),
  );

  final String? unitId;
  final String? productId;
  final String? code;
  final String name;
  final String? serial;

  /// Đơn vị tính.
  final String unit;
  final int qty;
  final double? price;
  final double? amount;
}

/// Phiếu xuất kho kiêm biên bản giao hàng (`GET /inventory/slips/{no}`).
@immutable
class Slip {
  const Slip({
    required this.no,
    this.date,
    this.orderId,
    this.customerId,
    this.customerName,
    this.lines = const [],
    this.total = 0,
  });

  factory Slip.fromJson(Map<String, dynamic> j) => Slip(
    no: j.strOr('no', ''),
    date: j.str('date'),
    orderId: j.str('order_id'),
    customerId: j.str('customer_id'),
    customerName: j.str('customer_name'),
    lines: [for (final l in j.mapList('lines')) SlipLine.fromJson(l)],
    total: j.dbl('total') ?? 0,
  );

  final String no;
  final String? date;
  final String? orderId;
  final String? customerId;
  final String? customerName;
  final List<SlipLine> lines;
  final double total;
}
