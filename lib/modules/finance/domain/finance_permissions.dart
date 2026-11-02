import '../../../security/permissions/access_policy.dart';
import '../../../security/permissions/resource_access.dart';

/// Quyền truy cập phân hệ Sổ chi phí (`finance.expenses.*`).
abstract final class FinancePermissions {
  static const String base = 'finance.expenses';

  static const String read = '$base.read';
  static const String create = '$base.create';
  static const String update = '$base.update';
  static const String delete = '$base.delete';

  static const List<String> anyRead = [read];
  static const List<String> all = [read, create, update, delete];

  static ResourceAccess of(AccessPolicy policy) => policy.crud(base);
}
