/// Public surface of the customers module.
///
/// Other modules import this and nothing deeper: the inbox links a thread to a
/// profile, opportunities pick a customer. Reaching past this barrel into
/// `presentation/` or `data/` is what turns modules back into one tangled app.
library;

export 'application/customers_providers.dart';
export 'customers_module.dart' show CustomersModule;
export 'domain/customer.dart';
export 'domain/customer_permissions.dart';
export 'presentation/customer_picker_sheet.dart';
