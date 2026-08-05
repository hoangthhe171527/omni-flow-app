import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session.dart';

/// A tenant the signed-in user may enter.
class TenantOption {
  const TenantOption({
    required this.id,
    required this.name,
    this.code,
    this.memberCount,
    this.planLabel,
  });

  final String id;
  final String name;
  final String? code;
  final int? memberCount;
  final String? planLabel;
}

/// What the session controller needs from the outside world.
///
/// Declared here — in `security`, which owns session state — and implemented in
/// `modules/auth`. That inversion is what keeps `core` and `security` free of
/// any dependency on a feature module.
abstract interface class AuthGateway {
  Future<AuthTokens> login({required String email, required String password});

  Future<List<TenantOption>> tenants();

  /// Exchanges the current token for one scoped to [tenantId].
  Future<AuthTokens> switchTenant(String tenantId);

  Future<AuthTokens> refresh(String refreshToken);

  /// Loads `/auth/context` — user, tenant, membership, roles, permissions.
  Future<Session> loadContext();

  Future<void> logout();
}

class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    this.refreshToken,
    this.expiresIn,
  });

  final String accessToken;
  final String? refreshToken;
  final int? expiresIn;
}

/// Bound in `bootstrap.dart` to the auth module's implementation.
final authGatewayProvider = Provider<AuthGateway>((ref) {
  throw UnimplementedError('authGatewayProvider must be overridden');
});
