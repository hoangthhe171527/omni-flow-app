import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/modules/notifications/application/notifications_providers.dart';
import 'package:omni_app/modules/notifications/data/notifications_api.dart';
import 'package:omni_app/modules/notifications/domain/app_notification.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

AppNotification n(String id, {DateTime? at, bool read = false}) =>
    AppNotification(
      id: id,
      kind: NotificationKind.taskAssigned,
      title: 't$id',
      body: '',
      createdAt: at,
      readAt: read ? DateTime.utc(2026) : null,
    );

class _Api implements NotificationsApi {
  final calls = <bool>[];
  bool failMark = false;
  int counted = 0;
  final marked = <String>{};

  @override
  Future<Paged<AppNotification>> list({
    int page = 1,
    int perPage = 20,
    bool unreadOnly = false,
  }) async {
    calls.add(unreadOnly);
    return Paged(
      items: [n('1'), n('2')].where((e) => !marked.contains(e.id)).toList(),
      pagination: const ApiPagination.empty(),
    );
  }

  @override
  Future<int> unreadCount() async => ++counted;

  @override
  Future<void> markRead(String id) async {
    if (failMark) throw Exception('x');
    marked.add(id);
  }

  @override
  Future<void> markAllRead() async {}
}

void main() {
  late _Api api;
  late ProviderContainer c;

  setUp(() {
    api = _Api();
    c = ProviderContainer(
      overrides: [
        notificationsApiProvider.overrideWithValue(api),
        sessionProvider.overrideWithValue(const Session.unauthenticated()),
      ],
    );
    c.listen(notificationsProvider, (_, _) {});
  });
  tearDown(() => c.dispose());

  test('bật Chưa đọc thì gọi lại danh sách với unreadOnly', () async {
    await c.read(notificationsProvider.future);
    c.read(notificationUnreadOnlyProvider.notifier).state = true;
    await c.read(notificationsProvider.future);
    expect(api.calls, [false, true]);
  });

  test(
    'ở Chưa đọc, mở một dòng thì dòng rời danh sách; lỗi thì quay lại',
    () async {
      c.read(notificationUnreadOnlyProvider.notifier).state = true;
      await c.read(notificationsProvider.future);
      await c.read(notificationsProvider.notifier).markRead('1');
      expect(c.read(notificationsProvider).value!.items.map((e) => e.id), [
        '2',
      ]);

      api.failMark = true;
      await c.read(notificationsProvider.notifier).markRead('2');
      expect(c.read(notificationsProvider).value!.items.map((e) => e.id), [
        '2',
      ]);
    },
  );

  test('huy hiệu chuông lấy số đếm ở server', () async {
    c.listen(unreadNotificationBadgeProvider, (_, _) {});
    expect(c.read(unreadNotificationBadgeProvider), 0);
    await c.read(unreadNotificationCountProvider.future);
    expect(c.read(unreadNotificationBadgeProvider), 1);
  });

  test('nhóm Hôm nay / Trước đó theo ngày VN', () {
    // 17:30Z ngày 9 = 00:30 ngày 10 giờ VN → Hôm nay.
    final clock = DateTime.utc(2026, 10, 10, 3);
    final g = groupNotificationsByDay([
      n('a', at: DateTime.utc(2026, 10, 9, 17, 30)),
      n('b', at: DateTime.utc(2026, 10, 9, 16, 0)),
      n('c'),
    ], clock: clock);
    expect(g.map((e) => e.label), ['Hôm nay', 'Trước đó']);
    expect(g[0].items.map((e) => e.id), ['a']);
    expect(g[1].items.map((e) => e.id), ['b', 'c']);
  });

  test('không có dòng hôm nay thì không có nhóm Hôm nay', () {
    final g = groupNotificationsByDay([
      n('b', at: DateTime.utc(2026, 1, 1)),
    ], clock: DateTime.utc(2026, 10, 10));
    expect(g.map((e) => e.label), ['Trước đó']);
  });
}
