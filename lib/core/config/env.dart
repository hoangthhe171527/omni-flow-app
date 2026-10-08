import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Build-time / runtime configuration.
///
/// Resolution order for every value: `--dart-define` first (so CI builds are
/// reproducible without shipping a `.env`), then `.env`, then a safe default.
abstract final class Env {
  static const defaultApiBaseUrl = 'https://omni-api.app.sunriseieco.vn';
  static const defaultGoogleSsoServerClientId =
      '858803204032-i3lv9du7r7dgcsd57e0r82emie00r8i3.apps.googleusercontent.com';
  static const defaultGoogleSsoIosClientId =
      '858803204032-doeqcqgftmn0itu2ip9oej6gtlggjj1h.apps.googleusercontent.com';

  static String get apiBaseUrl => _normalizeBaseUrl(
    _read(const String.fromEnvironment('API_BASE_URL'), 'API_BASE_URL') ??
        defaultApiBaseUrl,
  );

  static String get appName =>
      _read(const String.fromEnvironment('APP_NAME'), 'APP_NAME') ?? 'Viomni';

  /// Web OAuth client used by the API to verify the Google ID token audience.
  /// OAuth client IDs are public identifiers, not secrets.
  static String get googleSsoServerClientId =>
      _read(
        const String.fromEnvironment('GOOGLE_SSO_SERVER_CLIENT_ID'),
        'GOOGLE_SSO_SERVER_CLIENT_ID',
      ) ??
      defaultGoogleSsoServerClientId;

  /// iOS application OAuth client. OAuth client IDs are public identifiers;
  /// the default matches the Viomni bundle registered in Google Cloud.
  static String get googleSsoIosClientId =>
      _read(
        const String.fromEnvironment('GOOGLE_SSO_IOS_CLIENT_ID'),
        'GOOGLE_SSO_IOS_CLIENT_ID',
      ) ??
      defaultGoogleSsoIosClientId;

  static String? get googleSsoApplicationClientId =>
      defaultTargetPlatform == TargetPlatform.iOS ? googleSsoIosClientId : null;

  /// Realtime (Reverb / Pusher protocol). Empty disables realtime entirely —
  /// the app then falls back to pull-to-refresh + polling on the inbox.
  static String get realtimeKey =>
      _read(const String.fromEnvironment('REALTIME_KEY'), 'REALTIME_KEY') ?? '';

  static String get realtimeHost =>
      _read(const String.fromEnvironment('REALTIME_HOST'), 'REALTIME_HOST') ??
      '';

  /// `https` in production (Reverb behind TLS), `http` for a local server.
  static String get realtimeScheme =>
      _read(
        const String.fromEnvironment('REALTIME_SCHEME'),
        'REALTIME_SCHEME',
      ) ??
      'https';

  static bool get realtimeUseTls => realtimeScheme.toLowerCase() == 'https';

  /// Defaults to the scheme's own port, which is what a Reverb behind a reverse
  /// proxy uses. A directly-exposed Reverb wants its own (8080 by default).
  static int get realtimePort {
    final raw = _read(
      const String.fromEnvironment('REALTIME_PORT'),
      'REALTIME_PORT',
    );
    return int.tryParse(raw ?? '') ?? (realtimeUseTls ? 443 : 80);
  }

  static bool get isRealtimeEnabled =>
      realtimeKey.isNotEmpty && realtimeHost.isNotEmpty;

  static String? _read(String fromDefine, String key) {
    if (fromDefine.isNotEmpty) return fromDefine;
    if (!dotenv.isInitialized) return null;
    final value = dotenv.env[key]?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  static String _normalizeBaseUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return defaultApiBaseUrl;
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }
}
