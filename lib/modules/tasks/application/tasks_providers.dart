import 'dart:async';

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

/// Kênh "có thực thể vừa đổi" của tenant đang đăng nhập; null khi chưa có tenant.
final _entityChannelProvider = Provider<String?>((ref) {
  final tenantId = ref.watch(sessionProvider).tenant?.id;

  return (tenantId == null || tenantId.isEmpty)
      ? null
      : 'tenant.$tenantId.entities';
});

/// Bumped when realtime says something about this user's work changed.
///
/// A signal, never data: acting on it means refetching through the API, which
/// re-applies the caller's permissions. A broadcast payload has not.
///
/// Provider này TỰ MỞ KÊNH.
///
/// Trước đây việc đó nằm ở một provider thứ hai (`tasksRealtimeSubscription`)
/// mà mọi người dùng tín hiệu phải nhớ theo dõi KÈM — và bốn trong năm chỗ đã
/// quên: bảng dự án, thẻ KPI, dòng việc, và tải việc của một người. Chỗ duy
/// nhất nhớ là `MyTasksController`, một provider autoDispose; nên realtime của
/// bốn màn kia sống chết theo việc màn "Việc của tôi" có tình cờ còn trong bộ
/// nhớ hay không. Kiểu hỏng tệ nhất: CÓ LÚC CHẠY.
///
/// Một mảnh thay vì hai: không còn cái để quên. `ref.watch(...)` tín hiệu này
/// tự nó là đủ.
final taskRealtimeSignalProvider = NotifierProvider<TaskRealtimeSignal, int>(
  TaskRealtimeSignal.new,
);

class TaskRealtimeSignal extends Notifier<int> {
  /// Gộp các sự kiện dồn dập. Tick xong ba việc con liên tiếp là ba lần
  /// `entity.changed` trong hai giây, và mỗi lần là một lượt quét nhật ký cả
  /// xưởng để vẽ ra cùng một màn hình.
  static const _coalesceWindow = Duration(milliseconds: 400);

  Timer? _coalesce;

  @override
  int build() {
    final channel = ref.watch(_entityChannelProvider);
    if (channel != null) {
      // Server đã phát sẵn (Task dùng BroadcastsEntityChanges) và web đã nghe
      // sẵn (Topbar → subscribeEntities); chỉ app là chưa xin kênh.
      final unsubscribe = ref
          .watch(realtimeClientProvider)
          .subscribePrivate(channel, _onEvent);
      ref.onDispose(unsubscribe);
    }

    ref.onDispose(() => _coalesce?.cancel());

    return 0;
  }

  void _onEvent(RealtimeEvent event) {
    if (event.event != 'entity.changed') return;
    // Kênh này chở MỌI loại thực thể của tenant. Nhận tất cả thì một khách
    // hàng hay đơn hàng ai đó sửa cũng kéo theo một lượt tải lại danh sách việc.
    if (event.data['type'] != 'task') return;

    _coalesce?.cancel();
    _coalesce = Timer(_coalesceWindow, () => state = state + 1);
  }

  /// Buộc một lượt tải lại.
  ///
  /// Dùng khi app quay lại từ nền: socket có thể đã chết lặng trong lúc đó
  /// (proxy hết hạn chờ, nhà mạng cắt kết nối dài), và màn hình lúc ấy hiện dữ
  /// liệu cũ mà trông y hệt dữ liệu mới.
  void bump() {
    _coalesce?.cancel();
    state = state + 1;
  }
}

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
    // Theo dõi tín hiệu là ĐỦ — nó tự mở kênh. Trước đây ở đây có thêm một
    // dòng `ref.watch(tasksRealtimeSubscriptionProvider)`, và chính việc phải
    // nhớ hai dòng thay vì một là thứ bốn màn khác đã quên.
    ref.watch(taskRealtimeSignalProvider);
    final bucket = ref.watch(taskBucketProvider);
    final page = await ref.watch(tasksApiProvider).mine(bucket: bucket);

    return TaskListState(items: page.items, pagination: page.pagination);
  }

  Future<void> refresh() async {
    // Kéo để tải lại là "cho tôi con số mới": badge trên tab đi cùng.
    ref.invalidate(taskOverdueCountProvider);
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

/// Tải việc của MỘT người: đang gánh bao nhiêu, trễ bao nhiêu.
///
/// [total] và [overdue] đều do SERVER đếm, không đếm trên [tasks]: danh sách
/// có phân trang, nên một con số đếm từ trang một là con số của trang một —
/// và trên màn hình nó trông y hệt một con số của tất cả.
typedef Workload = ({List<Task> tasks, int total, int overdue});

/// Việc đang gánh của một người, cho màn hình quản đốc.
///
/// autoDispose: quản đốc mở tải việc của một người rồi đóng lại, không quay
/// lại người đó. Giữ trong bộ nhớ cả phiên là giữ đúng thứ chắc chắn đã cũ.
final workloadProvider = FutureProvider.autoDispose.family<Workload, String>((
  ref,
  userId,
) async {
  ref.watch(taskRealtimeSignalProvider);
  final api = ref.watch(tasksApiProvider);

  // Song song: hai lượt gọi độc lập, và cái đếm nhanh không việc gì phải
  // chờ cái danh sách.
  final (page, overdue) = await (
    // Một trang lớn thay vì cuộn vô tận: một người gánh 60 cây là đã bất
    // thường, và màn này để LIẾC chứ không để đọc hết.
    api.byAssignee(userId, perPage: 100),
    api.overdueCount(userId),
  ).wait;

  return (tasks: page.items, total: page.pagination.total, overdue: overdue);
});

/// Chuỗi đang gõ ở ô tìm kiếm, sau khi đã chờ người dùng ngừng gõ.
final taskSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

/// Kết quả tìm một cây đàn theo tên hoặc số máy.
///
/// Chuỗi rỗng KHÔNG gọi mạng: `search=` trống ở API nghĩa là "không lọc", tức
/// là trả về toàn bộ công việc của xưởng — một danh sách 500 dòng hiện ra
/// trước khi người dùng kịp gõ chữ đầu tiên.
final taskSearchProvider = FutureProvider.autoDispose<List<Task>>((ref) async {
  final query = ref.watch(taskSearchQueryProvider).trim();
  if (query.isEmpty) return const [];

  final page = await ref.watch(tasksApiProvider).search(query);

  return page.items;
});

/// Số việc TRỄ của người đang đăng nhập, server đếm.
///
/// Không đọc [myTasksProvider]: badge từng là số việc trễ trên TRANG ĐẦU của
/// RỔ ĐANG XEM — đứng ở "Sắp tới" thì badge là 0 dù có ba việc trễ. Và vì
/// thanh tab theo dõi badge suốt phiên, `myTasksProvider` khai autoDispose mà
/// không bao giờ được dọn: mỗi tín hiệu realtime là một lượt tải lại danh
/// sách cho một tab có thể đang không mở.
///
/// null user (chưa đăng nhập) → 0, không gọi mạng.
final taskOverdueCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final userId = ref.watch(sessionProvider.select((s) => s.user?.id));
  if (userId == null || userId.isEmpty) return 0;

  ref.watch(taskRealtimeSignalProvider);

  return ref.watch(tasksApiProvider).overdueCount(userId);
});

/// Count for the tab badge: work that is late.
///
/// Deliberately not "everything assigned to me" — a badge showing 40 is
/// wallpaper, one showing 3 is a prompt. Giữ con số cũ trong lúc đếm lại, để
/// badge không nháy về 0 mỗi lần realtime bơm tín hiệu.
final taskBadgeProvider = Provider.autoDispose<int>((ref) {
  return ref.watch(taskOverdueCountProvider).valueOrNull ?? 0;
});
