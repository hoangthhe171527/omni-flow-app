import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Build-time / runtime configuration.
///
/// Resolution order for every value: `--dart-define` first (so CI builds are
/// reproducible without shipping a `.env`), then `.env`, then a safe default.
abstract final class Env {
  static const defaultApiBaseUrl = 'https://omni-api.app.sunriseieco.vn';

  static String get apiBaseUrl => _normalizeBaseUrl(
    _read(const String.fromEnvironment('API_BASE_URL'), 'API_BASE_URL') ??
        defaultApiBaseUrl,
  );

  static String get appName =>
      _read(const String.fromEnvironment('APP_NAME'), 'APP_NAME') ?? 'Viomni';

  /// Realtime (Reverb / Pusher protocol). Empty disables realtime entirely —
  /// the app then falls back to pull-to-refresh + polling on the inbox.
  static String get realtimeKey =>
      _read(const String.fromEnvironment('REALTIME_KEY'), 'REALTIME_KEY') ?? '';

  static String get realtimeHost =>
      _read(const String.fromEnvironment('REALTIME_HOST'), 'REALTIME_HOST') ??
      '';

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
