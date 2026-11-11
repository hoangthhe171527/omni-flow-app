import 'package:flutter/foundation.dart';

import '../../../core/utils/json.dart';
import 'inventory_format.dart';

/// Kiểu của Kho chuẩn hóa Đợt A (omni-flow-api PR #96, spec
/// `TNP_KHO_CHUAN_HOA.md` §4–§5): vị trí, thẻ kho, ảnh, khoản đòi, hồ sơ nhà
/// cung cấp. Đúng hình dạng `InventoryPresenter` / các controller Kho.
///
/// Thêm trường ở đây phải thêm đủ ở `fromJson` + chỗ ghi — thiếu một chỗ là
/// mất dữ liệu lặng.

/// Cách xử lý cây thiếu / lỗi với nhà cung cấp.
enum ClaimResolution {
  deduct('deduct', 'Nhà cung cấp trừ tiền'),
  replaceLater('replace_later', 'Bù ở lô sau'),
  absorb('absorb', 'Mình chịu');

  const ClaimResolution(this.wire, this.label);

  final String wire;
  final String label;

  static const undecidedLabel = 'Chưa quyết';

  static ClaimResolution? parse(String? raw) {
    for (final r in values) {
      if (r.wire == raw) return r;
    }
    return null;
  }

  static String labelOf(ClaimResolution? r) => r?.label ?? undecidedLabel;
}

/// Khoản đòi nhà cung cấp (`InventoryPresenter::claim`). ¥ chỉ có với
/// `inventory.cost`.
@immutable
class LotClaim {
  const LotClaim({
    required this.id,
    required this.lotId,
    required this.unitId,
    this.missing = true,
    this.resolution,
    this.settled = false,
    this.settledAt,
    this.note,
    this.amountJpy,
    this.debtCutJpy,
  });

  factory LotClaim.fromJson(Map<String, dynamic> j) => LotClaim(
    id: j.strOr('id', ''),
    lotId: j.strOr('lot_id', ''),
    unitId: j.strOr('unit_id', ''),
    missing: j.str('kind') != 'defect',
    resolution: ClaimResolution.parse(j.str('resolution')),
    settled: j.str('status') == 'settled',
    settledAt: j.str('settled_at'),
    note: j.str('note'),
    amountJpy: j.dbl('amount_jpy'),
    debtCutJpy: j.dbl('debt_cut_jpy'),
  );

  final String id;
  final String lotId;
  final String unitId;

  /// `kind == missing`; ngược lại là cây lỗi (`defect`).
  final bool missing;
  final ClaimResolution? resolution;
  final bool settled;
  final String? settledAt;
  final String? note;
  final double? amountJpy;
  final double? debtCutJpy;

  String get kindLabel => missing ? 'Thiếu' : 'Lỗi';

  /// Cây lỗi chọn "trừ tiền" thì phải có số ¥ (API 422 nếu thiếu).
  static bool needsAmount({
    required bool missing,
    required ClaimResolution? resolution,
  }) => !missing && resolution == ClaimResolution.deduct;
}

/// Thân `PUT /inventory/claims/{id}`.
@immutable
class ClaimInput {
  const ClaimInput({
    required this.missing,
    required this.resolution,
    required this.settled,
    this.amountJpy,
  });

  final bool missing;
  final ClaimResolution? resolution;
  final bool settled;
  final num? amountJpy;

  Map<String, Object?> toPayload() => {
    'resolution': resolution?.wire,
    // Cây thiếu luôn tính theo cả ¥ của cây: API bỏ số riêng.
    if (LotClaim.needsAmount(missing: missing, resolution: resolution))
      'amount_jpy': amountJpy,
    'status': settled ? 'settled' : 'open',
  };
}

/// Vị trí chứa hàng (`LocationController::presentMany`).
@immutable
class StockLocation {
  const StockLocation({
    required this.id,
    required this.name,
    this.kind = 'warehouse',
    this.isDefault = false,
    this.archived = false,
    this.unitCount = 0,
    this.partnerName,
  });

  factory StockLocation.fromJson(Map<String, dynamic> j) => StockLocation(
    id: j.strOr('id', ''),
    name: j.strOr('name', ''),
    kind: j.strOr('kind', 'warehouse'),
    isDefault: j.flag('is_default'),
    archived: j.str('archived_at') != null,
    unitCount: j.intOr('unit_count'),
    partnerName: j.str('partner_customer_name'),
  );

  final String id;
  final String name;

  /// `warehouse` | `showroom` | `partner`.
  final String kind;
  final bool isDefault;
  final bool archived;

  /// Số cây đang trong kho ở vị trí này (chỉ cây `in_stock`).
  final int unitCount;
  final String? partnerName;
}

/// Tóm tắt tồn (`GET /inventory/units/summary`) — app chỉ cần biết có từ hai
/// vị trí hay không (spec §5: lọc / chuyển vị trí chỉ khi đó).
@immutable
class StockSummary {
  const StockSummary({this.multiLocation = false});

  factory StockSummary.fromJson(Map<String, dynamic> j) =>
      StockSummary(multiLocation: j.flag('multi_location'));

  final bool multiLocation;
}

/// Một dòng thẻ kho (`GET /units/{id}/ledger`): sổ chuyển động (`move`) hoặc
/// việc xưởng (`work`), mới nhất trước.
@immutable
class LedgerRow {
  const LedgerRow({
    required this.id,
    required this.isWork,
    required this.kind,
    this.at,
    this.fromName,
    this.toName,
    this.note,
    this.title = '',
    this.taskId,
  });

  factory LedgerRow.fromJson(Map<String, dynamic> j) => LedgerRow(
    id: j.strOr('id', ''),
    isWork: j.str('type') == 'work',
    kind: j.strOr('kind', ''),
    at: j.str('at'),
    fromName: j.str('from_location_name'),
    toName: j.str('to_location_name'),
    note: j.str('note'),
    title: j.strOr('title', ''),
    taskId: j.str('task_id'),
  );

  final String id;
  final bool isWork;

  /// move: `receive` | `transfer` | `issue` | `return` | `count_missing` |
  /// `count_found`; work: `refurbish` |
  /// `warranty`.
  final String kind;
  final String? at;
  final String? fromName;
  final String? toName;
  final String? note;
  final String title;
  final String? taskId;

  /// Chữ của dòng — cùng câu với web (`ledger.*`).
  String get text {
    if (isWork) {
      return switch (kind) {
        'refurbish' => 'Tân trang: $title',
        'warranty' => 'Bảo hành: $title',
        _ => title,
      };
    }
    final from = fromName ?? '—';
    final to = toName ?? '—';
    return switch (kind) {
      'receive' => 'Nhận vào $to',
      'transfer' => 'Chuyển từ $from đến $to',
      'issue' => 'Xuất kho',
      'return' => 'Nhận lại vào $to',
      'count_missing' => 'Kiểm kê: không thấy',
      'count_found' => 'Kiểm kê: thấy lại',
      _ => kind,
    };
  }

  /// `12/10/2026`; việc chưa xong (chưa có ngày) là "Đang làm".
  String get when => at == null ? 'Đang làm' : InventoryFormat.dmy(at);
}

/// Ảnh của cây (`UnitPhotos::all`): ảnh kho (xoá, đặt đại diện được) hoặc ảnh
/// thợ chụp trong việc xưởng (`source: task`, chỉ xem).
@immutable
class UnitPhoto {
  const UnitPhoto({
    required this.id,
    required this.url,
    this.fromTask = false,
    this.taskTitle,
    this.at,
    this.isCover = false,
  });

  factory UnitPhoto.fromJson(Map<String, dynamic> j) => UnitPhoto(
    id: j.strOr('id', ''),
    url: j.strOr('url', ''),
    fromTask: j.str('source') == 'task',
    taskTitle: j.str('task_title'),
    at: j.str('at'),
    isCover: j.flag('is_cover'),
  );

  /// Tối đa ảnh kho mỗi cây (`UnitPhotos::MAX_STOCK_PHOTOS`).
  static const maxStock = 20;

  final String id;
  final String url;
  final bool fromTask;
  final String? taskTitle;
  final String? at;
  final bool isCover;
}

/// Hạn trả nhà cung cấp.
enum PaymentTermKind {
  onClearance('on_clearance', 'Trả khi thông quan'),
  days('days', 'Trả sau số ngày'),
  prepaid('prepaid', 'Trả trước');

  const PaymentTermKind(this.wire, this.label);

  final String wire;
  final String label;

  static PaymentTermKind parse(String? raw) => switch (raw) {
    'days' => days,
    'prepaid' => prepaid,
    _ => onClearance,
  };
}

@immutable
class BankAccount {
  const BankAccount({required this.bank, required this.number, this.holder});

  factory BankAccount.fromJson(Map<String, dynamic> j) => BankAccount(
    bank: j.strOr('bank', ''),
    number: j.strOr('number', ''),
    holder: j.str('holder'),
  );

  final String bank;
  final String number;
  final String? holder;

  Map<String, Object?> toPayload() => {
    'bank': bank.trim(),
    'number': number.trim(),
    'holder': holder == null || holder!.trim().isEmpty ? null : holder!.trim(),
  };
}

/// Lô còn nợ / trả dư của một nhà cung cấp (chỉ ở chi tiết, quyền thanh toán).
@immutable
class SupplierLot {
  const SupplierLot({
    required this.id,
    required this.code,
    this.status = 'ordered',
    this.receivedAt,
    this.dueJpy = 0,
    this.prepaidJpy = 0,
    this.overdue = false,
  });

  factory SupplierLot.fromJson(Map<String, dynamic> j) => SupplierLot(
    id: j.strOr('id', ''),
    code: j.strOr('code', ''),
    status: j.strOr('status', 'ordered'),
    receivedAt: j.str('received_at'),
    dueJpy: j.dbl('due_jpy') ?? 0,
    prepaidJpy: j.dbl('prepaid_jpy') ?? 0,
    overdue: j.flag('overdue'),
  );

  final String id;
  final String code;
  final String status;
  final String? receivedAt;
  final double dueJpy;
  final double prepaidJpy;
  final bool overdue;
}

/// Hồ sơ nhà cung cấp (`SupplierController::present`, `lots` ở chi tiết). Số
/// nợ chỉ có với `inventory.lot_payments` (API bỏ hẳn khoá) → null.
@immutable
class SupplierDetail {
  const SupplierDetail({
    required this.id,
    required this.code,
    required this.name,
    this.foreign = true,
    this.person = false,
    this.taxId,
    this.phone,
    this.address,
    this.bankAccounts = const [],
    this.customerId,
    this.customerName,
    this.currency = 'JPY',
    this.term = PaymentTermKind.onClearance,
    this.termDays,
    this.note,
    this.debtJpy,
    this.overdueJpy,
    this.prepaidJpy,
    this.openLots,
    this.lots,
  });

  factory SupplierDetail.fromJson(Map<String, dynamic> j) {
    final term = j.child('payment_term');
    return SupplierDetail(
      id: j.strOr('id', ''),
      code: j.strOr('code', ''),
      name: j.strOr('name', ''),
      foreign: j.str('origin') != 'domestic',
      person: j.str('party') == 'person',
      taxId: j.str('tax_id'),
      phone: j.str('phone'),
      address: j.str('address'),
      bankAccounts: [
        for (final b in j.mapList('bank_accounts')) BankAccount.fromJson(b),
      ],
      customerId: j.str('customer_id'),
      customerName: j.str('customer_name'),
      currency: j.strOr('currency', 'JPY'),
      term: PaymentTermKind.parse(term.str('kind')),
      termDays: term['days'] == null ? null : term.intOr('days'),
      note: j.str('note'),
      debtJpy: j.dbl('debt_jpy'),
      overdueJpy: j.dbl('overdue_jpy'),
      prepaidJpy: j.dbl('prepaid_jpy'),
      openLots: j['open_lots'] == null ? null : j.intOr('open_lots'),
      lots: j['lots'] is List
          ? [for (final l in j.mapList('lots')) SupplierLot.fromJson(l)]
          : null,
    );
  }

  final String id;
  final String code;
  final String name;

  /// `origin == foreign` (nhập khẩu); ngược lại trong nước.
  final bool foreign;

  /// `party == person` (cá nhân); ngược lại tổ chức.
  final bool person;
  final String? taxId;
  final String? phone;
  final String? address;
  final List<BankAccount> bankAccounts;
  final String? customerId;
  final String? customerName;

  /// `JPY` | `VND`.
  final String currency;
  final PaymentTermKind term;
  final int? termDays;
  final String? note;

  // ---- chỉ có với `inventory.lot_payments` ----
  final double? debtJpy;
  final double? overdueJpy;
  final double? prepaidJpy;
  final int? openLots;
  final List<SupplierLot>? lots;

  bool get hasDebt => debtJpy != null;

  String get originLabel => foreign ? 'Nước ngoài' : 'Trong nước';

  String get termLabel => term == PaymentTermKind.days
      ? 'Trả sau ${termDays ?? 30} ngày'
      : term.label;
}

/// Thân `PUT /inventory/suppliers/{id}` — hồ sơ; mã không đổi.
@immutable
class SupplierInput {
  const SupplierInput({
    required this.name,
    required this.foreign,
    required this.person,
    required this.currency,
    required this.term,
    this.termDays,
    this.taxId,
    this.phone,
    this.address,
    this.note,
    this.bankAccounts = const [],
  });

  factory SupplierInput.of(SupplierDetail s) => SupplierInput(
    name: s.name,
    foreign: s.foreign,
    person: s.person,
    currency: s.currency,
    term: s.term,
    termDays: s.termDays,
    taxId: s.taxId,
    phone: s.phone,
    address: s.address,
    note: s.note,
    bankAccounts: s.bankAccounts,
  );

  final String name;
  final bool foreign;
  final bool person;
  final String currency;
  final PaymentTermKind term;
  final int? termDays;
  final String? taxId;
  final String? phone;
  final String? address;
  final String? note;
  final List<BankAccount> bankAccounts;

  static String? _orNull(String? v) =>
      v == null || v.trim().isEmpty ? null : v.trim();

  Map<String, Object?> toPayload() => {
    'name': name.trim(),
    'origin': foreign ? 'foreign' : 'domestic',
    'party': person ? 'person' : 'org',
    'tax_id': _orNull(taxId),
    'phone': _orNull(phone),
    'address': _orNull(address),
    'currency': currency,
    'payment_term': {
      'kind': term.wire,
      'days': term == PaymentTermKind.days
          ? (termDays != null && termDays! > 0 ? termDays : 30)
          : null,
    },
    'note': _orNull(note),
    // Dòng tài khoản thiếu ngân hàng hoặc số bị bỏ (API đòi cả hai).
    'bank_accounts': [
      for (final b in bankAccounts)
        if (b.bank.trim().isNotEmpty && b.number.trim().isNotEmpty)
          b.toPayload(),
    ],
  };
}
