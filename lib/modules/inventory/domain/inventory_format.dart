import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'inventory_models.dart';

/// Logic thuần của Kho (không widget) — cùng quy tắc với web `domain/format.ts`.
abstract final class InventoryFormat {
  static final _group = NumberFormat('#,##0', 'vi_VN');
  static final _serialTail = RegExp(r'\.0+$');
  static final _nonDigit = RegExp(r'[^\d]');

  /// Số đủ chữ số, dấu chấm hàng nghìn (`1.850.000`) — không rút gọn.
  static String number(num? n) {
    if (n == null || !n.isFinite) return '—';
    return _group.format(n.round());
  }

  /// Tiền yên: `1.850.000 ¥`.
  static String yen(num? n) => n == null ? '—' : '${number(n)} ¥';

  /// Tỷ lệ ₫/¥: số nguyên giữ nguyên (`200`), còn lại 2 chữ số (`185,53`).
  static String rate(num? n) {
    if (n == null || !n.isFinite) return '—';
    if ((n - n.round()).abs() < 0.005) return '${n.round()}';
    return n.toStringAsFixed(2).replaceAll('.', ',');
  }

  /// `yyyy-mm-dd…` → `dd/mm/yyyy`.
  static String dmy(String? iso) {
    if (iso == null || iso.length < 10) return '—';
    final p = iso.substring(0, 10).split('-');
    if (p.length != 3) return '—';
    return '${p[2]}/${p[1]}/${p[0]}';
  }

  /// Ngày hôm nay dạng `yyyy-mm-dd` (giờ máy).
  static String isoDay(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Số ngày từ ngày nhập kho tới [today]; không có ngày → null.
  static int? ageDays(String? iso, DateTime today) {
    if (iso == null || iso.length < 10) return null;
    final t = DateTime.tryParse(iso.substring(0, 10));
    if (t == null) return null;
    // Theo giờ UTC để ngày đổi giờ mùa hè không làm lệch một ngày.
    final base = DateTime.utc(today.year, today.month, today.day);
    return base.difference(DateTime.utc(t.year, t.month, t.day)).inDays;
  }

  /// Chuẩn hoá serial như API (`Serial::normalize`): cắt trắng, viết hoa, bỏ
  /// đuôi `.0` (Excel lưu số thành `6100656.0`). Rỗng → null.
  static String? normalizeSerial(String? raw) {
    final s = (raw ?? '').trim().toUpperCase().replaceAll(_serialTail, '');
    return s.isEmpty ? null : s;
  }

  static final _decimalTail = RegExp(r'^(.*\d)[.,](\d{1,2})$');

  /// Đọc số tiền gõ tay hoặc dán từ Excel → số nguyên (rỗng, số âm → null).
  /// Dấu chấm/phẩy là dấu hàng nghìn (`17.500.000`, `120,000`); riêng đuôi 1–2
  /// chữ số sau dấu cuối là phần lẻ của Excel (`5500000.0`) — làm tròn, không
  /// dính vào phần nguyên. Giống `parseMoney` ở web.
  static int? parseMoney(String raw) {
    final s = raw.trim();
    if (s.startsWith('-') || s.startsWith('−')) return null;
    final m = _decimalTail.firstMatch(s);
    final whole = (m?.group(1) ?? s).replaceAll(_nonDigit, '');
    if (whole.isEmpty) return null;
    final n = int.tryParse(whole);
    if (n == null || m == null) return n;
    final frac = m.group(2)!;
    final up = int.parse(frac.padRight(2, '0')) >= 50;
    return up ? n + 1 : n;
  }

  static String digits(String raw) => raw.replaceAll(_nonDigit, '');

  /// Chuỗi gõ vào ô tìm khách trông như số điện thoại.
  static bool looksLikePhone(String raw) =>
      RegExp(r'^[\d\s.+]+$').hasMatch(raw.trim()) && digits(raw).length >= 3;
}

enum NextTone { ok, warn, muted }

/// "Việc tiếp theo" của một lô — một câu, đủ biết cần làm gì.
@immutable
class NextStep {
  const NextStep(this.tone, this.text);

  final NextTone tone;
  final String text;

  @override
  bool operator ==(Object other) =>
      other is NextStep && other.tone == tone && other.text == text;

  @override
  int get hashCode => Object.hash(tone, text);

  @override
  String toString() => 'NextStep($tone, $text)';
}

NextStep nextStep(Lot lot, {required bool canPay}) {
  if (lot.status == LotStatus.received) {
    return NextStep(NextTone.muted, 'Còn ${lot.inStock} cây trong kho');
  }
  if (lot.units == 0) return const NextStep(NextTone.muted, 'Chờ packing list');
  if (lot.costFinal) {
    return NextStep(
      NextTone.ok,
      lot.status == LotStatus.inTransit
          ? 'Đã chốt giá vốn · chờ nhận hàng'
          : 'Đã chốt giá vốn',
    );
  }
  final due = lot.dueJpy;
  if (due != null && due > 0) {
    return canPay
        ? NextStep(
            NextTone.warn,
            'Còn tiền invoice ${InventoryFormat.yen(due)}',
          )
        : const NextStep(NextTone.warn, 'Chờ trả tiền hàng');
  }
  if (lot.plannedCount > 0) {
    return NextStep(NextTone.warn, 'Còn ${lot.plannedCount} khoản thuế phí');
  }
  return const NextStep(NextTone.muted, 'Chờ nhận hàng');
}

/// Nhóm cây cùng hãng + model.
@immutable
class ModelGroup {
  const ModelGroup(this.key, this.items);

  final String key;
  final List<InventoryUnit> items;

  int get withCustomer => items.where((u) => u.hasCustomer).length;
}

/// Gom cây theo hãng + model, giữ thứ tự xuất hiện đầu tiên.
List<ModelGroup> groupByModel(Iterable<InventoryUnit> units) {
  final map = <String, List<InventoryUnit>>{};
  for (final u in units) {
    map.putIfAbsent('${u.maker} ${u.model}'.trim(), () => []).add(u);
  }
  return [for (final e in map.entries) ModelGroup(e.key, e.value)];
}

/// Một mẫu hàng đã từng nhập — gợi ý khi gõ model ở "Thêm cây".
@immutable
class ModelSuggestion {
  const ModelSuggestion({
    required this.maker,
    required this.model,
    this.category,
    this.yenPrice,
    this.listPrice,
  });

  final String maker;
  final String model;
  final String? category;
  final double? yenPrice;
  final double? listPrice;

  String get key => '$maker|$model';
}

/// Danh mục mẫu (hãng + model) từ các cây đã có; mẫu đầu tiên gặp thắng, giá
/// lấy từ cây đầu tiên có giá.
List<ModelSuggestion> modelCatalog(Iterable<InventoryUnit> units) {
  final out = <String, ModelSuggestion>{};
  for (final u in units) {
    if (u.maker.isEmpty || u.model.isEmpty) continue;
    final key = '${u.maker}|${u.model}';
    final prev = out[key];
    out[key] = ModelSuggestion(
      maker: u.maker,
      model: u.model,
      category: prev?.category ?? u.category,
      yenPrice: prev?.yenPrice ?? u.yenPrice,
      listPrice: prev?.listPrice ?? u.listPrice,
    );
  }
  return out.values.toList();
}

/// Gợi ý theo chuỗi gõ (khớp "hãng model", không phân biệt hoa thường).
List<ModelSuggestion> suggestModels(
  List<ModelSuggestion> catalog,
  String query, {
  int limit = 4,
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  return catalog
      .where((c) => '${c.maker} ${c.model}'.toLowerCase().contains(q))
      .take(limit)
      .toList();
}

/// Cây đặt trước cho một khách sau khi nhận hàng — để tạo đơn gom theo khách.
@immutable
class CustomerOrderGroup {
  const CustomerOrderGroup({
    required this.customerId,
    required this.customerName,
    required this.units,
    required this.total,
  });

  final String customerId;
  final String customerName;
  final List<InventoryUnit> units;
  final double total;
}

/// Gom cây đã đặt trước (không phải "để bán lẻ", không thiếu) theo khách.
List<CustomerOrderGroup> groupReservedByCustomer(
  Iterable<InventoryUnit> units,
  Map<String, ReceiveResult> results,
) {
  final map = <String, List<InventoryUnit>>{};
  final names = <String, String>{};
  for (final u in units) {
    final cid = u.customerId;
    if (u.sale != UnitSale.reserved || cid == null || u.retailHold) continue;
    if (results[u.id] == ReceiveResult.missing) continue;
    map.putIfAbsent(cid, () => []).add(u);
    names[cid] = u.customerName ?? '—';
  }
  return [
    for (final e in map.entries)
      CustomerOrderGroup(
        customerId: e.key,
        customerName: names[e.key]!,
        units: e.value,
        total: e.value.fold(0, (s, u) => s + u.suggestedPrice),
      ),
  ];
}

/// Lọc tuổi tồn (tính trên trang đã tải).
enum AgeBucket {
  upTo90('≤ 90 ngày'),
  upTo180('91–180 ngày'),
  over180('> 180 ngày'),
  none('Chưa có ngày');

  const AgeBucket(this.label);

  final String label;

  bool matches(int? days) => switch (this) {
    AgeBucket.none => days == null,
    AgeBucket.upTo90 => days != null && days <= 90,
    AgeBucket.upTo180 => days != null && days > 90 && days <= 180,
    AgeBucket.over180 => days != null && days > 180,
  };
}
