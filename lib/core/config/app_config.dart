import 'env.dart';

abstract final class AppConfig {
  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// Every list endpoint on omnicrm-pro-api caps `per_page` at 100.
  static const int maxPerPage = 100;
  static const int defaultPerPage = 30;

  /// Cursor page size for the chat thread (newest-first, `before` cursor).
  static const int messagePageSize = 30;

  static String get apiBaseUrl => Env.apiBaseUrl;
  static String get apiPrefix => '/api/v1';
  static String get appName => Env.appName;
}
