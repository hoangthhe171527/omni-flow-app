import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/realtime/realtime_client.dart';
import '../../../core/utils/formatters.dart';
import '../../../security/session/session_controller.dart';
import '../data/notifications_api.dart';
import '../domain/app_notification.dart';

/// Bumped when the server says this user has a new notification.
///
/// A signal, never the payload: what arrives over the socket has not been
/// through the caller's permission scope, so acting on it means refetching
/// through the API, which has. Same rule as the inbox.
final notificationSignalProvider = StateProvider<int>((ref) => 0);

/// The signed-in user's own stream, or null before there is a session.
final _userChannelProvider = Provider<String?>((ref) {
  final userId = ref.watch(sessionProvider).user?.id;

  return (userId == null || userId.isEmpty) ? null : 'user.$userId';
});

/// Chuông chỉ báo các thông báo không liên quan đến tin nhắn; tin nhắn hộp thư
/// đã có kênh push và tín hiệu inbox riêng.
bool isInboxMessageRealtimePayload(Map<String, dynamic> data) {
  final type = (data['notification_type'] ?? data['type'])
      ?.toString()
      .toUpperCase();
  if (type == 'INBOX_MESSAGE' || type == 'MESSAGE') return true;
  if (data['related_entity_type']?.toString().toLowerCase() == 'conversation') {
    return true;
  }
  final hasConv = (data['conversation_id']?.toString().trim() ?? '').isNotEmpty;
  final hasTask = (data['task_id']?.toString().trim() ?? '').isNotEmpty;
  return hasConv && !hasTask;
}

/// Keeps the bell live for as long as something is watching it.
final notificationRealtimeProvider = Provider<void>((ref) {
  final channel = ref.watch(_userChannelProvider);
  if (channel == null) return;

  final client = ref.watch(realtimeClientProvider);
  final unsubscribe = client.subscribePrivate(channel, (event) {
    if (event.event != 'notification.created') return;
    if (isInboxMessageRealtimePayload(event.data)) return;
    final signal = ref.read(notificationSignalProvider.notifier);
    signal.state = signal.state + 1;
  });

  ref.onDispose(unsubscribe);
});

/// Thanh chọn "Tất cả / Chưa đọc". Lọc ở SERVER (`?unread=1`): lọc trên trang
/// đầu sẽ bỏ sót dòng chưa đọc nằm ở trang hai.
///
/// autoDispose: [notificationsProvider] theo dõi nó, nên rời màn thì cả hai
/// cùng huỷ và lần mở sau luôn bắt đầu ở "Tất cả".
final notificationUnreadOnlyProvider = StateProvider.autoDispose<bool>(
  (ref) => false,
);

class NotificationListState {
  const NotificationListState({
    this.items = const [],
    this.pagination = const ApiPagination.empty(),
    this.loadingMore = false,
  });

  final List<AppNotification> items;
  final ApiPagination pagination;
  final bool loadingMore;

  bool get hasMore => pagination.hasMore;

  int get unreadCount => items.where((item) => item.isUnread).length;
}

class NotificationsController
    extends AutoDisposeAsyncNotifier<NotificationListState> {
  int _generation = 0;
  bool _loadingMore = false;

  @override
  Future<NotificationListState> build() async {
    final gen = ++_generation;
    _loadingMore = false;
    ref.watch(notificationSignalProvider);
    final unreadOnly = ref.watch(notificationUnreadOnlyProvider);
    final page = await ref
        .watch(notificationsApiProvider)
        .list(unreadOnly: unreadOnly);
    if (gen != _generation) {
      return state.valueOrNull ?? const NotificationListState();
    }

    return NotificationListState(
      items: page.items.where((item) => item.isBellNotification).toList(),
      pagination: page.pagination,
    );
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(build);
  }

  Future<void> loadMore() async {
    if (_loadingMore) return;
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.loadingMore) return;

    _loadingMore = true;
    final gen = _generation;
    state = AsyncData(
      NotificationListState(
        items: current.items,
        pagination: current.pagination,
        loadingMore: true,
      ),
    );

    try {
      final next = await ref
          .read(notificationsApiProvider)
          .list(
            page: current.pagination.nextPage,
            unreadOnly: ref.read(notificationUnreadOnlyProvider),
          );
      if (gen != _generation) return;
      final seen = {for (final item in current.items) item.id};
      final merged = [
        ...current.items,
        for (final item in next.items)
          if (item.isBellNotification && seen.add(item.id)) item,
      ];
      state = AsyncData(
        NotificationListState(
          items: merged,
          pagination: next.pagination,
        ),
      );
    } catch (_) {
      if (gen == _generation) {
        state = AsyncData(
          NotificationListState(
            items: current.items,
            pagination: current.pagination,
          ),
        );
      }
    } finally {
      _loadingMore = false;
    }
  }

  /// Marks one row read, on screen first.
  ///
  /// The row is being tapped to open something, so the screen is about to
  /// change; waiting for the server before the dot clears would make the tap
  /// feel unacknowledged. A failure leaves the dot — the row is still there to
  /// tap again.
  Future<void> markRead(String id) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final target = current.items.where((item) => item.id == id).firstOrNull;
    if (target == null || !target.isUnread) return;

    final unreadOnly = ref.read(notificationUnreadOnlyProvider);
    state = AsyncData(
      NotificationListState(
        items: [
          for (final item in current.items)
            if (item.id != id) item else if (!unreadOnly) item.markedRead(),
        ],
        pagination: current.pagination,
      ),
    );

    try {
      await ref.read(notificationsApiProvider).markRead(id);
      // Chuông đếm ở server; server vừa đổi, nên hỏi lại nó.
      ref.invalidate(unreadNotificationCountProvider);
      if (unreadOnly) {
        // Tập chưa đọc ở server vừa co lại: các trang sau dồn lên, nên
        // `nextPage` cũ sẽ nhảy qua dòng. Nạp lại từ trang một; nạp hỏng thì
        // giữ danh sách đã bỏ dòng.
        final fresh = await AsyncValue.guard(build);
        if (fresh.hasValue) state = fresh;
      }
    } catch (_) {
      state = AsyncData(current);
    }
  }

  Future<void> markAllRead() async {
    final current = state.valueOrNull;
    if (current == null || current.unreadCount == 0) return;

    // Ở Chưa đọc, "đọc hết" làm tập rỗng: bỏ cả các trang chưa nạp.
    state = AsyncData(
      ref.read(notificationUnreadOnlyProvider)
          ? const NotificationListState()
          : NotificationListState(
              items: [for (final item in current.items) item.markedRead()],
              pagination: current.pagination,
            ),
    );

    try {
      await ref.read(notificationsApiProvider).markAllRead();
      ref.invalidate(unreadNotificationCountProvider);
    } catch (_) {
      state = AsyncData(current);
    }
  }
}

final notificationsProvider =
    AutoDisposeAsyncNotifierProvider<
      NotificationsController,
      NotificationListState
    >(NotificationsController.new);

/// Đánh dấu toàn bộ đã đọc ngay cả khi màn danh sách chưa từng được mở.
/// [NotificationsController.markAllRead] cần một trang đã nạp để cập nhật lạc
/// quan; menu chuông ở header thì có thể là lối vào đầu tiên của phiên.
final markAllNotificationsReadProvider = Provider<Future<void> Function()>((
  ref,
) {
  return () async {
    try {
      await ref.read(notificationsApiProvider).markAllRead();
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationCountProvider);
    } catch (_) {
      // Menu đã đóng nhưng chấm chưa đọc vẫn còn, nên người dùng thấy ngay là
      // thao tác chưa thành công và có thể thử lại; không làm sập màn hiện tại.
    }
  };
});

/// Số trên chuông, đếm ở SERVER.
///
/// Không đọc [notificationsProvider]: chuông hiện trên màn "Việc của tôi" cả
/// phiên, nên đếm qua danh sách là nạp và giữ 20 bản ghi đầy đủ để vẽ một chữ
/// số — và con số ấy sai ngay khi dòng chưa đọc nằm ở trang hai. Một lượt gọi
/// đếm thì rẻ, đúng, và tự dọn khi không còn chuông nào nhìn nó.
///
/// Theo dõi [notificationRealtimeProvider] để chuông SỐNG: kênh riêng của
/// người dùng mở ra ngay khi chuông hiện, không đợi tới lúc mở màn thông báo.
final unreadNotificationCountProvider = FutureProvider.autoDispose<int>((ref) {
  ref.watch(notificationRealtimeProvider);
  ref.watch(notificationSignalProvider);

  return ref.watch(notificationsApiProvider).unreadCount();
});

final unreadNotificationBadgeProvider = Provider.autoDispose<int>(
  (ref) => ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0,
);

typedef NotificationGroup = ({String label, List<AppNotification> items});

/// "Hôm nay" theo ngày VN, còn lại "Trước đó" — như `Notifications.dc.html`.
List<NotificationGroup> groupNotificationsByDay(
  List<AppNotification> items, {
  DateTime? clock,
}) {
  final today = VnTime.today(clock);
  final now = <AppNotification>[];
  final earlier = <AppNotification>[];
  for (final item in items) {
    final at = item.createdAt;
    (at != null && VnTime.day(at) == today ? now : earlier).add(item);
  }
  return [
    if (now.isNotEmpty) (label: 'Hôm nay', items: now),
    if (earlier.isNotEmpty) (label: 'Trước đó', items: earlier),
  ];
}
