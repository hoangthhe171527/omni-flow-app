import '../permissions/access_policy.dart';

/// The permission a route or nav destination demands.
///
/// Attached to each route *by the module that owns it* — there is no central map
/// of path → permission, and no `location.startsWith('/crm/...')` prefix
/// matching. Adding a screen means adding one route in one module file.
class AccessRequirement {
  const AccessRequirement.any(this.permissions) : requireAll = false;

  const AccessRequirement.all(this.permissions) : requireAll = true;

  /// No permission needed (login, forbidden, the workspace picker).
  const AccessRequirement.open() : permissions = const [], requireAll = false;

  final List<String> permissions;
  final bool requireAll;

  bool get isOpen => permissions.isEmpty;

  bool isSatisfiedBy(AccessPolicy policy) {
    if (isOpen) return true;
    return requireAll ? policy.canAll(permissions) : policy.canAny(permissions);
  }
}
