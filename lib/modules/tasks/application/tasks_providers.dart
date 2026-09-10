import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/realtime/realtime_client.dart';
import '../../../security/session/session_controller.dart';
import '../data/tasks_api.dart';
import '../domain/task.dart';
import '../domain/task_permissions.dart';

final taskAccessProvider = Provider<TaskAccess>((ref) {
  return TaskAccess.of(ref.watch(accessProvider));
});

/// Which bucket of "my work" is on screen.
final taskBucketProvider = StateProvider<TaskBucket>((ref) => TaskBucket.today);

/// Bumped when realtime says something about this user's work changed.
///
/// A signal, never data: acting on it means refetching through the API, which
/// re-applies the caller's permissions. A broadcast payload has not.
final taskRealtimeSignalProvider = StateProvider<int>((ref) => 0);

/// Kênh "có thực thể vừa đổi" của tenant đang đăng nhập; null khi chưa có tenant.
final _entityChannelProvider = Provider<String?>((ref) {
  final tenantId = ref.watch(sessionProvider).tenant?.id;

  return (tenantId == null || tenantId.isEmpty)
      ? null
      : 'tenant.$tenantId.entities';
});

/// Nối tín hiệu ở trên vào socket.
///
/// Thiếu mảnh này thì [taskRealtimeSignalProvider] được bốn provider theo dõi
/// mà KHÔNG CHỖ NÀO tăng: nó vĩnh viễn bằng 0 và không bao giờ kích hoạt một
/// lượt tải lại. Quản đốc chuyển công đoạn trên web, danh sách trong app đứng
/// yên — mà trên một danh sách việc, "đứng yên" đọc giống hệt "chưa có gì đổi",
/// nên hỏng mà không ai biết. Server đã phát sẵn (Task dùng
/// BroadcastsEntityChanges) và web đã nghe sẵn (Topbar → subscribeEntities);
/// chỉ app là chưa xin kênh.
///
/// Đây là TÍN HIỆU, không phải dữ liệu: payload broadcast chưa đi qua bộ lọc
/// quyền của người xem, nên phải hỏi lại API — nơi có bộ lọc đó. Lọc theo
/// `type` vì kênh này chở mọi loại thực thể của tenant; nhận tất cả thì một
/// khách hàng hay đơn hàng ai đó sửa cũng kéo theo một lượt tải lại danh sách
/// việc.
final tasksRealtimeSubscriptionProvider = Provider<void>((ref) {
  final channel = ref.watch(_entityChannelProvider);
  if (channel == null) return;

  final client = ref.watch(realtimeClientProvider);
  final unsubscribe = client.subscribePrivate(channel, (event) {
    if (event.event != 'entity.changed') return;
    if (event.data['type'] != 'task') return;

    final signal = ref.read(taskRealtimeSignalProvider.notifier);
    signal.state = signal.state + 1;
  });

  ref.onDispose(unsubscribe);
});

class TaskListState {
  const TaskListState({
    this.items = const [],
    this.pagination = const ApiPagination.empty(),
    this.loadingMore = false,
  });

  final List<Task> items;
  final ApiPagination pagination;
  final bool loadingMore;

  bool get hasMore => pagination.hasMore;
}

/// The signed-in worker's list, for the selected bucket.
class MyTasksController extends AutoDisposeAsyncNotifier<TaskListState> {
  @override
  Future<TaskListState> build() async {
    // Giữ đăng ký kênh sống cùng danh sách, không gửi lên màn hình: đặt ở màn
    // hình thì lần sau ai dựng lại danh sách ở chỗ khác sẽ quên, và cái quên đó
    // im lặng đúng như lần này.
    ref.watch(tasksRealtimeSubscriptionProvider);
    ref.watch(taskRealtimeSignalProvider);
    final bucket = ref.watch(taskBucketProvider);
    final page = await ref.watch(tasksApiProvider).mine(bucket: bucket);

    return TaskListState(items: page.items, pagination: page.pagination);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(build);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.loadingMore) return;

    state = AsyncData(
      TaskListState(
        items: current.items,
        pagination: current.pagination,
        loadingMore: true,
      ),
    );

    try {
      final next = await ref
          .read(tasksApiProvider)
          .mine(
            bucket: ref.read(taskBucketProvider),
            page: current.pagination.nextPage,
          );
      state = AsyncData(
        TaskListState(
          items: [...current.items, ...next.items],
          pagination: next.pagination,
        ),
      );
    } catch (_) {
      // Keep what is on screen; the next pull retries. Blanking a list because
      // page three failed is worse than showing pages one and two.
      state = AsyncData(
        TaskListState(items: current.items, pagination: current.pagination),
      );
    }
  }

  /// Applies a change made on the detail screen without a round trip, so
  /// coming back to the list does not show stale progress.
  void patch(Task updated) {
    final current = state.valueOrNull;
    if (current == null) return;

    state = AsyncData(
      TaskListState(
        items: [
          for (final task in current.items)
            if (task.id == updated.id) updated else task,
        ],
        pagination: current.pagination,
      ),
    );
  }
}

final myTasksProvider =
    AutoDisposeAsyncNotifierProvider<MyTasksController, TaskListState>(
      MyTasksController.new,
    );

/// Count for the tab badge: work that is late or due today.
///
/// Deliberately not "everything assigned to me" — a badge showing 40 is
/// wallpaper, one showing 3 is a prompt.
final taskBadgeProvider = Provider<int>((ref) {
  final tasks = ref.watch(myTasksProvider).valueOrNull;
  if (tasks == null) return 0;

  return tasks.items.where((task) => task.isOverdue || task.isDueToday).length;
});
