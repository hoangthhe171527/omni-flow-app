import '../../../security/permissions/access_policy.dart';
import '../../../security/permissions/access_scope.dart';
import '../../../security/permissions/resource_access.dart';

/// The task module's permission vocabulary, owned by the task module.
///
/// Mirrors `modules/Tasks/Interfaces/routes.php` on the API, which gates reads
/// behind `tasks.read` and every mutation behind `tasks.write`. Unlike the
/// inbox there is no `.own` variant: per-project roles do the narrowing
/// server-side, so the client has one read permission and one write permission.
abstract final class TaskPermissions {
  static const read = 'tasks.read';

  static const write = 'tasks.write';

  static const all = [read, write];

  static const anyRead = [read];
}

class TaskAccess extends ResourceAccess {
  TaskAccess._({required super.readScope, required bool canWrite})
    : super(
        canCreate: canWrite,
        canUpdate: canWrite,
        canDelete: canWrite,
        capabilities: canWrite
            ? const {'complete', 'comment', 'attach'}
            : const {},
      );

  factory TaskAccess.of(AccessPolicy policy) {
    final canRead = policy.can(TaskPermissions.read);

    return TaskAccess._(
      // The API narrows by project membership rather than by an `.own` scope,
      // so from the client's side a reader simply sees what it is served.
      readScope: canRead ? AccessScope.all : AccessScope.none,
      canWrite: policy.can(TaskPermissions.write),
    );
  }

  /// Ticking a stage, changing status — the whole point of the app for a worker.
  bool get canComplete => can('complete');

  bool get canComment => can('comment');

  bool get canAttach => can('attach');
}
