import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/app_exception.dart';
import '../../core/network/active_tenant.dart';
import '../../core/storage/preferences_store.dart';
import '../../core/storage/storage_keys.dart';
import '../../core/storage/token_store.dart';
import 'auth_gateway.dart';
import 'session.dart';

typedef PreLogoutCallback = Future<void> Function();

/// A feature-neutral boundary for work that needs the current auth and tenant
/// context immediately before an explicit logout.
///
/// Session owns the ordering, while the app shell binds feature cleanup without
/// making security import notifications (which would create a dependency
/// cycle through inbox providers).
class SessionPreLogout {
  PreLogoutCallback? _callback;

  void Function() register(PreLogoutCallback callback) {
    _callback = callback;
    return () {
      if (identical(_callback, callback)) _callback = null;
    };
  }

  Future<void> run() async {
    await _callback?.call();
  }
}

final sessionPreLogoutProvider = Provider<SessionPreLogout>(
  (ref) => SessionPreLogout(),
);

/// Owns the session for the whole app: restore on launch, log in, pick a
/// tenant, log out, and end the session when the API says the token is dead.
class SessionController extends Notifier<Session> {
  Timer? _restoreRetryTimer;

  @override
  Session build() {
    // A 401 on any business endpoint ends the session. Listening here (rather
    // than letting the network layer import this file) keeps the dependency
    // pointing one way: security → core, never core → security.
    ref.listen<int>(unauthorizedSignalProvider, (previous, next) {
      if (previous != null && next > previous && state.hasCredentials) {
        _clearCredentials();
        state = const Session.expired();
      }
    });

    ref.onDispose(() => _restoreRetryTimer?.cancel());

    Future.microtask(restore);
    return const Session.restoring();
  }

  TokenStore get _tokens => ref.read(tokenStoreProvider);
  PreferencesStore get _prefs => ref.read(preferencesStoreProvider);
  AuthGateway get _gateway => ref.read(authGatewayProvider);
  SessionPreLogout get _preLogout => ref.read(sessionPreLogoutProvider);

  /// Launch path: token in secure storage + tenant in prefs → rebuild context.
  Future<void> restore() async {
    _restoreRetryTimer?.cancel();
    _restoreRetryTimer = null;

    final accessToken = await _tokens.readAccessToken();
    final refreshToken = await _tokens.readRefreshToken();
    final hasAccessToken = accessToken != null && accessToken.isNotEmpty;
    final hasRefreshToken = refreshToken != null && refreshToken.isNotEmpty;
    if (!hasAccessToken && !hasRefreshToken) {
      state = const Session.unauthenticated();
      return;
    }

    if (hasRefreshToken) {
      try {
        // Rotate at launch so regularly-used installs retain their rolling
        // server session without asking for credentials again.
        final tokens = await _gateway.refresh(refreshToken);
        await _tokens.save(
          accessToken: tokens.accessToken,
          refreshToken: tokens.refreshToken,
        );
      } on UnauthorizedException {
        await _clearCredentials();
        state = const Session.expired();
        return;
      } on AppException {
        // A temporary offline/server failure must not erase local credentials.
      }
    }

    final tenantId = _prefs.getString(StorageKeys.tenantId);
    if (tenantId == null || tenantId.isEmpty) {
      state = const Session(status: SessionStatus.tenantPending);
      return;
    }

    ref.read(activeTenantIdProvider.notifier).state = tenantId;
    await _loadContext(retryOnTransientFailure: true);
  }

  Future<void> login({required String email, required String password}) async {
    state = const Session.restoring();
    try {
      final tokens = await _gateway.login(email: email, password: password);
      await _tokens.save(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );

      // A token issued by /auth/login is not yet tenant-scoped. Auto-enter the
      // workspace when there is exactly one; otherwise the picker takes over.
      final tenants = await _gateway.tenants();
      if (tenants.length == 1) {
        await selectTenant(tenants.first.id);
        return;
      }
      state = const Session(status: SessionStatus.tenantPending);
    } on AppException {
      await _clearCredentials();
      state = const Session.unauthenticated();
      rethrow;
    }
  }

  Future<void> selectTenant(String tenantId) async {
    final tokens = await _gateway.switchTenant(tenantId);
    await _tokens.save(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
    await _prefs.setString(StorageKeys.tenantId, tenantId);
    ref.read(activeTenantIdProvider.notifier).state = tenantId;
    await _loadContext(retryOnTransientFailure: true);
  }

  Future<void> refreshContext() => _loadContext();

  Future<void> logout() async {
    try {
      // Push unregister must run before /auth/logout and before local
      // credentials/tenant are cleared so Dio can authenticate the DELETE.
      await _preLogout.run();
    } catch (error, stackTrace) {
      // Feature cleanup is best-effort and must never trap a user in session.
      debugPrint('Pre-logout cleanup failed: $error\n$stackTrace');
    }
    try {
      await _gateway.logout();
    } on AppException {
      // Best-effort: a failed server logout must never trap the user in the app.
    }
    await _clearCredentials();
    state = const Session.unauthenticated();
  }

  Future<AccountDeletionReceipt> requestAccountDeletion({
    required String password,
  }) async {
    final receipt = await _gateway.requestAccountDeletion(password: password);
    // The server disables the account, revokes every session and removes push
    // tokens before returning 202. Clear the local copy only after that succeeds
    // so a transient network error cannot strand the user without feedback.
    await _clearCredentials();
    state = const Session.unauthenticated();
    return receipt;
  }

  Future<void> _loadContext({bool retryOnTransientFailure = false}) async {
    final previous = state;
    try {
      state = await _gateway.loadContext();
    } on UnauthorizedException {
      await _clearCredentials();
      state = const Session.expired();
    } on AppException {
      // Offline periods, timeouts and server errors do not revoke a session.
      // Keep secure credentials and retry startup automatically.
      if (retryOnTransientFailure) {
        state = const Session.restoring();
        _scheduleRestoreRetry();
      } else {
        state = previous;
        rethrow;
      }
    }
  }

  void _scheduleRestoreRetry() {
    if (_restoreRetryTimer?.isActive ?? false) return;
    _restoreRetryTimer = Timer(const Duration(seconds: 5), restore);
  }

  Future<void> _clearCredentials() async {
    await _tokens.clear();
    await _prefs.remove(StorageKeys.tenantId);
    ref.read(activeTenantIdProvider.notifier).state = null;
  }
}

final sessionControllerProvider = NotifierProvider<SessionController, Session>(
  SessionController.new,
);

/// Read this — not the controller — anywhere you only need to *look at* the
/// session. Keeps rebuild scope tight.
final sessionProvider = Provider<Session>((ref) {
  return ref.watch(sessionControllerProvider);
});

/// The permission policy for the current session. Every gate in the app starts
/// here: nav destinations, route guards, buttons, list scopes.
final accessProvider = Provider((ref) => ref.watch(sessionProvider).policy);
