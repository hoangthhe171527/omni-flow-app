import '../../../core/utils/formatters.dart';
import '../../../core/utils/json.dart';

/// Trạng thái thu tiền của đơn (`pay_status`).
enum OrderPayStatus {
  unpaid('Chưa thu'),
  partial('Thu một phần'),
  paid('Đã thu đủ');

  const OrderPayStatus(this.label);
  final String label;

  static OrderPayStatus parse(Object? raw) => switch (raw) {
    'paid' => paid,
    'partial' => partial,
    _ => unpaid,
  };
}

/// Hình thức thu (`ORDER_PAYMENT_METHODS` của web).
enum PaymentMethod {
  cash('cash', 'Tiền mặt'),
  transfer('transfer', 'Chuyển khoản'),
  card('card', 'Thẻ'),
  other('other', 'Khác');

  const PaymentMethod(this.wire, this.label);
  final String wire;
  final String label;

  static PaymentMethod parse(Object? raw) => values.firstWhere(
    (m) => m.wire == raw,
    orElse: () => PaymentMethod.other,
  );
}

/// Một dòng của danh sách đơn (`GET /orders`).
class OrderRow {
  const OrderRow({
    required this.id,
    required this.code,
    required this.customerName,
    this.product = '',
    this.value = 0,
    this.paid = 0,
    this.status = 'new',
    this.payStatus = OrderPayStatus.unpaid,
    this.createdAt,
  });

  factory OrderRow.fromJson(Map<String, dynamic> j) => OrderRow(
    id: j.strOr('id', ''),
    code: j.str('code') ?? j.strOr('id', ''),
    customerName: j.strOr('customer_name', ''),
    product: j.strOr('product', ''),
    value: j.dbl('value') ?? 0,
    paid: j.dbl('paid') ?? 0,
    status: j.strOr('status', 'new'),
    payStatus: OrderPayStatus.parse(j['pay_status']),
    createdAt: DateUtilsX.parse(j['closed_at'] ?? j['created_at']),
  );

  final String id;
  final String code;
  final String customerName;
  final String product;
  final double value;
  final double paid;
  final String status;
  final OrderPayStatus payStatus;
  final DateTime? createdAt;

  bool get cancelled => status == 'cancelled';
  double get remaining => cancelled || paid >= value ? 0 : value - paid;
}

/// Một đợt thu trong sổ thu của đơn (`payments[]`).
class OrderPayment {
  const OrderPayment({
    required this.id,
    required this.amount,
    this.paidAt,
    this.method = PaymentMethod.other,
    this.note,
  });

  factory OrderPayment.fromJson(Map<String, dynamic> j) => OrderPayment(
    id: j.strOr('id', ''),
    amount: j.dbl('amount') ?? 0,
    paidAt: DateUtilsX.parse(j['paid_at']),
    method: PaymentMethod.parse(j['method']),
    note: j.str('note'),
  );

  final String id;
  final double amount;
  final DateTime? paidAt;
  final PaymentMethod method;
  final String? note;
}

/// Lọc danh sách đơn (bản mẫu NWUQNP): Cần thu (mặc định), Đang xử lý, Tất cả.
enum OrderListFilter { due, processing, all }

/// Dòng tổng của danh sách: `GET /orders/summary`.
typedef OrdersDue = ({double outstanding, int awaiting});
