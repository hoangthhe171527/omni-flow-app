import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/json.dart';
import '../../../security/permissions/access_policy.dart';
import '../../../security/session/auth_gateway.dart';
import '../../../security/session/session.dart';

/// HTTP calls for `/api/v1/auth/*`, plus the mapping into session types.
class AuthApi implements AuthGateway {
  AuthApi(this._client);

  final ApiClient _client;

  @override
  Future<AuthTokens> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      '/auth/login',
      body: {'email': email, 'password': password, 'client_type': 'mobile'},
    );
    return _tokens(response.object);
  }

  @override
  Future<List<TenantOption>> tenants() async {
    final response = await _client.get('/auth/tenants');
    return response.list
        .map((row) {
          final tenant = row.child('tenant');
          final membership = row.child('membership');
          return TenantOption(
            id: tenant.strOr('id', ''),
            name: tenant.strOr('name', 'Không gian làm việc'),
            code: tenant.str('code'),
            memberCount: membership['member_count'] is num
                ? (membership['member_count'] as num).toInt()
                : null,
            planLabel: tenant.child('settings').str('plan_label'),
          );
        })
        .where((option) => option.id.isNotEmpty)
        .toList();
  }

  @override
  Future<AuthTokens> switchTenant(String tenantId) async {
    final response = await _client.post(
      '/auth/switch-tenant',
      body: {'tenant_id': tenantId},
    );
    return _tokens(response.object);
  }

  @override
  Future<AuthTokens> refresh(String refreshToken) async {
    final response = await _client.post(
      '/auth/refresh',
      body: {'refresh_token': refreshToken},
    );
    return _tokens(response.object);
  }

  @override
  Future<Session> loadContext() async {
    // Two calls because the API splits them: /auth/me is the person,
    // /auth/context is who they are *inside this tenant* (roles + permissions).
    final results = await Future.wait([
      _client.get('/auth/me'),
      _client.get('/auth/context'),
    ]);

    final me = results[0].object;
    final context = results[1].object;

    final userJson = me.child('user');
    final tenantJson = context.child('tenant');
    final membershipJson = context.child('membership');

    return Session(
      status: SessionStatus.authenticated,
      user: SessionUser(
        id: userJson.strOr('id', ''),
        fullName: userJson.strOr(
          'full_name',
          userJson.strOr('email', 'Người dùng'),
        ),
        email: userJson.strOr('email', ''),
        phone: userJson.str('phone'),
        avatarUrl: userJson.str('avatar'),
        locale: userJson.str('locale'),
      ),
      tenant: SessionTenant(
        id: tenantJson.strOr('id', ''),
        name: tenantJson.strOr('name', ''),
        code: tenantJson.str('code'),
      ),
      membershipId: membershipJson.str('id'),
      roles: context.mapList('roles').map((role) {
        return SessionRole(
          id: role.strOr('id', ''),
          slug: role.strOr('slug', ''),
          name: role.strOr('name', role.strOr('slug', '')),
        );
      }).toList(),
      policy: AccessPolicy(context.strList('permissions').toSet()),
    );
  }

  @override
  Future<void> logout() async {
    await _client.post('/auth/logout');
  }

  AuthTokens _tokens(Map<String, dynamic> json) => AuthTokens(
    accessToken: json.strOr('access_token', ''),
    refreshToken: json.str('refresh_token'),
    expiresIn: json['expires_in'] is num
        ? (json['expires_in'] as num).toInt()
        : null,
  );
}

final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(ref.watch(apiClientProvider));
});
