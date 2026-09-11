abstract final class StorageKeys {
  // Secure storage (Keychain / EncryptedSharedPreferences).
  static const accessToken = 'omni.access_token';
  static const refreshToken = 'omni.refresh_token';

  // Preferences (non-sensitive).
  static const tenantId = 'omni.tenant_id';
  static const tenantName = 'omni.tenant_name';
  static const locale = 'omni.locale';
  static const themeMode = 'omni.theme_mode';

  /// Nền cả app đã chọn lần cuối, để mở app không nháy nền trước khi
  /// `/auth/me` về. Nguồn sự thật là tài khoản; đây chỉ là bản chép.
  static const background = 'omni.background';
  static const lastInboxFilter = 'omni.inbox.last_filter';

  /// Tiền tố; khoá thật là `<tiền tố>.<id công việc>`. Hàng chờ tick việc con
  /// chưa được server xác nhận của MỘT công việc — xem `SubtaskOutbox`.
  static const subtaskOutbox = 'omni.tasks.subtask_outbox';
}
