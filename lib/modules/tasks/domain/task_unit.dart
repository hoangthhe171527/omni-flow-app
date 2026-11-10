import 'package:flutter/foundation.dart';

import '../../../core/utils/json.dart';

/// Kho nối Xưởng (spec `TNP_KHO_VA_HANG_SAP_VE.md` §13): việc gắn với một cây
/// trong Kho. Server ghi `subject` (`WorkState::subject`) và gắn `unit` lúc trả
/// lời (`UnitDecorator` đọc `UnitLookupPort::summaries`), nên khách và trạng
/// thái ở đây luôn là số hiện tại của Kho.
///
/// `place` / `sale` / `condition` giữ nguyên chuỗi trên dây: module tasks không
/// import Kho (Kho import tasks — chiều ngược lại là một chu trình).

/// `subject: {type, id, role}`. Hiện chỉ có `type == unit`.
@immutable
class TaskSubject {
  const TaskSubject({
    required this.type,
    required this.id,
    this.role = refurbish,
  });

  static const refurbish = 'refurbish';
  static const warranty = 'warranty';

  /// null khi vắng khoá, sai kiểu, hoặc thiếu `type` / `id` — như server.
  static TaskSubject? parse(Object? raw) {
    if (raw is! Map) return null;
    final j = raw.cast<String, dynamic>();
    final type = j.str('type');
    final id = j.str('id');
    if (type == null || id == null) return null;

    return TaskSubject(type: type, id: id, role: j.strOr('role', refurbish));
  }

  final String type;
  final String id;

  /// `refurbish` (tân trang, cây chưa giao) hoặc `warranty` (bảo hành).
  final String role;

  bool get isWarranty => role == warranty;
}

/// Cây của việc, đọc từ Kho. Không có trường tiền (thợ không cần quyền Kho).
@immutable
class TaskUnit {
  const TaskUnit({
    required this.id,
    this.maker = '',
    this.model = '',
    this.serial,
    this.category,
    this.lotId,
    this.lotCode,
    this.place = 'incoming',
    this.condition,
    this.sale = 'available',
    this.retailHold = false,
    this.customerId,
    this.customerName,
    this.receivedAt,
  });

  /// null khi vắng khoá hoặc cây đã xoá khỏi Kho (`unit: null`).
  static TaskUnit? parse(Object? raw) {
    if (raw is! Map) return null;
    final j = raw.cast<String, dynamic>();
    final id = j.str('id');
    if (id == null) return null;

    return TaskUnit(
      id: id,
      maker: j.strOr('maker', ''),
      model: j.strOr('model', ''),
      serial: j.str('serial'),
      category: j.str('category'),
      lotId: j.str('lot_id'),
      lotCode: j.str('lot_code'),
      place: j.strOr('place', 'incoming'),
      condition: j.str('condition'),
      sale: j.strOr('sale', 'available'),
      retailHold: j.flag('retail_hold'),
      customerId: j.str('customer_id'),
      customerName: j.str('customer_name'),
      receivedAt: j.str('received_at'),
    );
  }

  final String id;
  final String maker;
  final String model;
  final String? serial;
  final String? category;
  final String? lotId;
  final String? lotCode;

  /// `incoming` | `in_stock` | `delivered`.
  final String place;

  /// `sealed` | `refurbishing` | `ready` | `defective` | `missing` | null.
  final String? condition;

  /// `available` | `reserved` | `sold`.
  final String sale;
  final bool retailHold;
  final String? customerId;
  final String? customerName;
  final String? receivedAt;

  /// "YAMAHA U1E" — serial vẽ riêng, chữ mờ.
  String get name => '$maker $model'.trim();

  bool get isDelivered => place == 'delivered';

  bool get isSold => sale == 'sold';

  bool get hasCustomer => customerId != null || customerName != null;

  /// Nhãn tình trạng — BẢN SAO của `UnitCondition` bên Kho;
  /// `task_unit_test` canh hai bảng luôn bằng nhau.
  String get conditionLabel => switch (condition) {
    'sealed' => 'Nguyên thùng',
    'refurbishing' => 'Đang làm',
    'ready' => 'Sẵn sàng',
    'defective' => 'Lỗi',
    'missing' => 'Không thấy',
    _ => 'Chưa kiểm',
  };

  /// Dòng phụ trên thẻ bảng: "Trần Minh Khôi · Ep 61" / "Chưa có khách · Ep 61".
  String get customerLine => [
    customerName ?? (customerId != null ? 'Khách' : 'Chưa có khách'),
    ?lotCode,
  ].join(' · ');
}

/// Việc tân trang mà cây đã giao khách: nằm ở cột ảo "Đã giao" thay cho nhóm
/// việc đã lưu. Việc bảo hành thì cây LUÔN đã giao nên vẫn ở nhóm của nó.
bool isDeliveredRefurbish(TaskSubject? subject, TaskUnit? unit) =>
    unit != null && unit.isDelivered && !(subject?.isWarranty ?? false);

/// Cây đã bán mà việc chưa xong và cây chưa giao: khách đang chờ.
bool isSoldPriority(TaskUnit? unit, {required bool done}) =>
    unit != null && unit.isSold && !unit.isDelivered && !done;
