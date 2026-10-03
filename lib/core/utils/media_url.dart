import '../config/app_config.dart';

/// Dựng lại host cho đường proxy media của Hộp thư về API origin mà điện thoại
/// tới được; giữ NGUYÊN khoá sau `/api/v1/inbox/media/`.
///
/// Từ Đợt 4 khoá có tiền tố tenant (`<tenant>/<uuid>.jpg`). Trước Đợt 5 hàm này
/// chỉ giữ tên tệp cuối, nên mọi ảnh mới mất `<tenant>/` và trả 404 (APP-I1).
/// Dạng cũ `/storage/inbox/` và `/public/inbox/` vẫn chỉ lấy tên tệp cuối.
/// URL S3/CDN công khai không đổi.
String resolveMediaUrl(String value) {
  final source = value.trim();
  if (source.isEmpty) return source;
  // Một URL media hợp lệ không bao giờ có đoạn `..`. `Uri.parse` tự gộp chúng
  // (đường thành chỗ khác hẳn), nên chặn trên chuỗi gốc thay vì trên `parsed`.
  if (_dotDotSegment.hasMatch(source)) return '';
  final parsed = Uri.tryParse(source);
  if (parsed == null) return source;
  final api = Uri.parse(AppConfig.apiBaseUrl);
  const mediaPath = '/api/v1/inbox/media/';
  final marker = '/inbox/';
  final file = parsed.path.split('/').last;

  if (parsed.path.startsWith(mediaPath)) {
    // Giữ NGUYÊN phần sau /api/v1/inbox/media/ — gồm cả `<tenant>/` của khoá
    // mới (Đợt 4). Chỉ đổi host.
    final rest = parsed.path.substring(mediaPath.length);
    if (rest.isEmpty) return source;
    return api.replace(path: '$mediaPath$rest').toString();
  }
  final isLegacyMediaPath =
      parsed.path.contains('/storage/inbox/') ||
      parsed.path.contains('/public/inbox/');
  // Preserve public S3/CDN URLs. Only the legacy local-disk paths above
  // should be rebound to the current API origin.
  if (isLegacyMediaPath && file.isNotEmpty && !file.contains('..')) {
    return api.replace(path: '$mediaPath$file').toString();
  }
  if (!parsed.hasScheme && parsed.path.startsWith('/')) {
    return api.replace(path: parsed.path).toString();
  }
  // The server sometimes returns a bare filename for old local records.
  if (!parsed.hasScheme && !source.contains('/') && source != marker) {
    return api.replace(path: '$mediaPath$source').toString();
  }
  return source;
}

final _dotDotSegment = RegExp(r'(^|/)\.\.($|/|\?|#)');
