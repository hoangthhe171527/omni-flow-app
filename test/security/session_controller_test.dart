import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/core/network/active_tenant.dart';
import 'package:omni_app/core/storage/preferences_store.dart';
import 'package:omni_app/core/storage/storage_keys.dart';
import 'package:omni_app/core/storage/token_store.dart';
import 'package:omni_app/security/session/auth_gateway.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'runs push unregister before server logout and credential clear',
    () async {
      final harness = await _SessionHarness.create();
      addTearDown(harness.dispose);
      harness.preLogout.register(() async {
        expect(harness.tokens.hasCredentials, isTrue);
        expect(harness.preferences.hasTenant, isTrue);
        expect(harness.activeTenantId, 'tenant-1');
        harness.events.add('push.unregister');
      });

      await harness.controller.logout();

      expect(harness.events, [
        'push.unregister',
        'server.logout',
        'credentials.clear',
        'tenant.clear',
      ]);
      expect(harness.session.status, SessionStatus.unauthenticated);
      expect(harness.activeTenantId, isNull);
    },
  );

  test('failed push unregister and server logout cannot trap logout', () async {
    final harness = await _SessionHarness.create(serverLogoutFails: true);
    addTearDown(harness.dispose);
    harness.preLogout.register(() async {
      harness.events.add('push.unregister');
      throw StateError('push API unavailable');
    });

    await harness.controller.logout();

    expect(harness.events, [
      'push.unregister',
      'server.logout',
      'credentials.clear',
      'tenant.clear',
    ]);
    expect(harness.tokens.hasCredentials, isFalse);
    expect(harness.preferences.hasTenant, isFalse);
    expect(harness.session.status, SessionStatus.unauthenticated);
  });

  test(
    'unauthorized expiry keeps its existing direct-clear behavior',
    () async {
      final harness = await _SessionHarness.create();
      addTearDown(harness.dispose);
      var preLogoutCalls = 0;
      harness.preLogout.register(() async => preLogoutCalls++);

      harness.container.read(unauthorizedSignalProvider.notifier).state++;
      await harness.waitForStatus(SessionStatus.expired);

      expect(preLogoutCalls, 0);
      expect(harness.tokens.hasCredentials, isFalse);
      expect(harness.preferences.hasTenant, isFalse);
      expect(harness.activeTenantId, isNull);
    },
  );

  test(
    'account deletion clears the local session after server acceptance',
    () async {
      final harness = await _SessionHarness.create();
      addTearDown(harness.dispose);

      final receipt = await harness.controller.requestAccountDeletion(
        password: 'DeleteMe123!',
      );

      expect(receipt.scheduledFor, DateTime.utc(2026, 9, 7));
      expect(harness.events, [
        'account.delete',
        'credentials.clear',
        'tenant.clear',
      ]);
      expect(harness.session.status, SessionStatus.unauthenticated);
      expect(harness.activeTenantId, isNull);
    },
  );

  test(
    'temporary restore failure keeps credentials for automatic retry',
    () async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.tenantId: 'tenant-1',
      });
      final sharedPreferences = await SharedPreferences.getInstance();
      final events = <String>[];
      final tokens = _RecordingTokenStore(
        events,
        refreshToken: 'refresh-token',
      );
      final container = ProviderContainer(
        overrides: [
          tokenStoreProvider.overrideWithValue(tokens),
          preferencesStoreProvider.overrideWithValue(
            _RecordingPreferencesStore(sharedPreferences, events),
          ),
          authGatewayProvider.overrideWithValue(
            _RecordingAuthGateway(
              events,
              logoutFails: false,
              restoreFailure: const NetworkException('offline'),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(sessionControllerProvider);
      for (var attempt = 0; attempt < 20; attempt++) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(
        container.read(sessionControllerProvider).status,
        SessionStatus.restoring,
      );
      expect(tokens.hasCredentials, isTrue);
      expect(sharedPreferences.getString(StorageKeys.tenantId), 'tenant-1');
      expect(events, isNot(contains('credentials.clear')));
    },
  );
}

class _SessionHarness {
  _SessionHarness({
    required this.container,
    required this.events,
    required this.tokens,
    required this.preferences,
    required this.preLogout,
  });

  static Future<_SessionHarness> create({
    bool serverLogoutFails = false,
  }) async {
    SharedPreferences.setMockInitialValues({StorageKeys.tenantId: 'tenant-1'});
    final sharedPreferences = await SharedPreferences.getInstance();
    final events = <String>[];
    final tokens = _RecordingTokenStore(events);
    final preferences = _RecordingPreferencesStore(sharedPreferences, events);
    final preLogout = SessionPreLogout();
    final gateway = _RecordingAuthGateway(
      events,
      logoutFails: serverLogoutFails,
    );
    final container = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(tokens),
        preferencesStoreProvider.overrideWithValue(preferences),
        authGatewayProvider.overrideWithValue(gateway),
        sessionPreLogoutProvider.overrideWithValue(preLogout),
      ],
    );
    container.read(activeTenantIdProvider.notifier).state = 'tenant-1';
    container.read(sessionControllerProvider);
    final harness = _SessionHarness(
      container: container,
      events: events,
      tokens: tokens,
      preferences: preferences,
      preLogout: preLogout,
    );
    await harness.waitForStatus(SessionStatus.authenticated);
    events.clear();
    return harness;
  }

  final ProviderContainer container;
  final List<String> events;
  final _RecordingTokenStore tokens;
  final _RecordingPreferencesStore preferences;
  final SessionPreLogout preLogout;

  SessionController get controller =>
      container.read(sessionControllerProvider.notifier);

  Session get session => container.read(sessionControllerProvider);

  String? get activeTenantId => container.read(activeTenantIdProvider);

  Future<void> waitForStatus(SessionStatus status) async {
    for (var attempt = 0; attempt < 20; attempt++) {
      final expiredCleanupFinished =
          !tokens.hasCredentials &&
          !preferences.hasTenant &&
          activeTenantId == null;
      if (session.status == status &&
          (status != SessionStatus.expired || expiredCleanupFinished)) {
        return;
      }
      await Future<void>.delayed(Duration.zero);
    }
    fail('Session never reached $status; current status is ${session.status}.');
  }

  void dispose() => container.dispose();
}

class _RecordingTokenStore extends TokenStore {
  _RecordingTokenStore(this.events, {this.refreshToken})
    : super(const FlutterSecureStorage());

  final List<String> events;
  final String? refreshToken;
  bool hasCredentials = true;

  @override
  Future<String?> readAccessToken() async =>
      hasCredentials ? 'access-token' : null;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> clear() async {
    events.add('credentials.clear');
    hasCredentials = false;
  }
}

class _RecordingPreferencesStore extends PreferencesStore {
  _RecordingPreferencesStore(super.preferences, this.events);

  final List<String> events;

  bool get hasTenant => getString(StorageKeys.tenantId)?.isNotEmpty ?? false;

  @override
  Future<void> remove(String key) async {
    if (key == StorageKeys.tenantId) events.add('tenant.clear');
    await super.remove(key);
  }
}

class _RecordingAuthGateway implements AuthGateway {
  _RecordingAuthGateway(
    this.events, {
    required this.logoutFails,
    this.restoreFailure,
  });

  final List<String> events;
  final bool logoutFails;
  final AppException? restoreFailure;

  @override
  Future<Session> loadContext() async {
    if (restoreFailure case final failure?) throw failure;
    return const Session(status: SessionStatus.authenticated);
  }

  @override
  Future<void> logout() async {
    events.add('server.logout');
    if (logoutFails) throw const NetworkException('offline');
  }

  @override
  Future<AccountDeletionReceipt> requestAccountDeletion({
    required String password,
  }) async {
    events.add('account.delete');
    return AccountDeletionReceipt(scheduledFor: DateTime.utc(2026, 9, 7));
  }

  @override
  Future<AuthTokens> login({required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<AuthTokens> refresh(String refreshToken) async {
    if (restoreFailure case final failure?) throw failure;
    return const AuthTokens(
      accessToken: 'access-refreshed',
      refreshToken: 'refresh-rotated',
    );
  }

  @override
  Future<AuthTokens> switchTenant(String tenantId) =>
      throw UnimplementedError();

  @override
  Future<List<TenantOption>> tenants() => throw UnimplementedError();
}
