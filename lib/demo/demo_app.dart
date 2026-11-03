import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/dio_provider.dart';
import '../core/realtime/realtime_client.dart';
import '../core/storage/storage_keys.dart';
import '../core/storage/token_store.dart';
import 'demo_backend.dart';
import 'demo_seed.dart';
import 'modules/auth_demo.dart';
import 'modules/crm_demo.dart';
import 'modules/inbox_demo.dart';
import 'modules/work_demo.dart';

/// Toàn bộ "máy chủ" của bản demo.
DemoRoutes buildDemoRoutes() {
  final routes = DemoRoutes();
  final links = DemoLinks();
  registerAuthDemo(routes);
  registerInboxDemo(routes, links);
  // work trước crm: `/system-options/task-labels` (work) phải khớp trước
  // `/system-options/{id}` (crm).
  registerWorkDemo(routes);
  registerCrmDemo(routes, links);
  return routes;
}

/// Override cho bản demo: mạng giả, phiên đã đăng nhập sẵn (token chỉ nằm
/// trong RAM), tắt realtime (không có máy chủ socket nào).
Future<List<Override>> demoOverrides(SharedPreferences preferences) async {
  // Phiên khôi phục đọc workspace từ prefs: chọn sẵn workspace mẫu.
  await preferences.setString(StorageKeys.tenantId, demoTenantId);
  await preferences.setString(StorageKeys.tenantName, demoTenantName);

  final HttpClientAdapter adapter = DemoApiAdapter(buildDemoRoutes());
  return [
    httpClientAdapterProvider.overrideWithValue(adapter),
    secureStorageProvider.overrideWithValue(
      _MemorySecureStorage({
        StorageKeys.accessToken: 'demo-access-token',
        StorageKeys.refreshToken: 'demo-refresh-token',
      }),
    ),
    realtimeConfigProvider.overrideWithValue(const RealtimeConfig.disabled()),
  ];
}

/// Secure storage trong RAM: bản demo không ghi token nào xuống máy.
class _MemorySecureStorage extends FlutterSecureStorage {
  _MemorySecureStorage(Map<String, String> initial) : _values = {...initial};

  final Map<String, String> _values;

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _values[key];

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
      _values.remove(key);
    } else {
      _values[key] = value;
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
  }) async => _values.remove(key);
}
