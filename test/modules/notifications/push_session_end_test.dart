import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/modules/notifications/application/push_notifications.dart';
import 'package:omni_app/modules/notifications/data/push_api.dart';
import 'package:omni_app/security/session/session.dart';

/// Lỗi bảo mật (audit run-1, `fcm-token-survives-session-end`).
///
/// Phiên kết thúc mà không gỡ được token bằng `DELETE /devices/push-tokens`
/// (refresh bị từ chối → 401; phiên hết hạn ngay lúc mở app nên push chưa
/// từng chạy; đăng xuất lúc mất mạng) thì FCM token của máy vẫn gắn người cũ
/// ở máy chủ — người cầm máy sau thấy tên khách và trích tin của người cũ trên
/// màn khoá. Endpoint gỡ duy nhất của API cần đăng nhập, nên phía app phải tự
/// huỷ token ở Firebase (`deleteToken`) và gỡ thông báo đang hiện.
void main() {
  late _FakeReset reset;
  late _FakePushApi api;
  late ProviderContainer container;

  setUp(() {
    reset = _FakeReset();
    api = _FakePushApi();
    container = ProviderContainer(
      overrides: [
        pushDeviceResetProvider.overrideWithValue(reset),
        pushApiProvider.overrideWithValue(api),
      ],
    );
  });

  tearDown(() => container.dispose());

  const authenticated = Session(status: SessionStatus.authenticated);
  const tenantPending = Session(status: SessionStatus.tenantPending);

  test(
    'phiên hết hạn (refresh bị từ chối) → huỷ FCM token, gỡ thông báo',
    () async {
      final push = container.read(pushNotificationsProvider);

      await push.onSessionChanged(authenticated, const Session.expired());

      expect(reset.deletedTokens, 1);
      expect(reset.clearedNotifications, 1);
    },
  );

  test('hết hạn ngay lúc mở app (push chưa chạy) → vẫn huỷ token', () async {
    final push = container.read(pushNotificationsProvider);

    await push.onSessionChanged(
      const Session.restoring(),
      const Session.expired(),
    );

    expect(reset.deletedTokens, 1);
  });

  test('đăng xuất (gỡ ở máy chủ thất bại) → huỷ token, gỡ thông báo', () async {
    final push = container.read(pushNotificationsProvider);

    await push.onSessionChanged(authenticated, const Session.unauthenticated());

    expect(reset.deletedTokens, 1);
    expect(reset.clearedNotifications, 1);
  });

  test('đổi không gian làm việc KHÔNG huỷ token (vẫn là người đó)', () async {
    final push = container.read(pushNotificationsProvider);

    await push.onSessionChanged(authenticated, tenantPending);

    expect(reset.deletedTokens, 0);
    expect(reset.clearedNotifications, 0);
  });

  test('mở app chưa đăng nhập → không đụng tới token', () async {
    final push = container.read(pushNotificationsProvider);

    await push.onSessionChanged(
      const Session.restoring(),
      const Session.unauthenticated(),
    );

    expect(reset.deletedTokens, 0);
  });

  test(
    'Firebase lỗi khi huỷ token không làm hỏng việc kết thúc phiên',
    () async {
      reset.failDelete = true;
      final push = container.read(pushNotificationsProvider);

      await push.onSessionChanged(authenticated, const Session.expired());

      expect(reset.clearedNotifications, 1);
    },
  );
}

class _FakeReset implements PushDeviceReset {
  int deletedTokens = 0;
  int clearedNotifications = 0;
  bool failDelete = false;

  @override
  Future<void> deleteFcmToken() async {
    deletedTokens++;
    if (failDelete) throw StateError('firebase down');
  }

  @override
  Future<void> clearShownNotifications() async => clearedNotifications++;
}

class _FakePushApi implements PushApi {
  final unregistered = <String>[];

  @override
  Future<void> unregister(String token) async {
    unregistered.add(token);
    throw const UnauthorizedException('Phiên đã hết hạn.');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
