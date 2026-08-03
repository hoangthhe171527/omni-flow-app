abstract final class StorageKeys {
  // Secure storage (Keychain / EncryptedSharedPreferences).
  static const accessToken = 'omni.access_token';
  static const refreshToken = 'omni.refresh_token';

  // Preferences (non-sensitive).
  static const tenantId = 'omni.tenant_id';
  static const tenantName = 'omni.tenant_name';
  static const locale = 'omni.locale';
  static const themeMode = 'omni.theme_mode';
  static const lastInboxFilter = 'omni.inbox.last_filter';
}
