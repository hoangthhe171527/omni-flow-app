import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// Ảnh đại diện của CHÍNH người đang đăng nhập.
///
/// Đường TỰ PHỤC VỤ trên `/auth`, cạnh `locale` và `notification-prefs`. Cố ý
/// không đi qua `/identity/users/{id}`: đường đó đòi `membership.members.update`
/// mà vai `worker` không có, nên người thợ sẽ không tự đổi được ảnh của mình.
class AvatarApi {
  AvatarApi(this._client);

  final ApiClient _client;

  /// Trả về URL ảnh mới do SERVER sinh.
  ///
  /// Không tự dựng URL ở client: server là nơi quyết định ảnh nằm trên đĩa
  /// local hay S3, và một bản sao luật đó ở đây sẽ lệch ngay lần đầu triển
  /// khai đổi đĩa.
  Future<String> upload(String filePath) async {
    final response = await _client.upload(
      '/auth/avatar',
      field: 'file',
      filePath: filePath,
    );

    return response.object['avatar']?.toString() ?? '';
  }

  Future<void> remove() => _client.delete('/auth/avatar');
}

final avatarApiProvider = Provider<AvatarApi>(
  (ref) => AvatarApi(ref.watch(apiClientProvider)),
);
