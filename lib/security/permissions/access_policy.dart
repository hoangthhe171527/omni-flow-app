import 'access_scope.dart';
import 'resource_access.dart';

/// Reads a session's permission slugs. The single source of truth for "may the
/// current user…" everywhere in the app — nav, routes, buttons, list filters.
///
/// This is client-side *presentation* gating. The API enforces the same rules
/// again on every request; hiding an action here is a courtesy, never the
/// security boundary.
class AccessPolicy {
  const AccessPolicy(this._permissions);

  const AccessPolicy.empty() : _permissions = const {};

  final Set<String> _permissions;

  Set<String> get slugs => _permissions;

  bool can(String slug) => _permissions.contains(slug);

  bool canAny(Iterable<String> slugs) => slugs.any(_permissions.contains);

  bool canAll(Iterable<String> slugs) => slugs.every(_permissions.contains);

  /// Resolves `<base>` / `<base>.all` / `<base>.team` / `<base>.own` into a scope.
  /// `base` is the read slug without a suffix, e.g. `crm.customers.read`.
  AccessScope scopeOf(String base) {
    if (can(base) || can('$base.all')) return AccessScope.all;
    if (can('$base.team')) return AccessScope.team;
    if (can('$base.own')) return AccessScope.own;
    return AccessScope.none;
  }

  /// Convention-based CRUD for resources that follow
  /// `<resource>.read|create|update|delete`, which is most of the CRM surface.
  ResourceAccess crud(
    String resource, {
    Set<String> capabilities = const {},
  }) {
    return ResourceAccess(
      readScope: scopeOf('$resource.read'),
      canCreate: can('$resource.create'),
      canUpdate: can('$resource.update'),
      canDelete: can('$resource.delete'),
      capabilities: {
        for (final capability in capabilities)
          if (can('$resource.$capability')) capability,
      },
    );
  }
}
