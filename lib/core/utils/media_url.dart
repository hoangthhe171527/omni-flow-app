import '../config/app_config.dart';

/// Rebinds old/local media URLs to the API origin the phone can actually reach.
/// Media files are public proxy resources, so this is safe for both thumbnails
/// and downloads.
String resolveMediaUrl(String value) {
  final source = value.trim();
  if (source.isEmpty) return source;
  final parsed = Uri.tryParse(source);
  if (parsed == null) return source;
  final api = Uri.parse(AppConfig.apiBaseUrl);
  const mediaPath = '/api/v1/inbox/media/';
  final marker = '/inbox/';
  final file = parsed.path.split('/').last;
  final isMediaPath =
      parsed.path.startsWith(mediaPath) ||
      parsed.path.contains('/storage/inbox/') ||
      parsed.path.contains('/public/inbox/');

  if (!parsed.hasScheme && parsed.path.startsWith(mediaPath)) {
    return api.replace(path: parsed.path).toString();
  }
  // Preserve public S3/CDN URLs. Only the legacy API/local-disk paths above
  // should be rebound to the current API origin.
  if (isMediaPath && file.isNotEmpty && !file.contains('..')) {
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
