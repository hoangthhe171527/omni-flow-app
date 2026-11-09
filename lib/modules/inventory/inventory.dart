/// Bề mặt công khai của module Kho hàng.
///
/// Module khác chỉ import file này: tên route và quyền. KHÔNG xuất lớp module
/// (xem `customers.dart`).
library;

export 'domain/inventory_permissions.dart';
export 'routes.dart';
