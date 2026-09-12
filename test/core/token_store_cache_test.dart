import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/storage/storage_keys.dart';
import 'package:omni_app/core/storage/token_store.dart';

/// Access token đọc secure storage MỘT lần, rồi sống trong RAM.
///
/// Interceptor của Dio hỏi token cho từng request. Secure storage là
/// Keychain/Keystore qua platform channel — một round-trip native trên đường
/// nóng của mọi request, kể cả khi màn hộp thư bắn năm request cùng lúc lúc mở
/// app. `save`/`clear` cập nhật cache nên không có cửa sổ nào token trong RAM
/// lệch với token vừa xoay.
void main() {
  late _CountingStorage storage;
  late TokenStore store;

  setUp(() {
    storage = _CountingStorage();
    store = TokenStore(storage);
  });

  test('đọc 3 lần → chạm secure storage 1 lần', () async {
    storage.values[StorageKeys.accessToken] = 'jwt-1';

    expect(await store.readAccessToken(), 'jwt-1');
    expect(await store.readAccessToken(), 'jwt-1');
    expect(await store.readAccessToken(), 'jwt-1');

    expect(storage.reads, 1);
  });

  test('3 request đồng thời lúc mở app cũng chỉ đọc đĩa 1 lần', () async {
    storage.values[StorageKeys.accessToken] = 'jwt-1';

    final results = await Future.wait([
      store.readAccessToken(),
      store.readAccessToken(),
      store.readAccessToken(),
    ]);

    expect(results, ['jwt-1', 'jwt-1', 'jwt-1']);
    expect(
      storage.reads,
      1,
      reason: 'Cờ "đã tải" không đủ: lượt đọc đang bay phải được dùng chung.',
    );
  });

  test('save rồi đọc → giá trị mới, không đọc đĩa', () async {
    await store.save(accessToken: 'jwt-2', refreshToken: 'r-2');

    expect(await store.readAccessToken(), 'jwt-2');
    expect(storage.reads, 0);
    expect(
      storage.values[StorageKeys.accessToken],
      'jwt-2',
      reason: 'Vẫn ghi đĩa: lần mở app sau còn phiên.',
    );
    expect(storage.values[StorageKeys.refreshToken], 'r-2');
  });

  test('clear → lần đọc tiếp trả null và đọc đĩa lại đúng 1 lần', () async {
    storage.values[StorageKeys.accessToken] = 'jwt-1';
    await store.readAccessToken();
    expect(storage.reads, 1);

    await store.clear();

    expect(await store.readAccessToken(), isNull);
    expect(await store.readAccessToken(), isNull);
    expect(storage.reads, 2);
    expect(storage.values.containsKey(StorageKeys.accessToken), isFalse);
  });

  test('đọc đĩa lỗi thì lần sau thử lại, không kẹt với lỗi cũ', () async {
    storage.failNextRead = true;
    await expectLater(store.readAccessToken(), throwsStateError);

    storage.values[StorageKeys.accessToken] = 'jwt-1';
    expect(await store.readAccessToken(), 'jwt-1');
    expect(storage.reads, 2);
  });

  test('refresh token không đi qua cache: đọc là đọc đĩa', () async {
    // Chỉ dùng khi xoay phiên, hiếm; và đây là chỗ một giá trị cũ trong RAM
    // gây hại nhất (xoay bằng token đã bị thu hồi).
    storage.values[StorageKeys.refreshToken] = 'r-1';
    expect(await store.readRefreshToken(), 'r-1');
    storage.values[StorageKeys.refreshToken] = 'r-2';
    expect(await store.readRefreshToken(), 'r-2');
  });
}

class _CountingStorage implements FlutterSecureStorage {
  final values = <String, String>{};
  int reads = 0;
  bool failNextRead = false;

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    reads++;
    if (failNextRead) {
      failNextRead = false;
      throw StateError('Keystore không mở được.');
    }
    return values[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
