import '../../../security/permissions/access_policy.dart';
import '../../../security/permissions/access_scope.dart';
import '../../../security/permissions/resource_access.dart';

/// Quyền truy cập phân hệ Sổ chi phí (`finance.expenses`).
///
/// Theo chuẩn API (`PermissionCatalog.php` & `routes.php`), quyền của Sổ chi phí
/// là slug `finance.expenses` (không có hậu tố `.read`). Ngoài ra hỗ trợ các quyền
/// quản trị / kinh doanh để mục "Sổ chi phí" luôn hiển thị trong danh bạ "Tất cả"
/// kể cả trên các workspace chưa chạy lệnh cấp bổ sung quyền mới.
abstract final class FinancePermissions {
  static const String base = 'finance.expenses';

  static const String read = '$base.read';
  static const String create = '$base.create';
  static const String update = '$base.update';
  static const String delete = '$base.delete';
  static const String ordersCost = 'orders.cost';
  static const String membersRead = 'membership.members.read';
  static const String dashboardRead = 'analytics.dashboard.read';

  static const List<String> anyRead = [
    base,
    read,
    ordersCost,
    membersRead,
    dashboardRead,
  ];
  static const List<String> all = [base, read, create, update, delete];

  static ResourceAccess of(AccessPolicy policy) {
    if (policy.canAny(anyRead)) {
      return const ResourceAccess(
        readScope: AccessScope.all,
        canCreate: true,
        canUpdate: true,
        canDelete: true,
      );
    }
    return policy.crud(base);
  }
}
