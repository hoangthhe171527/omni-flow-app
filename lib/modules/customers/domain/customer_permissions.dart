import '../../../security/permissions/access_policy.dart';
import '../../../security/permissions/resource_access.dart';

/// Customers follow the API's CRUD convention exactly, so this module leans on
/// [AccessPolicy.crud] rather than restating each slug — the contrast with the
/// inbox, which does not follow the convention, is the point of letting modules
/// own their own access shape.
abstract final class CustomerPermissions {
  static const base = 'crm.customers';

  static const read = '$base.read';
  static const readOwn = '$base.read.own';
  static const readTeam = '$base.read.team';
  static const readAll = '$base.read.all';
  static const create = '$base.create';
  static const update = '$base.update';
  static const delete = '$base.delete';

  static const anyRead = [read, readOwn, readTeam, readAll];

  static const all = [read, readOwn, readTeam, readAll, create, update, delete];

  static ResourceAccess of(AccessPolicy policy) => policy.crud(base);
}
