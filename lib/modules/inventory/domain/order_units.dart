import '../../../core/utils/formatters.dart';
import '../../../core/utils/json.dart';

/// Trạng thái một cây trong đơn — server tính (`GET /orders/{id}/units`,
/// TNP_DON_HANG_THEO_CAY §3), app chỉ gom và hiện. Thứ tự = thứ tự nhóm.
enum OrderUnitBucket {
  issue('Cần xem'),
  inShop('Ở xưởng'),
  ready('Sẵn sàng giao'),
  notInShop('Chưa vào xưởng'),
  delivered('Đã giao');

  const OrderUnitBucket(this.label);
  final String label;

  /// Nhóm lạ (server thêm nhóm mới) → "Chưa vào xưởng", không vỡ màn.
  static OrderUnitBucket parse(Object? raw) => switch (raw) {
    'issue' => issue,
    'in_shop' => inShop,
    'ready' => ready,
    'delivered' => delivered,
    _ => notInShop,
  };
}

/// Việc xưởng hiện trên dòng cây: việc mở mới nhất, không có thì việc xong.
class OrderUnitWork {
  const OrderUnitWork({
    required this.taskId,
    this.sectionName,
    this.assigneeNames = const [],
    this.dueDate,
    this.done = 0,
    this.total = 0,
    this.state = 'todo',
    this.completedAt,
  });

  static OrderUnitWork? parse(Object? raw) {
    if (raw is! Map) return null;
    final j = raw.cast<String, dynamic>();
    final id = j.str('task_id');
    if (id == null) return null;
    return OrderUnitWork(
      taskId: id,
      sectionName: j.str('section_name') ?? j.str('step'),
      assigneeNames: j.strList('assignee_names'),
      dueDate: DateUtilsX.parse(j['due_date']),
      done: j.intOr('done'),
      total: j.intOr('total'),
      state: j.strOr('state', 'todo'),
      completedAt: DateUtilsX.parse(j['completed_at']),
    );
  }

  final String taskId;
  final String? sectionName;
  final List<String> assigneeNames;
  final DateTime? dueDate;
  final int done;
  final int total;
  final String state;
  final DateTime? completedAt;
}

/// Lời báo vấn đề trên cây. [taskId] là việc MANG cờ.
class OrderUnitIssue {
  const OrderUnitIssue({required this.note, this.taskId, this.byName});

  static OrderUnitIssue? parse(Object? raw) {
    if (raw is! Map) return null;
    final j = raw.cast<String, dynamic>();
    final note = j['note'];
    if (note is! String) return null;
    return OrderUnitIssue(
      note: note,
      taskId: j.str('task_id'),
      byName: j.str('by_name'),
    );
  }

  final String note;
  final String? taskId;
  final String? byName;
}

class OrderUnit {
  const OrderUnit({
    required this.id,
    required this.label,
    required this.bucket,
    this.serial,
    this.lotCode,
    this.condition,
    this.location,
    this.price,
    this.deliveredAt,
    this.work,
    this.issue,
  });

  factory OrderUnit.fromJson(Map<String, dynamic> j) => OrderUnit(
    id: j.strOr('id', ''),
    label:
        j.str('label') ??
        '${j.strOr('maker', '')} ${j.strOr('model', '')}'.trim(),
    bucket: OrderUnitBucket.parse(j['bucket']),
    serial: j.str('serial'),
    lotCode: j.str('lot_code'),
    condition: j.str('condition'),
    location: j.str('location'),
    price: j.dbl('price'),
    deliveredAt: DateUtilsX.parse(j['delivered_at']),
    work: OrderUnitWork.parse(j['work']),
    issue: OrderUnitIssue.parse(j['issue']),
  );

  final String id;
  final String label;
  final OrderUnitBucket bucket;
  final String? serial;
  final String? lotCode;
  final String? condition;
  final String? location;

  /// Chỉ khi người xem có quyền giá đơn (`orders.cost`).
  final double? price;
  final DateTime? deliveredAt;
  final OrderUnitWork? work;
  final OrderUnitIssue? issue;

  /// Việc để mở khi chạm dòng: việc mang cờ, không thì việc xưởng.
  String? get taskId => issue?.taskId ?? work?.taskId;
}

/// Đơn + cây của đơn: đủ cho màn Chi tiết đơn (bản mẫu 7LZPEX "App · Đơn hàng").
class OrderUnits {
  const OrderUnits({
    required this.code,
    required this.customerName,
    required this.units,
    this.value = 0,
    this.paid = 0,
  });

  final String code;
  final String customerName;
  final double value;
  final double paid;
  final List<OrderUnit> units;

  int get total => units.length;

  /// Xong = sẵn sàng giao + đã giao (§3).
  int get done => units
      .where(
        (u) =>
            u.bucket == OrderUnitBucket.ready ||
            u.bucket == OrderUnitBucket.delivered,
      )
      .length;

  double get remaining => (value - paid) < 0 ? 0 : value - paid;

  int count(OrderUnitBucket b) => units.where((u) => u.bucket == b).length;

  /// Nhóm theo thứ tự màn, bỏ nhóm rỗng.
  List<(OrderUnitBucket, List<OrderUnit>)> get groups => [
    for (final b in OrderUnitBucket.values)
      if (units.where((u) => u.bucket == b).toList() case final list
          when list.isNotEmpty)
        (b, list),
  ];
}
