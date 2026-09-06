/// Public surface of the customers module.
///
/// Other modules import this and nothing deeper: the inbox links a thread to a
/// profile, opportunities pick a customer. Reaching past this barrel into
/// `presentation/` or `data/` is what turns modules back into one tangled app.
library;

export 'application/customers_providers.dart';
// KHÔNG xuất lớp module. Module khác chỉ cần TÊN ROUTE, và lấy nó qua
//  — một file hằng số không import gì. Xuất lớp module ở đây
// là mở lại đúng cửa hậu đã tạo ra chu trình customers ↔ opportunities.
export 'routes.dart';
export 'domain/customer.dart';
export 'domain/customer_permissions.dart';
export 'presentation/customer_picker_sheet.dart';
