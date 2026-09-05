import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/modules/notifications/application/notifications_providers.dart';
import 'package:omni_app/modules/notifications/data/notifications_api.dart';
import 'package:omni_app/modules/notifications/domain/app_notification.dart';

/// The bell's two jobs: stay current, and clear its own dot.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeNotificationsApi api;
  late ProviderContainer container;

  setUp(() {
    api = _FakeNotificationsApi();
    container = ProviderContainer(
      overrides: [notificationsApiProvider.overrideWithValue(api)],
    );
  });

  tearDown(() => container.dispose());

  Future<void> open() {
    // AutoDispose: without a listener the provider is torn down between reads.
    container.listen(notificationsProvider, (_, _) {});
    return container.read(notificationsProvider.future);
  }

  NotificationListState read() =>
      container.read(notificationsProvider).requireValue;

  group('staying current', () {
    test('a realtime signal reloads the list', () async {
      api.rows = [_row('n1', 'Bạn có việc mới')];
      await open();
      expect(read().items.single.title, 'Bạn có việc mới');

      // The socket says something arrived. The payload is not trusted — the
      // list refetches through the API, which applies the caller's scope.
      api.rows = [
        _row('n2', 'Công việc đã hoàn thành'),
        _row('n1', 'Bạn có việc mới'),
      ];
      final signal = container.read(notificationSignalProvider.notifier);
      signal.state = signal.state + 1;
      await container.read(notificationsProvider.future);

      expect(read().items.first.title, 'Công việc đã hoàn thành');
      expect(read().items, hasLength(2));
    });

    test('the unread count is what the badge shows', () async {
      api.rows = [
        _row('n1', 'a'),
        _row('n2', 'b', readAt: '2026-09-05T08:00:00Z'),
        _row('n3', 'c'),
      ];
      await open();

      expect(read().unreadCount, 2);
      expect(container.read(unreadNotificationCountProvider), 2);
    });
  });

  group('marking read', () {
    test('the dot clears before the server answers', () async {
      // The row is being tapped to open a task, so the screen is about to
      // change. Waiting on a round trip would make the tap feel ignored.
      api.rows = [_row('n1', 'a')];
      await open();

      final pending = container
          .read(notificationsProvider.notifier)
          .markRead('n1');

      expect(read().items.single.isUnread, isFalse);
      await pending;
      expect(api.markedRead, ['n1']);
    });

    test('a failure puts the dot back', () async {
      // Otherwise a notification the server still considers unread looks
      // handled, and it comes back on the next refresh with no explanation.
      api.rows = [_row('n1', 'a')];
      await open();

      api.failWrites = true;
      await container.read(notificationsProvider.notifier).markRead('n1');

      expect(read().items.single.isUnread, isTrue);
    });

    test('an already-read row is not sent again', () async {
      api.rows = [_row('n1', 'a', readAt: '2026-09-05T08:00:00Z')];
      await open();

      await container.read(notificationsProvider.notifier).markRead('n1');

      expect(api.markedRead, isEmpty);
    });

    test('read-all clears every dot at once', () async {
      api.rows = [_row('n1', 'a'), _row('n2', 'b')];
      await open();

      await container.read(notificationsProvider.notifier).markAllRead();

      expect(read().unreadCount, 0);
      expect(api.markedAll, 1);
    });

    test('read-all with nothing unread does not call the server', () async {
      api.rows = [_row('n1', 'a', readAt: '2026-09-05T08:00:00Z')];
      await open();

      await container.read(notificationsProvider.notifier).markAllRead();

      expect(api.markedAll, 0);
    });
  });

  group('paging', () {
    test('a failed next page keeps the pages already on screen', () async {
      api.rows = [_row('n1', 'a')];
      api.hasMore = true;
      await open();

      api.failReads = true;
      await container.read(notificationsProvider.notifier).loadMore();

      expect(read().items, hasLength(1));
    });
  });
}

AppNotification _row(String id, String title, {String? readAt}) =>
    AppNotification.fromJson({
      'id': id,
      'notification_type': 'TASK_ASSIGNED',
      'title': title,
      'content': 'x',
      'related_entity_type': 'task',
      'related_entity_id': 't-1',
      'read_at': readAt,
    });

class _FakeNotificationsApi implements NotificationsApi {
  List<AppNotification> rows = [];
  bool hasMore = false;
  bool failReads = false;
  bool failWrites = false;
  final List<String> markedRead = [];
  int markedAll = 0;

  @override
  Future<Paged<AppNotification>> list({
    int page = 1,
    int perPage = 20,
    bool unreadOnly = false,
  }) async {
    if (failReads) throw Exception('offline');

    return Paged(
      items: rows,
      pagination: ApiPagination(
        currentPage: page,
        perPage: perPage,
        total: hasMore ? rows.length + 1 : rows.length,
        lastPage: hasMore ? page + 1 : page,
      ),
    );
  }

  @override
  Future<void> markRead(String id) async {
    if (failWrites) throw Exception('offline');
    markedRead.add(id);
  }

  @override
  Future<void> markAllRead() async {
    if (failWrites) throw Exception('offline');
    markedAll++;
  }
}
