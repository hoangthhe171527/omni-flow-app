import '../../../security/permissions/access_policy.dart';
import '../../../security/permissions/access_scope.dart';
import '../../../security/permissions/resource_access.dart';

/// Quyền truy cập phân hệ Sổ chi phí (`finance.expenses`).
///
/// Theo chuẩn API (`PermissionCatalog.php`, `SystemRolePresets.php` và
/// `routes.php`), quyền của Sổ chi phí là slug đơn `finance.expenses` và chỉ
/// preset Admin được cấp quyền này. Không dùng quyền bán hàng, nhân sự hay
/// dashboard làm quyền dự phòng: chúng khiến người không phải Admin nhìn thấy
/// giao diện tài chính rồi bị API từ chối khi thao tác.
abstract final class FinancePermissions {
  static const String base = 'finance.expenses';

  /// Dùng cùng một yêu cầu cho menu và route để deep link cũng không lách qua
  /// được lớp ẩn giao diện.
  static const List<String> adminOnly = [base];
  static const List<String> all = adminOnly;

  static ResourceAccess of(AccessPolicy policy) {
    if (policy.can(base)) {
      return const ResourceAccess(
        readScope: AccessScope.all,
        canCreate: true,
        canUpdate: true,
        canDelete: true,
      );
    }
    return ResourceAccess.denied;
  }
}
