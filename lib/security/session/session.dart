import '../permissions/access_policy.dart';

enum SessionStatus {
  /// Still reading storage — the router must not redirect yet.
  restoring,

  /// Signed in but no tenant chosen: the workspace picker owns the screen.
  tenantPending,
  authenticated,
  unauthenticated,

  /// Was authenticated, then the API answered 401. Shown as "phiên đã hết hạn".
  expired,
}

class SessionUser {
  const SessionUser({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.locale,
  });

  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final String? locale;
}

class SessionTenant {
  const SessionTenant({required this.id, required this.name, this.code});

  final String id;
  final String name;
  final String? code;
}

class SessionRole {
  const SessionRole({required this.id, required this.slug, required this.name});

  final String id;
  final String slug;
  final String name;
}

/// Everything the app knows about who is using it.
///
/// Note what is *not* here: no `MobileRole` enum. Roles are tenant-configurable
/// on the server, so mapping them to a fixed client-side enum — and then
/// branching the whole UI on it — breaks the moment a tenant renames or adds
/// one. The UI branches on [policy] (permissions) instead; [roles] is kept only
/// for display and support diagnostics.
class Session {
  const Session({
    required this.status,
    this.user,
    this.tenant,
    this.membershipId,
    this.roles = const [],
    this.policy = const AccessPolicy.empty(),
  });

  const Session.restoring() : this(status: SessionStatus.restoring);

  const Session.unauthenticated() : this(status: SessionStatus.unauthenticated);

  const Session.expired() : this(status: SessionStatus.expired);

  final SessionStatus status;
  final SessionUser? user;
  final SessionTenant? tenant;
  final String? membershipId;
  final List<SessionRole> roles;
  final AccessPolicy policy;

  bool get isRestoring => status == SessionStatus.restoring;

  bool get isAuthenticated => status == SessionStatus.authenticated;

  bool get needsTenant => status == SessionStatus.tenantPending;

  /// Signed in at the token level — true both before and after a tenant is picked.
  bool get hasCredentials => isAuthenticated || needsTenant;

  String get displayName => user?.fullName ?? '';

  String get roleLabel =>
      roles.isEmpty ? 'Thành viên' : roles.map((r) => r.name).join(', ');

  Session copyWith({
    SessionStatus? status,
    SessionUser? user,
    SessionTenant? tenant,
    String? membershipId,
    List<SessionRole>? roles,
    AccessPolicy? policy,
  }) {
    return Session(
      status: status ?? this.status,
      user: user ?? this.user,
      tenant: tenant ?? this.tenant,
      membershipId: membershipId ?? this.membershipId,
      roles: roles ?? this.roles,
      policy: policy ?? this.policy,
    );
  }
}
