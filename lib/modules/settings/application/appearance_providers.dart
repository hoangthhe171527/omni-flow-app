import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/preferences_store.dart';
import '../../../core/storage/storage_keys.dart';
import '../../../security/session/session.dart';
import '../../../security/session/session_controller.dart';
import '../data/appearance_api.dart';

/// Tên nền cả app đang dùng (null = mặc định).
///
/// Nguồn sự thật là TÀI KHOẢN (`/auth/me`), để đổi máy hay mở web vẫn cùng
/// nền. Cache trên máy chỉ để lúc mở app, trước khi `/auth/me` về, nền không
/// nháy từ phẳng sang có vân. Đổi nền: hiện ngay (lạc quan) → gọi API → ghi
/// cache → làm mới phiên; lỗi thì hoàn về và ném lại cho màn hình báo.
final backgroundProvider = NotifierProvider<BackgroundController, String?>(
  BackgroundController.new,
);

class BackgroundController extends Notifier<String?> {
  @override
  String? build() {
    final session = ref.watch(sessionProvider);
    final store = ref.read(preferencesStoreProvider);

    if (session.status != SessionStatus.authenticated) {
      return store.getString(StorageKeys.background);
    }

    final fromAccount = session.user?.background;
    // Đồng bộ cache theo tài khoản — ngoài khung dựng, để không ghi đĩa
    // trong build.
    if (store.getString(StorageKeys.background) != fromAccount) {
      Future<void>.microtask(
        () => store.setString(StorageKeys.background, fromAccount),
      );
    }

    return fromAccount;
  }

  Future<void> set(String? name) async {
    final before = state;
    state = name;
    try {
      await ref.read(appearanceApiProvider).setBackground(name);
      await ref
          .read(preferencesStoreProvider)
          .setString(StorageKeys.background, name);
      await ref.read(sessionControllerProvider.notifier).refreshContext();
    } catch (_) {
      state = before;
      rethrow;
    }
  }
}
