import 'package:flutter/foundation.dart';

import 'inventory_format.dart';
import 'inventory_models.dart';

/// Cách xử lý đang chọn ở một dòng nhận hàng (cây thiếu / lỗi).
@immutable
class ReceiveClaim {
  const ReceiveClaim({this.resolution, this.amountJpy});

  /// Cây thiếu mặc định "Nhà cung cấp trừ tiền" (bản duyệt); cây lỗi mặc định
  /// chưa quyết — như web `defaultClaim`.
  factory ReceiveClaim.defaultFor(ReceiveResult r) => ReceiveClaim(
    resolution: r == ReceiveResult.missing ? ClaimResolution.deduct : null,
  );

  final ClaimResolution? resolution;

  /// Số ¥ được trừ — chỉ dùng cho cây lỗi + trừ tiền.
  final int? amountJpy;

  ReceiveClaim copyWith({
    ValueGetter<ClaimResolution?>? resolution,
    ValueGetter<int?>? amountJpy,
  }) => ReceiveClaim(
    resolution: resolution != null ? resolution() : this.resolution,
    amountJpy: amountJpy != null ? amountJpy() : this.amountJpy,
  );
}

/// Một dòng gửi `POST /lots/{id}/receive` → `results[]`.
@immutable
class ReceiveLine {
  const ReceiveLine({
    required this.unitId,
    required this.result,
    this.serial,
    this.withClaim = false,
    this.resolution,
    this.amountJpy,
  });

  final String unitId;
  final ReceiveResult result;
  final String? serial;

  /// API có khoản đòi (`inventory.claims`) và cây không "nhận": gửi cách xử
  /// lý. API cũ không có thì không gửi khoá lạ.
  final bool withClaim;
  final ClaimResolution? resolution;
  final int? amountJpy;

  bool get needsAmount =>
      withClaim &&
      result == ReceiveResult.defect &&
      resolution == ClaimResolution.deduct;

  Map<String, Object?> toPayload() => {
    'unit_id': unitId,
    'result': result.wire,
    'serial': ?serial,
    if (withClaim && result != ReceiveResult.ok) ...{
      'resolution': resolution?.wire,
      if (needsAmount) 'amount_jpy': amountJpy,
    },
  };
}

/// Dòng gửi API (spec §4.5): chỉ cây khác "nhận" hoặc có serial mới — như web
/// `buildReceiveResults`.
List<ReceiveLine> buildReceiveLines(
  List<InventoryUnit> units, {
  required ReceiveResult Function(String id) result,
  required Map<String, String?> serials,
  required Map<String, ReceiveClaim> claims,
  required bool withClaims,
}) {
  return [
    for (final u in units)
      if (result(u.id) != ReceiveResult.ok ||
          InventoryFormat.normalizeSerial(serials[u.id]) != null)
        () {
          final r = result(u.id);
          final c = claims[u.id] ?? ReceiveClaim.defaultFor(r);
          final claim = withClaims && r != ReceiveResult.ok;
          return ReceiveLine(
            unitId: u.id,
            result: r,
            serial: InventoryFormat.normalizeSerial(serials[u.id]),
            withClaim: claim,
            resolution: claim ? c.resolution : null,
            amountJpy: claim ? c.amountJpy : null,
          );
        }(),
  ];
}

/// Cây lỗi chọn "trừ tiền" mà chưa có số ¥ → API trả 422; chặn trước ở form.
bool missingDeductAmount(List<ReceiveLine> lines) => lines.any(
  (l) => l.needsAmount && (l.amountJpy == null || l.amountJpy! <= 0),
);
