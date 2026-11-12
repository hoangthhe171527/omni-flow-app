import '../../../core/utils/json.dart';

/// Một cây trong Kho, đủ cho tấm "Thêm việc · Chọn đàn" trên bảng kế hoạch
/// (TNP_DON_HANG_THEO_CAY §6). Value type riêng của plans: module Kho đã phụ
/// thuộc plans, nên plans không import ngược kiểu cây của Kho.
class BoardUnit {
  const BoardUnit({
    required this.id,
    this.maker = '',
    this.model = '',
    this.serial,
    this.lotCode,
    this.customerName,
    this.busySection,
    this.busy = false,
  });

  /// Một dòng `GET /inventory/units`. `busy` = đang có việc tân trang chưa xong
  /// (server sẽ bỏ qua cây này); `busySection` = nhóm việc đang ở.
  factory BoardUnit.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic>? open;
    final work = j['workshop'];
    if (work is List) {
      for (final w in work) {
        if (w is Map &&
            w['role'] == 'refurbish' &&
            w['state'] != 'done' &&
            w['state'] != 'removed') {
          open = w.cast<String, dynamic>();
          break;
        }
      }
    }
    return BoardUnit(
      id: j.strOr('id', ''),
      maker: j.strOr('maker', ''),
      model: j.strOr('model', ''),
      serial: j.str('serial'),
      lotCode: j.str('lot_code'),
      customerName: j.str('customer_name'),
      busySection: open?.str('section_name'),
      busy: open != null,
    );
  }

  final String id;
  final String maker;
  final String model;
  final String? serial;
  final String? lotCode;
  final String? customerName;
  final String? busySection;
  final bool busy;

  String get label => '$maker $model'.trim();
}

/// Kết quả `POST /tasks/from-units`: số việc đã tạo, id cây bị bỏ qua.
typedef UnitTasksResult = ({int created, List<String> skipped});
