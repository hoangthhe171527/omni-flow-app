/// Public surface of the opportunities module.
library;

export 'application/opportunities_providers.dart';
export 'domain/opportunity.dart';
export 'domain/opportunity_permissions.dart';
export 'domain/pipeline_catalog.dart';
export 'presentation/customer_opportunities_section.dart'
    show opportunitiesCustomerSection;
export 'presentation/opportunities_segment.dart' show opportunitiesKhachSegment;
// KHÔNG xuất lớp module — xem ghi chú trong customers.dart.
export 'routes.dart';
