import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/modules/notifications/application/notifications_providers.dart';
import 'package:omni_app/modules/notifications/data/notifications_api.dart';
import 'package:omni_app/modules/notifications/domain/app_notification.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

/// Giả lập đúng cách server phân trang tập CHƯA ĐỌC: đánh dấu đọc làm tập co
/// lại, nên các trang sau dồn lên.
class _ServerApi implements NotificationsApi {
  _ServerApi(int count) : unread = [for (var i = 1; i <= count; i++) 'u$i'];

  final List<String> unread;
  int markAll = 0;

  @override
  Future<Paged<AppNotification>> list({
    int page = 1,
    int perPage = 20,
    bool unreadOnly = false,
  }) async {
    final from = (page - 1) * perPage;
    final slice = unread.skip(from).take(perPage).toList();
    return Paged(
      items: [
        for (final id in slice)
          AppNotification(
            id: id,
            kind: NotificationKind.taskAssigned,
            title: id,
            body: '',
            createdAt: null,
          ),
      ],
      pagination: ApiPagination(
        currentPage: page,
        perPage: perPage,
        total: unread.length,
        lastPage: (unread.length / perPage).ceil(),
      ),
    );
  }

  @override
  Future<void> markRead(String id) async => unread.remove(id);

  @override
  Future<void> markAllRead() async {
    markAll++;
    unread.clear();
  }

  @override
  Future<int> unreadCount() async => unread.length;
}

void main() {
  late _ServerApi api;
  late ProviderContainer c;

  ProviderContainer build() => ProviderContainer(
    overrides: [
      notificationsApiProvider.overrideWithValue(api),
      sessionProvider.overrideWithValue(const Session.unauthenticated()),
    ],
  );

  List<String> ids() => c
      .read(notificationsProvider)
      .requireValue
      .items
      .map((e) => e.id)
      .toList();

  tearDown(() => c.dispose());

  test(
    'Chưa đọc: mở 5 dòng ở trang một rồi tải thêm thì không sót dòng nào',
    () async {
      api = _ServerApi(40);
      c = build();
      c.listen(notificationsProvider, (_, _) {});
      c.read(notificationUnreadOnlyProvider.notifier).state = true;
      await c.read(notificationsProvider.future);
      expect(ids(), hasLength(20));

      for (final id in ['u1', 'u2', 'u3', 'u4', 'u5']) {
        await c.read(notificationsProvider.notifier).markRead(id);
      }
      await c.read(notificationsProvider.notifier).loadMore();

      expect(ids(), [for (var i = 6; i <= 40; i++) 'u$i']);
    },
  );

  test('Chưa đọc: đọc hết thì danh sách rỗng và hết trang', () async {
    api = _ServerApi(40);
    c = build();
    c.listen(notificationsProvider, (_, _) {});
    c.read(notificationUnreadOnlyProvider.notifier).state = true;
    await c.read(notificationsProvider.future);
    expect(c.read(notificationsProvider).requireValue.hasMore, isTrue);

    await c.read(notificationsProvider.notifier).markAllRead();

    final state = c.read(notificationsProvider).requireValue;
    expect(state.items, isEmpty);
    expect(state.hasMore, isFalse);
    expect(api.markAll, 1);
  });

  test('rời màn rồi mở lại thì bộ lọc về Tất cả', () async {
    api = _ServerApi(3);
    c = build();
    final sub = c.listen(notificationsProvider, (_, _) {});
    c.read(notificationUnreadOnlyProvider.notifier).state = true;
    await c.read(notificationsProvider.future);
    expect(c.read(notificationUnreadOnlyProvider), isTrue);

    sub.close();
    await Future<void>.delayed(Duration.zero);

    c.listen(notificationsProvider, (_, _) {});
    expect(c.read(notificationUnreadOnlyProvider), isFalse);
  });
}
