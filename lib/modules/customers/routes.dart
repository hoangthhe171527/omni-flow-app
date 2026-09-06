/// Tên route của module khách hàng. Xem `tasks/routes.dart` về lý do file này
/// không import gì.
library;

abstract final class CustomerRoutes {
  static const list = 'customers.list';
  static const detail = 'customers.detail';
  static const create = 'customers.create';
  static const edit = 'customers.edit';
}
