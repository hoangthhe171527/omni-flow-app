import '../config/app_config.dart';

/// Makes a server-mirrored avatar URL usable from a real phone.
///
/// Old conversations can contain a URL written while the API had `APP_URL` set
/// to localhost, an internal Docker hostname, or http. Those addresses work
/// from the API container but can never be loaded by Android. Avatar files are
/// public API resources, so they can safely be rebound to the active API origin.
String? resolveAvatarUrl(String? value) {
  final source = value?.trim();
  if (source == null || source.isEmpty) return null;

  final url = Uri.tryParse(source);
  if (url == null) return source;

  final api = Uri.parse(AppConfig.apiBaseUrl);
  const avatarPath = '/api/v1/inbox/avatar/';

  // Unlike a browser, Flutter's NetworkImage cannot resolve a relative URL
  // against the current page origin. The API may return this form when its
  // public APP_URL is configured as a relative path or when an old mirror was
  // stored without the origin.
  if (!url.hasScheme && url.path.startsWith(avatarPath)) {
    return api
        .replace(path: url.path, query: url.hasQuery ? url.query : null)
        .toString();
  }

  final host = url.host.toLowerCase();
  final isInternalHost =
      host == 'localhost' ||
      host == '127.0.0.1' ||
      host == '0.0.0.0' ||
      host == 'app' ||
      host == 'web' ||
      host == 'minio' ||
      host.startsWith('omnicrm-') ||
      host.endsWith('.local');

  // Older mirrors may have been exposed as /storage/avatars/... or directly
  // from an internal MinIO host. Android cannot reach those origins; the API
  // proxy is the stable public contract for mobile clients.
  final avatarMarker = '/avatars/';
  final markerIndex = url.path.indexOf(avatarMarker);
  if (markerIndex >= 0 && (isInternalHost || !url.path.startsWith(avatarPath))) {
    final file = url.path.substring(markerIndex + avatarMarker.length);
    if (file.isNotEmpty && !file.contains('/')) {
      return api.replace(path: '$avatarPath$file').toString();
    }
  }

  if (!url.path.startsWith(avatarPath)) return source;
  final needsHttps = host == api.host.toLowerCase() && url.scheme != api.scheme;

  if (!isInternalHost && !needsHttps) return source;

  return api
      .replace(path: url.path, query: url.hasQuery ? url.query : null)
      .toString();
}
