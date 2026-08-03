import 'access_scope.dart';

/// What the current session may do with one resource.
///
/// Built by each module from its own permission slugs — there is deliberately
/// no central `switch (entity)` that every module has to be edited into.
class ResourceAccess {
  const ResourceAccess({
    this.readScope = AccessScope.none,
    this.canCreate = false,
    this.canUpdate = false,
    this.canDelete = false,
    this.capabilities = const {},
  });

  static const denied = ResourceAccess();

  final AccessScope readScope;
  final bool canCreate;
  final bool canUpdate;
  final bool canDelete;

  /// Verbs beyond CRUD, named by the module: `approve`, `assign`, `convert`,
  /// `send`, `confirm`. Kept as strings so adding one never touches this class.
  final Set<String> capabilities;

  bool get canRead => readScope.isGranted;

  bool can(String capability) => capabilities.contains(capability);

  bool get hasAnyMutation =>
      canCreate || canUpdate || canDelete || capabilities.isNotEmpty;

  ResourceAccess copyWith({
    AccessScope? readScope,
    bool? canCreate,
    bool? canUpdate,
    bool? canDelete,
    Set<String>? capabilities,
  }) {
    return ResourceAccess(
      readScope: readScope ?? this.readScope,
      canCreate: canCreate ?? this.canCreate,
      canUpdate: canUpdate ?? this.canUpdate,
      canDelete: canDelete ?? this.canDelete,
      capabilities: capabilities ?? this.capabilities,
    );
  }
}
