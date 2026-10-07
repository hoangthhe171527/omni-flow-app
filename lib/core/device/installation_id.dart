import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../storage/preferences_store.dart';

/// Khoá lưu [InstallationId] — tên trùng với `device_id` phía API (Đợt 8 B2).
const installationIdKey = 'installation_id';

/// Mã của MỘT lượt cài đặt app trên MỘT máy.
///
/// Vì sao cần: API xoá mọi token đẩy khác cùng `(tenant, user, platform)` mỗi
/// lần đăng ký (NT-I9). Một người dùng cả điện thoại và tablet thì máy đăng ký
/// sau đạp token của máy trước, nên chỉ một máy nhận được thông báo — và không
/// ai thấy lỗi gì. Server cần một khoá để phân biệt hai máy; khoá đó phải do
/// client giữ, vì token FCM ĐỔI (cấp lại sau khi xoá dữ liệu app, sau khi
/// khôi phục bản sao lưu) mà máy thì vẫn là máy đó.
///
/// Vì sao không dùng id thiết bị của hệ máy: Android `ANDROID_ID` và iOS
/// `identifierForVendor` cần quyền/plugin, và cả hai đều đổi theo cách khó
/// đoán. Một UUID tự sinh, lưu cạnh các tuỳ chọn khác, nói đúng điều cần nói:
/// "cùng một lượt cài đặt". Xoá dữ liệu app là một máy mới — đúng, vì token cũ
/// cũng chết cùng lúc đó.
///
/// KHÔNG phải thứ bí mật: nó không xác thực ai cả, chỉ phân biệt máy. Nên nó
/// nằm ở `SharedPreferences`, không phải Keychain.
class InstallationId {
  InstallationId(this._prefs);

  final SharedPreferences _prefs;

  /// Đọc mã đã lưu, hoặc sinh và lưu một mã mới.
  ///
  /// Đồng bộ: nơi gọi là lúc đăng ký token đẩy, nằm trong một chuỗi await
  /// khác; `SharedPreferences` đã nạp sẵn vào bộ nhớ nên đọc không cần chờ.
  /// Lượt `setString` được bắn đi mà không chờ — giá trị đã nằm trong bộ nhớ
  /// đệm ngay, và nếu app chết trước khi ghi xuống đĩa thì lần sau sinh lại
  /// một mã khác, không mất gì ngoài một dòng token cũ ở server.
  String get value {
    final existing = _prefs.getString(installationIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = _newUuidV4();
    _prefs.setString(installationIdKey, generated);
    return generated;
  }
}

final installationIdProvider = Provider<InstallationId>(
  (ref) => InstallationId(ref.watch(sharedPreferencesProvider)),
);

/// UUID v4 từ [Random.secure] — dự án không thêm gói mới cho một hàm 10 dòng.
String _newUuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  // Phiên bản 4 và biến thể RFC 4122, để id đọc được là UUID thật.
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  String hex(int from, int to) => bytes
      .sublist(from, to)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();

  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}
