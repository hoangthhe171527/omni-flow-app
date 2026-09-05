import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/error/crash_reporting.dart';
import '../../../core/utils/client_id.dart';
import '../data/tasks_api.dart';
import '../domain/task.dart';

/// A tick that has not been confirmed by the server yet.
///
/// Kept as its own record rather than a flag on the subtask because the reason
/// a tick failed has to survive alongside it — a worker needs to see that it
/// did not go through, not just that the box is unchecked again.
class PendingTick {
  const PendingTick({
    required this.subtaskId,
    required this.done,
    required this.clientRequestId,
    this.error,
  });

  final String subtaskId;
  final bool done;

  /// Reused on every retry of the same tick, so a repeat cannot be counted as
  /// a second completion.
  final String clientRequestId;

  final String? error;

  bool get failed => error != null;

  PendingTick copyWith({String? error}) => PendingTick(
    subtaskId: subtaskId,
    done: done,
    clientRequestId: clientRequestId,
    error: error,
  );
}

class TaskDetailState {
  const TaskDetailState({required this.task, this.pending = const []});

  final Task task;

  /// Ticks this device has made that the server has not confirmed.
  ///
  /// Deliberately separate from [task]: a refresh replaces the server's copy,
  /// and anything living inside it would be wiped. A failed tick vanishing
  /// while the worker believes the stage is done is the worst thing this screen
  /// can do — it is how a piano gets skipped.
  final List<PendingTick> pending;

  PendingTick? pendingFor(String subtaskId) {
    for (final tick in pending) {
      if (tick.subtaskId == subtaskId) return tick;
    }

    return null;
  }

  /// What the screen renders: the server's task with local ticks applied on top.
  ///
  /// A failed tick keeps showing the state the worker chose, not the server's,
  /// so the row reads "this is what you did, and it did not save" rather than
  /// quietly reverting under their hand.
  Task get visible {
    if (pending.isEmpty) return task;

    return task.copyWith(
      subtasks: [
        for (final subtask in task.subtasks)
          switch (pendingFor(subtask.id)) {
            final tick? => subtask.copyWith(done: tick.done),
            null => subtask,
          },
      ],
    );
  }

  TaskDetailState copyWith({Task? task, List<PendingTick>? pending}) =>
      TaskDetailState(
        task: task ?? this.task,
        pending: pending ?? this.pending,
      );
}

/// One task's detail, plus the outbox of ticks waiting on the network.
///
/// The workshop has poor wifi and a worker ticks a stage with dirty hands and
/// walks away. Waiting on a round trip before the box moves would make the app
/// feel broken; losing the tick silently would be worse.
class TaskController
    extends AutoDisposeFamilyAsyncNotifier<TaskDetailState, String> {
  bool _disposed = false;

  @override
  Future<TaskDetailState> build(String taskId) async {
    _disposed = false;
    ref.onDispose(() => _disposed = true);

    return TaskDetailState(task: await ref.watch(tasksApiProvider).get(taskId));
  }

  /// Pulls the server's copy without touching the outbox.
  ///
  /// Called when a realtime event says the task changed. Invalidating the
  /// provider instead would throw away pending and failed ticks — the same
  /// mistake the inbox thread made with unsent messages.
  Future<void> refresh() async {
    final fresh = await ref.read(tasksApiProvider).get(arg);
    if (_disposed) return;

    final current = state.valueOrNull;
    state = AsyncData(
      TaskDetailState(task: fresh, pending: current?.pending ?? const []),
    );
  }

  Future<void> toggleSubtask(String subtaskId, {required bool done}) async {
    final current = state.valueOrNull;
    if (current == null) return;

    // A retry reuses the key of the attempt it is retrying, so the server can
    // recognise it. A fresh tick gets a new one.
    final existing = current.pendingFor(subtaskId);
    final tick = PendingTick(
      subtaskId: subtaskId,
      done: done,
      clientRequestId: existing?.clientRequestId ?? newClientId(),
    );

    state = AsyncData(
      current.copyWith(pending: _upsert(current.pending, tick)),
    );

    try {
      final updated = await ref
          .read(tasksApiProvider)
          .setSubtaskDone(
            arg,
            subtaskId,
            done: done,
            clientRequestId: tick.clientRequestId,
          );
      _settle(subtaskId, updated);
    } on AppException catch (error) {
      _fail(subtaskId, error.message);
    } on Object catch (error, stackTrace) {
      // Anything else is a bug, but the tick must still land on "failed" and
      // stay visible. A box that silently springs back reads as "it saved".
      _fail(subtaskId, 'Không lưu được. Vui lòng thử lại.');
      CrashReporting.recordHandled(
        error,
        stackTrace,
        reason: 'tasks: ticking a subtask',
      );
    }
  }

  /// Drops a failed tick the worker chose not to retry.
  void discard(String subtaskId) {
    final current = state.valueOrNull;
    if (current == null) return;

    state = AsyncData(
      current.copyWith(
        pending: [
          for (final tick in current.pending)
            if (tick.subtaskId != subtaskId) tick,
        ],
      ),
    );
  }

  Future<void> setStatus(String status) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final updated = await ref.read(tasksApiProvider).setStatus(arg, status);
    if (_disposed) return;
    state = AsyncData(current.copyWith(task: updated));
  }

  /// The server confirmed the tick: take it out of the outbox and adopt the
  /// server's copy of the task.
  void _settle(String subtaskId, Task updated) {
    final current = state.valueOrNull;
    if (_disposed || current == null) return;

    state = AsyncData(
      TaskDetailState(
        task: updated,
        pending: [
          for (final tick in current.pending)
            if (tick.subtaskId != subtaskId) tick,
        ],
      ),
    );
  }

  void _fail(String subtaskId, String reason) {
    final current = state.valueOrNull;
    if (_disposed || current == null) return;

    state = AsyncData(
      current.copyWith(
        pending: [
          for (final tick in current.pending)
            if (tick.subtaskId == subtaskId)
              tick.copyWith(error: reason)
            else
              tick,
        ],
      ),
    );
  }

  static List<PendingTick> _upsert(
    List<PendingTick> pending,
    PendingTick tick,
  ) {
    return [
      for (final existing in pending)
        if (existing.subtaskId != tick.subtaskId) existing,
      tick,
    ];
  }
}

final taskDetailProvider =
    AutoDisposeAsyncNotifierProvider.family<
      TaskController,
      TaskDetailState,
      String
    >(TaskController.new);
