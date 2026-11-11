import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/active_tenant.dart';
import 'package:omni_app/core/network/dio_provider.dart';
import 'package:omni_app/core/storage/storage_keys.dart';
import 'package:omni_app/core/storage/token_store.dart';

/// Lỗi bảo mật (audit run-1, `token-resurrected-after-logout`).
///
/// Một request nghiệp vụ bị 401 mở lượt refresh; `/auth/refresh` trả 429 nên
/// lượt ấy chờ 5–32 giây. Người dùng đăng xuất trong lúc chờ — token bị xoá.
/// Lượt refresh xong sau đó GHI LẠI token mới của người cũ vào secure storage:
/// lần mở app sau, máy (dùng chung) vào thẳng tài khoản người vừa đăng xuất.
void main() {
  late _MemoryStorage storage;
  late _ScriptedAdapter adapter;
  late Completer<void> backoffGate;
  late Completer<void> backoffEntered;
  late ProviderContainer container;

  setUp(() {
    storage = _MemoryStorage()
      ..values[StorageKeys.accessToken] = 'A1'
      ..values[StorageKeys.refreshToken] = 'R1';
    adapter = _ScriptedAdapter();
    backoffGate = Completer<void>();
    backoffEntered = Completer<void>();
    container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(storage),
        refreshBackoffProvider.overrideWithValue((_) {
          if (!backoffEntered.isCompleted) backoffEntered.complete();
          return backoffGate.future;
        }),
      ],
    );
    container.read(activeTenantIdProvider.notifier).state = 't1';
  });

  tearDown(() => container.dispose());

  test('đăng xuất giữa lượt refresh → token cũ KHÔNG được ghi lại', () async {
    final dio = container.read(dioProvider)..httpClientAdapter = adapter;

    final pending = dio
        .get<Map<String, dynamic>>('/api/v1/tasks')
        .then<Object?>((r) => r, onError: (Object e) => e);

    // Lượt refresh đầu bị 429 và đang chờ.
    await backoffEntered.future;

    // Đăng xuất: xoá token (đúng việc `_clearCredentials` làm).
    await container.read(tokenStoreProvider).clear();
    expect(storage.values, isEmpty);

    // Hết chờ: lần refresh thứ hai trả 200 {A2, R2}.
    backoffGate.complete();
    await pending;

    expect(adapter.refreshCalls, 2);
    expect(
      storage.values[StorageKeys.refreshToken],
      isNull,
      reason: 'Refresh token mới của người đã đăng xuất bị ghi lại vào máy.',
    );
    expect(storage.values[StorageKeys.accessToken], isNull);
    expect(await container.read(tokenStoreProvider).readAccessToken(), isNull);
  });

  test('không đăng xuất → refresh vẫn lưu token mới như cũ', () async {
    final dio = container.read(dioProvider)..httpClientAdapter = adapter;
    backoffGate.complete();

    final response = await dio.get<Map<String, dynamic>>('/api/v1/tasks');

    expect(response.statusCode, 200);
    expect(storage.values[StorageKeys.accessToken], 'A2');
    expect(storage.values[StorageKeys.refreshToken], 'R2');
  });
}

class _ScriptedAdapter implements HttpClientAdapter {
  int refreshCalls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    const json = {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    };
    if (options.path.endsWith('/auth/refresh')) {
      refreshCalls++;
      if (refreshCalls == 1) {
        return ResponseBody.fromString(
          '{"message":"Too Many"}',
          429,
          headers: json,
        );
      }
      return ResponseBody.fromString(
        '{"success":true,"data":{"access_token":"A2","refresh_token":"R2"}}',
        200,
        headers: json,
      );
    }
    if (options.headers['Authorization'] == 'Bearer A2') {
      return ResponseBody.fromString(
        '{"success":true,"data":[]}',
        200,
        headers: json,
      );
    }
    return ResponseBody.fromString('{"success":false}', 401, headers: json);
  }

  @override
  void close({bool force = false}) {}
}

class _MemoryStorage implements FlutterSecureStorage {
  final values = <String, String>{};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values[key];

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
