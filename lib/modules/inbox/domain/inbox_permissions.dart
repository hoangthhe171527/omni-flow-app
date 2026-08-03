import '../../../security/permissions/access_policy.dart';
import '../../../security/permissions/access_scope.dart';
import '../../../security/permissions/resource_access.dart';

/// The inbox's permission vocabulary, owned by the inbox.
///
/// Mirrors `modules/Inbox/Interfaces/routes.php` on the API. Note the shape is
/// deliberately *not* the CRUD convention the CRM modules use: reading is
/// `inbox.read` / `inbox.read.own`, and every mutation — send, note, assign,
/// convert, label — sits behind the single `inbox.write`. Modelling that here,
/// rather than forcing it into a shared CRUD helper, is the point of letting
/// each module declare its own access.
abstract final class InboxPermissions {
  /// Whole tenant.
  static const read = 'inbox.read';

  /// Only conversations assigned to me. The unassigned pool is NOT included —
  /// an unassigned thread is invisible to a scoped member until it is handed
  /// over. The list header says so, because "0 hội thoại" with a busy inbox
  /// otherwise reads as a bug.
  static const readOwn = 'inbox.read.own';

  static const write = 'inbox.write';

  static const all = [read, readOwn, write];

  static const anyRead = [read, readOwn];
}

class InboxAccess extends ResourceAccess {
  InboxAccess._({required super.readScope, required bool canWrite})
    : super(
        canCreate: canWrite,
        canUpdate: canWrite,
        canDelete: canWrite,
        capabilities: canWrite
            ? const {'send', 'note', 'assign', 'convert', 'label'}
            : const {},
      );

  factory InboxAccess.of(AccessPolicy policy) => InboxAccess._(
    readScope: policy.scopeOf(InboxPermissions.read),
    canWrite: policy.can(InboxPermissions.write),
  );

  bool get canSend => can('send');
  bool get canNote => can('note');
  bool get canAssign => can('assign');
  bool get canConvert => can('convert');
  bool get canLabel => can('label');

  /// A member who only sees their own threads has no use for an assignee
  /// filter — every row would be theirs.
  bool get showsAssigneeFilter => readScope == AccessScope.all;
}
