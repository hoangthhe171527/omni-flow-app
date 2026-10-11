import '../../inbox/domain/inbox_permissions.dart';
import '../../tasks/domain/task_permissions.dart';

/// Quyền của màn Tổng quan. Doanh thu cùng quyền với `/sales-overview/*`
/// (route middleware `permission:crm.sales_overview.read,…read.all`).
abstract final class DashboardPermissions {
  static const revenue = [
    'crm.sales_overview.read',
    'crm.sales_overview.read.all',
  ];
  static const anyRead = [
    ...revenue,
    TaskPermissions.read,
    ...InboxPermissions.anyRead,
  ];
}
