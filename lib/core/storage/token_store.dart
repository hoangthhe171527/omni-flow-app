import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'storage_keys.dart';

/// Owns the credentials on device.
///
/// Deliberately dependency-free: the Dio interceptor reads tokens from here, so
/// putting them behind the auth module would make `core/network` depend on a
/// feature module.
class TokenStore {
  TokenStore(this._storage);

  final FlutterSecureStorage _storage;

  /// Access token đã đọc — hoặc đang đọc — từ secure storage.
  ///
  /// Interceptor của Dio hỏi token cho TỪNG request, và secure storage là
  /// Keychain/Keystore qua platform channel: một round-trip native trên đường
  /// nóng của mọi request. Đọc một lần rồi giữ trong RAM; giữ cả Future đang
  /// bay chứ không chỉ cờ "đã tải", vì lúc mở app năm request bắn cùng lúc
  /// trước khi lượt đọc đầu kịp về. [save] và [clear] cập nhật cache, nên
  /// không có cửa sổ nào token trong RAM lệch với token vừa xoay.
  Future<String?>? _access;

  Future<String?> readAccessToken() => _access ??= _loadAccessToken();

  Future<String?> _loadAccessToken() async {
    try {
      return await _storage.read(key: StorageKeys.accessToken);
    } catch (_) {
      // Không cache lỗi: lần hỏi sau thử lại đĩa thay vì kẹt với lỗi cũ.
      _access = null;
      rethrow;
    }
  }

  /// Không qua cache: chỉ dùng khi xoay phiên, hiếm — và là chỗ một giá trị
  /// cũ trong RAM gây hại nhất (xoay bằng token đã bị thu hồi).
  Future<String?> readRefreshToken() =>
      _storage.read(key: StorageKeys.refreshToken);

  /// Thế hệ phiên: tăng mỗi lần [clear] (đăng xuất, phiên hết hạn).
  ///
  /// Việc chạy nền mở ra TRƯỚC khi phiên kết thúc — lượt refresh đang chờ
  /// 429 chẳng hạn — ghi nhớ thế hệ lúc bắt đầu và chỉ được lưu kết quả qua
  /// [saveIfCurrent]. Không có nó, token mới của người vừa đăng xuất bị ghi
  /// lại vào máy và lần mở app sau vào thẳng tài khoản của họ.
  int _generation = 0;

  int get generation => _generation;

  Future<void> save({required String accessToken, String? refreshToken}) async {
    final generation = _generation;
    // Cache trước, đĩa sau: request kế tiếp dùng token mới ngay, kể cả khi
    // lượt ghi Keychain còn đang bay.
    _access = Future.value(accessToken);
    await _storage.write(key: StorageKeys.accessToken, value: accessToken);
    // Đăng xuất chen vào giữa hai lượt ghi: lượt xoá của nó đã xếp sau lượt
    // ghi access token, nhưng ghi refresh token lúc này sẽ hồi sinh phiên.
    if (generation != _generation) return;
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.write(key: StorageKeys.refreshToken, value: refreshToken);
    }
  }

  /// [save] nếu phiên chưa đổi kể từ thế hệ [generation]; trả `false` (và
  /// không ghi gì) nếu đã có một lần [clear] chen vào.
  Future<bool> saveIfCurrent(
    int generation, {
    required String accessToken,
    String? refreshToken,
  }) async {
    if (generation != _generation) return false;
    await save(accessToken: accessToken, refreshToken: refreshToken);
    return generation == _generation;
  }

  Future<void> clear() async {
    _generation++;
    _access = null;
    await _storage.delete(key: StorageKeys.accessToken);
    await _storage.delete(key: StorageKeys.refreshToken);
  }
}

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
});

final tokenStoreProvider = Provider<TokenStore>((ref) {
  return TokenStore(ref.watch(secureStorageProvider));
});
