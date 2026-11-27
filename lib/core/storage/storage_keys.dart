abstract final class StorageKeys {
  // Secure storage (Keychain / EncryptedSharedPreferences).
  static const accessToken = 'omni.access_token';
  static const refreshToken = 'omni.refresh_token';

  // Preferences (non-sensitive).
  static const tenantId = 'omni.tenant_id';
  static const tenantName = 'omni.tenant_name';
  static const locale = 'omni.locale';
  static const themeMode = 'omni.theme_mode';

  /// Hiệu ứng (bậc hiệu năng) người dùng chọn: auto / full / reduced / minimal.
  static const perfPreference = 'omni.perf_preference';

  /// Bậc đã tự hạ vì đo thấy giật ở chế độ Tự động.
  static const perfLearnedTier = 'omni.perf_learned_tier';

  /// Nền cả app đã chọn lần cuối, để mở app không nháy nền trước khi
  /// `/auth/me` về. Nguồn sự thật là tài khoản; đây chỉ là bản chép.
  static const background = 'omni.background';
  static const lastInboxFilter = 'omni.inbox.last_filter';

  /// Tiền tố; khoá thật là `<tiền tố>.<id người dùng>.<id công ty>`. Ứng dụng
  /// mở lần cuối, để đăng nhập / mở app vào thẳng lại nó (27/11/2026). Không
  /// xoá khi đăng xuất: khoá đã gắn người dùng, người khác không thừa hưởng.
  static const lastApp = 'omni.apps.last_app';

  /// Tiền tố; khoá thật là `<tiền tố>.<id công việc>`. Hàng chờ tick việc con
  /// chưa được server xác nhận của MỘT công việc — xem `SubtaskOutbox`.
  static const subtaskOutbox = 'omni.tasks.subtask_outbox';

  /// Tiền tố; khoá thật là `<tiền tố>.<id hội thoại>`. Hàng chờ tin nhắn chưa
  /// được server xác nhận của MỘT hội thoại — xem `ThreadOutbox`.
  static const threadOutbox = 'omni.inbox.thread_outbox';
}
