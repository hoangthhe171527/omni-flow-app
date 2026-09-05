import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_envelope.dart';
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
