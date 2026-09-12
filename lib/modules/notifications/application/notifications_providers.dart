import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/realtime/realtime_client.dart';
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

/// Keeps the bell live for as long as something is watching it.
final notificationRealtimeProvider = Provider<void>((ref) {
  final channel = ref.watch(_userChannelProvider);
  if (channel == null) return;

  final client = ref.watch(realtimeClientProvider);
  final unsubscribe = client.subscribePrivate(channel, (event) {
    if (event.event != 'notification.created') return;
    final signal = ref.read(notificationSignalProvider.notifier);
    signal.state = signal.state + 1;
  });

  ref.onDispose(unsubscribe);
});

class NotificationListState {
  const NotificationListState({
    this.items = const [],
    this.pagination = const ApiPagination.empty(),
  });

  final List<AppNotification> items;
  final ApiPagination pagination;

  bool get hasMore => pagination.hasMore;

  int get unreadCount => items.where((item) => item.isUnread).length;
}

class NotificationsController
    extends AutoDisposeAsyncNotifier<NotificationListState> {
  @override
  Future<NotificationListState> build() async {
    ref.watch(notificationSignalProvider);
    final page = await ref.watch(notificationsApiProvider).list();

    return NotificationListState(
      items: page.items,
      pagination: page.pagination,
    );
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(build);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore) return;

    try {
      final next = await ref
          .read(notificationsApiProvider)
          .list(page: current.pagination.nextPage);
      state = AsyncData(
        NotificationListState(
          items: [...current.items, ...next.items],
          pagination: next.pagination,
        ),
      );
    } catch (_) {
      // Keep what is on screen. Blanking the list because page three failed is
      // worse than showing pages one and two.
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

    state = AsyncData(
      NotificationListState(
        items: [
          for (final item in current.items)
            if (item.id == id) item.markedRead() else item,
        ],
        pagination: current.pagination,
      ),
    );

    try {
      await ref.read(notificationsApiProvider).markRead(id);
      // Chuông đếm ở server; server vừa đổi, nên hỏi lại nó.
      ref.invalidate(unreadNotificationCountProvider);
    } catch (_) {
      state = AsyncData(current);
    }
  }

  Future<void> markAllRead() async {
    final current = state.valueOrNull;
    if (current == null || current.unreadCount == 0) return;

    state = AsyncData(
      NotificationListState(
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
