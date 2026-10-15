import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../design/tokens/omni_covers.dart';

/// API riêng cho ảnh nền dự án.
///
/// Không nhét multipart vào `PlansApi`: phần còn lại của API dự án là JSON,
/// còn upload có vòng đời lỗi/retry riêng và được dùng độc lập sau khi dự án
/// đã có id.
class PlanCoverApi {
  PlanCoverApi(this._client);

  final ApiClient _client;

  Future<String> upload(String planId, String filePath) async {
    final response = await _client.upload(
      '/projects/$planId/cover',
      field: 'cover',
      filePath: filePath,
    );
    final cover = response.object['cover'];
    if (cover is! String || cover.trim().isEmpty) {
      throw const ServerException(
        'Máy chủ chưa trả về ảnh nền vừa tải lên.',
        code: 'project_cover_missing',
      );
    }
    return cover.trim();
  }

  Future<void> remove(String planId) async {
    await _client.delete('/projects/$planId/cover');
  }
}

final planCoverApiProvider = Provider<PlanCoverApi>(
  (ref) => PlanCoverApi(ref.watch(apiClientProvider)),
);

/// Chuẩn hoá URL cover do API trả về.
///
/// Route proxy được đổi sang API origin hiện tại để dữ liệu tạo ở một môi
/// trường cũ (localhost / host nội bộ) vẫn mở được sau khi deploy. URL CDN
/// ngoài route proxy được giữ nguyên. Token màu cũ trả null để UI dùng surface.
String? resolveProjectCoverUrl(String? value) {
  final source = value?.trim() ?? '';
  if (!OmniCovers.isImageReference(source)) return null;

  final parsed = Uri.tryParse(source);
  if (parsed == null) return null;
  final api = Uri.parse(AppConfig.apiBaseUrl);
  const proxyPrefix = '/api/v1/projects/media/';

  if (!parsed.hasScheme) {
    return api
        .replace(
          path: parsed.path,
          query: parsed.hasQuery ? parsed.query : null,
        )
        .toString();
  }

  if (parsed.path.startsWith(proxyPrefix)) {
    return api
        .replace(
          path: parsed.path,
          query: parsed.hasQuery ? parsed.query : null,
        )
        .toString();
  }

  return source;
}
