import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/core/storage/preferences_store.dart';
import 'package:omni_app/core/storage/storage_keys.dart';
import 'package:omni_app/modules/settings/application/appearance_providers.dart';
import 'package:omni_app/modules/settings/data/appearance_api.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Nền đọc từ TÀI KHOẢN khi đã đăng nhập, từ cache máy khi chưa; đổi thì
/// hiện ngay, gọi API, lỗi thì hoàn về.
void main() {
  late _FakeApi api;
  late _FakeSessionController sessions;

  Future<ProviderContainer> container({
    Session session = const Session(status: SessionStatus.restoring),
    String? cached,
  }) async {
    SharedPreferences.setMockInitialValues({
      StorageKeys.background: ?cached,
    });
    final prefs = PreferencesStore(await SharedPreferences.getInstance());
    api = _FakeApi();
    sessions = _FakeSessionController(session);
    final c = ProviderContainer(
      overrides: [
        preferencesStoreProvider.overrideWithValue(prefs),
        appearanceApiProvider.overrideWithValue(api),
        sessionControllerProvider.overrideWith(() => sessions),
      ],
    );
    addTearDown(c.dispose);

    return c;
  }

  test('chưa có phiên thì lấy cache máy — mở app không nháy nền', () async {
    final c = await container(cached: 'sea');

    expect(c.read(backgroundProvider), 'sea');
  });

  test('có phiên thì tài khoản thắng cache', () async {
    final c = await container(
      cached: 'sea',
      session: const Session(
        status: SessionStatus.authenticated,
        user: SessionUser(
          id: 'u',
          fullName: 'H',
          email: 'h@x',
          background: 'walnut',
        ),
      ),
    );

    expect(c.read(backgroundProvider), 'walnut');
  });

  test('set: hiện ngay, gọi API, ghi cache, làm mới phiên', () async {
    final c = await container(
      session: const Session(
        status: SessionStatus.authenticated,
        user: SessionUser(id: 'u', fullName: 'H', email: 'h@x'),
      ),
    );

    final future = c.read(backgroundProvider.notifier).set('felt');
    expect(
      c.read(backgroundProvider),
      'felt',
      reason: 'lạc quan, trước khi API về',
    );
    await future;

    expect(api.sent, ['felt']);
    expect(
      (await SharedPreferences.getInstance()).getString(StorageKeys.background),
      'felt',
    );
    expect(sessions.refreshed, 1);
  });

  test('API lỗi thì hoàn về giá trị cũ và ném lại', () async {
    final c = await container(
      session: const Session(
        status: SessionStatus.authenticated,
        user: SessionUser(
          id: 'u',
          fullName: 'H',
          email: 'h@x',
          background: 'sea',
        ),
      ),
    );
    api.fail = true;

    await expectLater(
      c.read(backgroundProvider.notifier).set('felt'),
      throwsA(isA<AppException>()),
    );
    expect(c.read(backgroundProvider), 'sea');
    expect(sessions.refreshed, 0);
  });
}

class _FakeApi implements AppearanceApi {
  final sent = <String?>[];
  bool fail = false;

  @override
  Future<void> setBackground(String? name) async {
    if (fail) throw const NetworkException('Mất mạng rồi');
    sent.add(name);
  }
}

class _FakeSessionController extends SessionController {
  _FakeSessionController(this._session);

  final Session _session;
  int refreshed = 0;

  @override
  Session build() => _session;

  @override
  Future<void> refreshContext() async => refreshed++;
}
