import '../../../core/utils/json.dart';

/// `GET /customers/{id}/summary` (`GetCustomerSummary::execute`): chỉ đọc ba
/// khoá app dùng — `orders.total_amount`, `orders.count`, `opportunities_count`.
class CustomerSummary {
  const CustomerSummary({
    this.ordersTotal,
    this.ordersCount = 0,
    this.opportunitiesCount = 0,
  });

  final double? ordersTotal;
  final int ordersCount;
  final int opportunitiesCount;

  factory CustomerSummary.fromJson(Map<String, dynamic> json) {
    final orders = json['orders'];
    final map = orders is Map ? orders.cast<String, dynamic>() : null;
    return CustomerSummary(
      ordersTotal: map?.dbl('total_amount'),
      ordersCount: map?.intOr('count') ?? 0,
      opportunitiesCount: json.intOr('opportunities_count'),
    );
  }
}
