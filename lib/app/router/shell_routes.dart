/// Route names owned by the app shell itself rather than by any module.
abstract final class ShellRoutes {
  static const splash = 'shell.splash';
  static const more = 'shell.more';
  static const forbidden = 'shell.forbidden';

  /// Màn Chọn ứng dụng (khung ứng dụng, cờ `app_shell`).
  static const apps = 'shell.apps';

  static const splashPath = '/';
  static const morePath = '/more';
  static const forbiddenPath = '/forbidden';
  static const appsPath = '/apps';
}
