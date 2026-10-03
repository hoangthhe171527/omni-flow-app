import '../config/app_config.dart';

/// Dựng lại host cho đường proxy media của Hộp thư về API origin mà điện thoại
/// tới được; giữ NGUYÊN khoá sau `/api/v1/inbox/media/` và query.
///
/// Từ Đợt 4 khoá có tiền tố tenant (`<tenant>/<uuid>.jpg`). Trước Đợt 5 hàm này
/// chỉ giữ tên tệp cuối, nên mọi ảnh mới mất `<tenant>/` và trả 404 (APP-I1).
/// Dạng đĩa `/storage/inbox/` và `/public/inbox/` cũng giữ toàn bộ phần sau
/// tiền tố (disk `public` trả `/storage/inbox/<tenant>/<uuid>.jpg`).
/// URL S3/CDN công khai không đổi.
String resolveMediaUrl(String value) {
  final source = value.trim();
  if (source.isEmpty) return source;
  // Một URL media hợp lệ không bao giờ có đoạn `..` trong ĐƯỜNG. `Uri.parse`
  // tự giải mã `%2e` rồi gộp dot-segment (đường thành chỗ khác hẳn), nên kiểm
  // trên phần đường của chuỗi gốc, đã giải mã — không kiểm query.
  if (_hasDotDotPath(source)) return '';
  final parsed = Uri.tryParse(source);
  if (parsed == null) return source;
  final api = Uri.parse(AppConfig.apiBaseUrl);
  const mediaPath = '/api/v1/inbox/media/';
  final marker = '/inbox/';
  final query = parsed.hasQuery ? parsed.query : null;
  String rebind(String path) =>
      api.replace(path: path, query: query).toString();

  if (parsed.path.startsWith(mediaPath)) {
    // Giữ NGUYÊN phần sau /api/v1/inbox/media/ — gồm cả `<tenant>/` của khoá
    // mới (Đợt 4). Chỉ đổi host.
    final rest = parsed.path.substring(mediaPath.length);
    if (rest.isEmpty) return source;
    return rebind('$mediaPath$rest');
  }
  // Preserve public S3/CDN URLs. Only the local-disk paths below should be
  // rebound to the current API origin.
  for (final diskPrefix in const ['/storage/inbox/', '/public/inbox/']) {
    final at = parsed.path.indexOf(diskPrefix);
    if (at < 0) continue;
    final rest = parsed.path.substring(at + diskPrefix.length);
    if (rest.isEmpty) return source;
    return rebind('$mediaPath$rest');
  }
  if (!parsed.hasScheme && parsed.path.startsWith('/')) {
    return rebind(parsed.path);
  }
  // The server sometimes returns a bare filename for old local records.
  if (!parsed.hasScheme && !source.contains('/') && source != marker) {
    return api.replace(path: '$mediaPath$source').toString();
  }
  return source;
}

final _dotDotSegment = RegExp(r'(^|/)\.\.($|/)');

bool _hasDotDotPath(String source) {
  final cut = source.indexOf(RegExp(r'[?#]'));
  final rawPath = cut < 0 ? source : source.substring(0, cut);
  String decoded;
  try {
    decoded = Uri.decodeFull(rawPath);
  } catch (_) {
    decoded = rawPath;
  }
  decoded = decoded.replaceAll(r'\', '/');
  return _dotDotSegment.hasMatch(decoded);
}
