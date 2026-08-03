import '../../../security/permissions/access_policy.dart';
import '../../../security/permissions/resource_access.dart';

abstract final class OpportunityPermissions {
  static const base = 'crm.sales_opportunities';

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

abstract final class QuotePermissions {
  static const base = 'crm.quotes';

  static const read = '$base.read';
  static const readTeam = '$base.read.team';
  static const readAll = '$base.read.all';
  static const create = '$base.create';
  static const update = '$base.update';
  static const delete = '$base.delete';

  /// Manager-only. The quote screen hides the approve/reject bar without it,
  /// because a rep tapping an action they can't perform is a support ticket.
  static const approve = '$base.approve';

  static const anyRead = [read, readTeam, readAll];

  static const all = [read, readTeam, readAll, create, update, delete, approve];

  static ResourceAccess of(AccessPolicy policy) =>
      policy.crud(base, capabilities: const {'approve'});
}
