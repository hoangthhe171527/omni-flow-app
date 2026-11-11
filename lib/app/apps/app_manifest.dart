import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../security/session/session.dart';
import '../../security/session/session_controller.dart';

/// Tên khả năng API của bản khai báo ứng dụng (`GET /api/v1/apps`). API cũ
/// không có → app chạy như trước khi có khung ứng dụng.
const appsManifestCapability = 'apps.manifest';

/// Cờ tính năng bật khung ứng dụng cho một công ty (`tenant_features.php`).
const appShellFeature = 'app_shell';

/// Một mục trong ứng dụng của bản khai báo: chỉ là KHOÁ — app tự ánh xạ khoá
/// sang màn của mình (`app_shell_layout.dart`), khoá lạ thì bỏ qua.
class ManifestItem {
  const ManifestItem(this.key, {this.group});

  final String key;

  /// `reports` = mục báo cáo (vẽ dưới nhãn nhỏ trong "Thêm").
  final String? group;

  bool get isReport => group == 'reports';
}

class ManifestApp {
  const ManifestApp({
    required this.key,
    required this.name,
    required this.order,
    required this.enabled,
    required this.items,
  });

  final String key;
  final String name;
  final int order;

  /// Công ty bật ứng dụng này (cờ `app_*`).
  final bool enabled;
  final List<ManifestItem> items;
}

/// Bản khai báo ứng dụng (`omni-flow-api` `AppManifest::forFeatures`):
/// `{shell, home: [keys], apps: [{key, name, order, enabled, items}]}`.
class AppManifest {
  const AppManifest({
    required this.shell,
    this.home = const [],
    this.apps = const [],
  });

  factory AppManifest.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> maps(Object? v) => v is List
        ? [
            for (final e in v)
              if (e is Map) e.cast<String, dynamic>(),
          ]
        : const [];

    return AppManifest(
      shell: json['shell'] == true,
      home: [
        for (final k
            in (json['home'] is List ? json['home'] as List : const []))
          if (k is String) k,
      ],
      apps: [
        for (final (i, a) in maps(json['apps']).indexed)
          if (a['key'] is String)
            ManifestApp(
              key: a['key'] as String,
              name: a['name'] is String ? a['name'] as String : '',
              order: a['order'] is num ? (a['order'] as num).toInt() : i,
              enabled: a['enabled'] != false,
              items: [
                for (final item in maps(a['items']))
                  if (item['key'] is String)
                    ManifestItem(
                      item['key'] as String,
                      group: item['group'] is String
                          ? item['group'] as String
                          : null,
                    ),
              ],
            ),
      ],
    );
  }

  final bool shell;
  final List<String> home;
  final List<ManifestApp> apps;
}

/// Phiên có thể dùng khung ứng dụng không — biết ngay từ `/auth/context`, không
/// chờ mạng: cờ `app_shell` BẬT (khoá thiếu = tắt, ngược với cờ module) và API
/// có [appsManifestCapability]. Sai thì app y như cũ.
bool sessionWantsAppShell(Session s) =>
    s.isAuthenticated &&
    s.features[appShellFeature] == true &&
    s.apiSupports(appsManifestCapability);

/// Bản khai báo của công ty đang chọn. `null` = không dùng khung ứng dụng
/// (cờ tắt, API cũ, hoặc tải lỗi — lỗi thì app chạy như cũ chứ không chặn).
final appManifestProvider = FutureProvider<AppManifest?>((ref) async {
  // Chỉ tải lại khi đổi công ty / cờ / bản API — không phải mỗi lần phiên
  // đổi một trường bất kỳ.
  final (wants, _) = ref.watch(
    sessionProvider.select((s) => (sessionWantsAppShell(s), s.tenant?.id)),
  );
  if (!wants) return null;
  try {
    final response = await ref.watch(apiClientProvider).get('/apps');
    return AppManifest.fromJson(response.object);
  } on Object {
    return null;
  }
});
