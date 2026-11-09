import 'package:flutter/foundation.dart';

import 'inventory_format.dart';
import 'inventory_models.dart';

/// Vấn đề của một dòng packing list dán từ Excel.
enum PastedIssue {
  /// Serial dạng số Excel (`6100656.0`) đã bỏ đuôi `.0`.
  serialFixed,

  /// Không có giá nhập ¥.
  noYen,

  /// Thiếu hãng hoặc model — dòng bị bỏ qua.
  noModel,
}

/// Một dòng đọc được từ packing list.
@immutable
class PastedRow {
  const PastedRow({
    required this.maker,
    required this.model,
    this.category,
    this.serial,
    this.color,
    this.listPrice,
    this.yenPrice,
    this.customer = '',
    this.issues = const {},
  });

  final String maker;
  final String model;
  final String? category;
  final String? serial;
  final String? color;
  final double? listPrice;
  final double? yenPrice;

  /// Tên khách trong file — chỉ để xem, không đặt trước tự động.
  final String customer;
  final Set<PastedIssue> issues;

  bool get skipped => issues.contains(PastedIssue.noModel);

  /// Dòng gửi `POST /lots/{id}/units`; không có quyền giá thì bỏ ¥.
  NewUnitInput toInput({required bool withYen}) => NewUnitInput(
    maker: maker,
    model: model,
    category: category,
    serial: serial,
    color: color,
    yenPrice: withYen ? yenPrice : null,
    listPrice: listPrice,
  );
}

/// Cột nhận được (khoá → tiêu đề gốc, null = không có).
enum PastedColumn {
  category,
  maker,
  model,
  serial,
  color,
  listPrice,
  yenPrice,
  customer,
}

@immutable
class PackingList {
  const PackingList({required this.rows, required this.columns});

  static const empty = PackingList(rows: [], columns: {});

  final List<PastedRow> rows;

  /// Rỗng khi không có dòng tiêu đề + ít nhất một dòng dữ liệu.
  final Map<PastedColumn, String?> columns;

  List<PastedRow> get valid => [
    for (final r in rows)
      if (!r.skipped) r,
  ];

  int count(PastedIssue issue) =>
      rows.where((r) => r.issues.contains(issue)).length;
}

/// Đọc vùng ô copy từ Excel (dòng đầu là tiêu đề, cột cách nhau bằng tab) —
/// cùng quy tắc với web `domain/packing-list.ts`. Nhận cột theo tiêu đề như
/// file List Nguyên: Loại, MAKER, MODEL, SERIAL, Màu, Giá Bán, Giá nhập (¥),
/// Khách hàng. Serial dạng số `6100656.0` → `6100656`.
PackingList parsePackingList(String text) {
  final lines = text
      .split(RegExp(r'\r?\n'))
      .where((l) => l.trim().isNotEmpty)
      .toList();
  if (lines.length < 2) return PackingList.empty;
  final heads = lines.first.split('\t').map((h) => h.trim()).toList();
  final low = heads.map((h) => h.toLowerCase()).toList();
  int find(List<String> keys) =>
      low.indexWhere((h) => keys.any((k) => h.contains(k)));
  final col = <PastedColumn, int>{
    PastedColumn.category: find(['loại']),
    PastedColumn.maker: find(['maker', 'hãng']),
    PastedColumn.model: find(['model']),
    PastedColumn.serial: find(['serial']),
    PastedColumn.color: find(['màu']),
    PastedColumn.listPrice: find(['giá bán', 'niêm yết']),
    PastedColumn.yenPrice: find(['¥', 'giá nhập', 'yen']),
    PastedColumn.customer: find(['khách']),
  };
  final columns = {
    for (final e in col.entries) e.key: e.value >= 0 ? heads[e.value] : null,
  };

  String? nonEmpty(String s) => s.isEmpty ? null : s;
  double? money(String s) => InventoryFormat.parseMoney(s)?.toDouble();

  final rows = <PastedRow>[];
  for (final line in lines.skip(1)) {
    final cells = line.split('\t');
    String get(PastedColumn c) {
      final i = col[c]!;
      return i >= 0 && i < cells.length ? cells[i].trim() : '';
    }

    final rawSerial = get(PastedColumn.serial);
    final serial = InventoryFormat.normalizeSerial(rawSerial);
    final yen = money(get(PastedColumn.yenPrice));
    final maker = get(PastedColumn.maker);
    final model = get(PastedColumn.model);
    final issues = <PastedIssue>{
      if (rawSerial.isNotEmpty &&
          serial != null &&
          rawSerial.toUpperCase() != serial)
        PastedIssue.serialFixed,
      if (yen == null || yen == 0) PastedIssue.noYen,
      if (maker.isEmpty || model.isEmpty) PastedIssue.noModel,
    };
    rows.add(
      PastedRow(
        category: nonEmpty(get(PastedColumn.category)),
        maker: maker.toUpperCase(),
        model: model,
        serial: serial,
        color: nonEmpty(get(PastedColumn.color)),
        listPrice: money(get(PastedColumn.listPrice)),
        yenPrice: yen == 0 ? null : yen,
        customer: get(PastedColumn.customer),
        issues: issues,
      ),
    );
  }
  return PackingList(rows: rows, columns: columns);
}
