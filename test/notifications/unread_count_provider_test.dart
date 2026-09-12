import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/modules/notifications/application/notifications_providers.dart';
import 'package:omni_app/modules/notifications/data/notifications_api.dart';
import 'package:omni_app/modules/notifications/domain/app_notification.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

/// Số trên chuông đếm ở SERVER, không đếm trên trang đầu của danh sách.
///
/// Trước đây `unreadNotificationCountProvider` đọc `notificationsProvider` —
/// tức là để vẽ một con số trên chuông của màn "Việc của tôi", app phải nạp
/// cả trang thông báo đầu tiên (20 dòng, mỗi dòng một bản ghi đầy đủ), và giữ
/// nó trong bộ nhớ suốt phiên vì chuông luôn hiện. Và con số ấy SAI: 20 dòng
/// đầu đều đã đọc mà dòng 21 chưa đọc thì chuông im lặng.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _CountingApi api;
  late ProviderContainer container;

  setUp(() {
    api = _CountingApi();
    container = ProviderContainer(
      overrides: [
        notificationsApiProvider.overrideWithValue(api),
        sessionProvider.overrideWithValue(const Session.unauthenticated()),
      ],
    );
  });

  tearDown(() => container.dispose());

  Future<int> openBell() {
    // AutoDispose: không có người nghe thì provider bị dọn giữa hai lần đọc.
    container.listen(unreadNotificationCountProvider, (_, _) {});

    return container.read(unreadNotificationCountProvider.future);
  }

  test('lấy từ endpoint đếm, không nạp danh sách', () async {
    api.unread = 7;

    expect(await openBell(), 7);
    expect(api.countCalls, 1);
    expect(
      api.listCalls,
      0,
      reason:
          'Chuông chỉ cần MỘT con số. Nạp cả trang thông báo để đếm là trả '
          '20 bản ghi cho một chữ số — và giữ chúng cả phiên vì chuông luôn '
          'hiện.',
    );
  });

  test('tín hiệu realtime thì hỏi lại con số', () async {
    api.unread = 1;
    await openBell();

    api.unread = 2;
    final signal = container.read(notificationSignalProvider.notifier);
    signal.state = signal.state + 1;

    expect(await container.read(unreadNotificationCountProvider.future), 2);
    expect(api.countCalls, 2);
    expect(api.listCalls, 0);
  });

  test('đánh dấu đã đọc hết thì con số hỏi lại server', () async {
    api.unread = 3;
    api.rows = [_row('n1'), _row('n2'), _row('n3')];
    await openBell();
    container.listen(notificationsProvider, (_, _) {});
    await container.read(notificationsProvider.future);

    await container.read(notificationsProvider.notifier).markAllRead();

    expect(
      await container.read(unreadNotificationCountProvider.future),
      0,
      reason:
          'Nút "đã đọc hết" bấm xong mà chuông vẫn 3 thì người ta bấm lại — '
          'và lần hai không có gì để bấm.',
    );
  });
}

AppNotification _row(String id) => AppNotification.fromJson({
  'id': id,
  'notification_type': 'TASK_ASSIGNED',
  'title': id,
  'content': 'x',
});

/// Máy chủ giả: đếm số lần hỏi con số và số lần hỏi danh sách.
class _CountingApi implements NotificationsApi {
  int unread = 0;
  List<AppNotification> rows = const [];
  int countCalls = 0;
  int listCalls = 0;

  @override
  Future<int> unreadCount() async {
    countCalls++;

    return unread;
  }

  @override
  Future<Paged<AppNotification>> list({
    int page = 1,
    int perPage = 20,
    bool unreadOnly = false,
  }) async {
    listCalls++;

    return Paged(items: rows, pagination: const ApiPagination.empty());
  }

  @override
  Future<void> markAllRead() async {
    // Server đã đánh dấu: lần đếm sau phải ra 0.
    unread = 0;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
