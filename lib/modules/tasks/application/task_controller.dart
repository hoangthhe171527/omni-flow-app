import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/error/crash_reporting.dart';
import '../../../core/storage/preferences_store.dart';
import '../../../core/storage/storage_keys.dart';
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

  /// Ba thứ phải sống sót qua một lần đóng app: tick nào, bật hay tắt, và
  /// khoá của chính lần gửi đó. Khoá phải là khoá CŨ — sinh khoá mới lúc mở
  /// lại thì lần gửi lại thành một lần gửi khác trong mắt server.
  Map<String, dynamic> toJson() => {
    'subtask_id': subtaskId,
    'done': done,
    'client_request_id': clientRequestId,
  };

  /// Lý do lỗi KHÔNG đọc lại từ đĩa: lý do cũ ("Hết thời gian chờ") mô tả một
  /// lần gửi đã kết thúc từ lâu. Điều duy nhất còn đúng khi mở lại là "chưa có
  /// xác nhận nào của server", nên mọi bản đọc về mang đúng lý do đó.
  ///
  /// Và nó BẮT BUỘC có lý do, chứ không trở về ở trạng thái đang gửi: không
  /// còn request nào chạy để làm nó xong, mà ô đang gửi thì chỉ quay vòng và
  /// không hiện nút "Thử lại" — người thợ sẽ ngồi nhìn một cái ô quay mãi.
  static PendingTick? fromJson(Object? json) {
    if (json is! Map) return null;

    final subtaskId = '${json['subtask_id'] ?? ''}';
    final clientRequestId = '${json['client_request_id'] ?? ''}';
    if (subtaskId.isEmpty || clientRequestId.isEmpty) return null;

    return PendingTick(
      subtaskId: subtaskId,
      done: json['done'] == true,
      clientRequestId: clientRequestId,
      error: 'lần trước chưa gửi xong',
    );
  }
}

/// Hàng chờ tick, ghi xuống ĐĨA.
///
/// [taskDetailProvider] là autoDispose: rời màn chi tiết là provider bị huỷ và
/// cả hàng chờ đi theo — kể cả tick đã báo lỗi. Ở xưởng sóng chập chờn, người
/// thợ tick rồi bỏ máy xuống làm tiếp; lúc quay lại, ô đã tự bỏ tick và không
/// còn gì nói rằng nó chưa lưu. Đó đúng là cách một cây đàn bị bỏ sót.
///
/// Một khoá cho MỘT công việc, không phải một khoá cho tất cả: mở một công
/// việc thì không phải đọc rồi ghi lại hàng chờ của mọi công việc khác.
class SubtaskOutbox {
  const SubtaskOutbox(this._store);

  final PreferencesStore _store;

  List<PendingTick> read(String taskId) {
    final raw = _store.getString(_key(taskId));
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];

      final ticks = <PendingTick>[];
      for (final entry in decoded) {
        final tick = PendingTick.fromJson(entry);
        if (tick != null) ticks.add(tick);
      }

      return ticks;
    } on FormatException {
      // Một chuỗi hỏng trên đĩa không được phép làm màn chi tiết không mở lên
      // được. Mất hàng chờ đã tệ; không vào nổi công việc còn tệ hơn.
      return const [];
    }
  }

  Future<void> write(String taskId, List<PendingTick> ticks) {
    return _store.setString(
      _key(taskId),
      ticks.isEmpty
          ? null
          : jsonEncode([for (final tick in ticks) tick.toJson()]),
    );
  }

  static String _key(String taskId) => '${StorageKeys.subtaskOutbox}.$taskId';
}

final subtaskOutboxProvider = Provider<SubtaskOutbox>((ref) {
  return SubtaskOutbox(ref.watch(preferencesStoreProvider));
});

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

    final task = await ref.watch(tasksApiProvider).get(taskId);

    return TaskDetailState(task: task, pending: _restore(taskId, task));
  }

  /// Đọc lại hàng chờ trên đĩa rồi đối chiếu với bản server vừa lấy về.
  ///
  /// Bỏ đi tick nào server ĐÃ ở đúng trạng thái đó: lệnh ấy tới nơi rồi, chỉ
  /// là phản hồi không về được (người thợ rời màn hình giữa chừng, hoặc app bị
  /// thu hồi). Giữ lại thì màn hình báo "chưa lưu được" cho một việc đã lưu,
  /// đẩy người thợ bấm "Thử lại" cho thứ không cần thử lại — và dạy họ rằng
  /// cảnh báo đó không đáng tin, đúng thứ phải giữ cho đáng tin nhất.
  ///
  /// Bỏ luôn tick của việc con không còn trong checklist: không còn gì để thử
  /// lại nữa, cùng lý do đã ghi ở [removeSubtask].
  List<PendingTick> _restore(String taskId, Task task) {
    final outbox = ref.read(subtaskOutboxProvider);
    final saved = outbox.read(taskId);
    if (saved.isEmpty) return const [];

    final onServer = {
      for (final subtask in task.subtasks) subtask.id: subtask.done,
    };
    final unconfirmed = [
      for (final tick in saved)
        if (onServer.containsKey(tick.subtaskId) &&
            onServer[tick.subtaskId] != tick.done)
          tick,
    ];

    if (unconfirmed.length != saved.length) outbox.write(taskId, unconfirmed);

    return unconfirmed;
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

    // Ghi xuống đĩa TRƯỚC khi gọi mạng: giữa lúc này và lúc có phản hồi,
    // người thợ có thể rời màn hình hoặc hệ điều hành có thể thu hồi app, và
    // tick vẫn phải còn đó khi họ mở lại.
    _publish(current.copyWith(pending: _upsert(current.pending, tick)));

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

    _publish(
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

  /// Chuyển công việc sang công đoạn khác.
  ///
  /// KHÔNG lạc quan như [toggleSubtask]: tick một công đoạn là việc người thợ
  /// làm hàng chục lần một ca ở chỗ sóng yếu, nên nó phải nhúc nhích ngay.
  /// Chuyển công đoạn là việc quản đốc làm vài lần một ngày ở văn phòng, và
  /// một cây đàn nhảy cột rồi nhảy ngược lại vì mạng hỏng là thứ khó tin hơn
  /// nhiều so với một giây chờ.
  Future<void> moveToSection(String? sectionId) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final updated = await ref
        .read(tasksApiProvider)
        .moveToSection(arg, sectionId);
    if (_disposed) return;

    state = AsyncData(current.copyWith(task: updated));
  }

  /// Đặt lại danh sách người làm.
  ///
  /// Chờ server như [moveToSection], không lạc quan: gán việc là lời hứa với
  /// một người khác, và một cái tên hiện lên rồi biến mất vì mạng hỏng còn tệ
  /// hơn một giây chờ.
  Future<void> setAssignees(List<String> userIds) =>
      _apply((api) => api.setAssignees(arg, userIds));

  Future<void> setTitle(String title) =>
      _apply((api) => api.setTitle(arg, title));

  Future<void> setDescription(String description) =>
      _apply((api) => api.setDescription(arg, description));

  Future<void> setPriority(String priority) =>
      _apply((api) => api.setPriority(arg, priority));

  /// null = xoá hạn.
  Future<void> setDueDate(DateTime? dueDate) =>
      _apply((api) => api.setDueDate(arg, dueDate));

  /// Chấm điểm QC. 0 = xoá điểm.
  Future<void> setRating(int rating) =>
      _apply((api) => api.setRating(arg, rating));

  /// Viết một bình luận.
  ///
  /// §B3: QC không đạt thì bình luận rồi kéo cây về. Đây là chỗ duy nhất trong
  /// cả luồng ghi lại LÝ DO — nhật ký hoạt động chỉ biết cây đã bị chuyển cột.
  Future<void> comment(
    String body, {
    List<String> mentionedUserIds = const [],
  }) => _apply(
    (api) => api.comment(arg, body, mentionedUserIds: mentionedUserIds),
  );

  Future<void> addSubtask(String title) =>
      _apply((api) => api.addSubtask(arg, title));

  Future<void> renameSubtask(String subtaskId, String title) =>
      _apply((api) => api.renameSubtask(arg, subtaskId, title));

  /// Nhận một việc con đang trống về mình (§3).
  ///
  /// Chờ server như [setAssignees], KHÔNG lạc quan: nhận việc là lời hứa với cả
  /// tổ, và một cái tên hiện lên rồi biến mất vì mạng hỏng còn tệ hơn một giây
  /// chờ. Tick thì ngược lại, và nó đã có đường riêng.
  Future<void> claimSubtask(String subtaskId, String userId) =>
      _apply((api) => api.claimSubtask(arg, subtaskId, userId));

  /// Xoá một việc con.
  ///
  /// Dọn luôn tick đang chờ của nó nếu có: giữ lại một dòng lỗi "chưa lưu
  /// được" cho một việc con vừa biến mất là để người dùng bấm "Thử lại" vào
  /// một thứ không còn tồn tại.
  Future<void> removeSubtask(String subtaskId) async {
    await _apply((api) => api.removeSubtask(arg, subtaskId));
    discard(subtaskId);
  }

  /// Gọi API rồi thay công việc trong state bằng bản server trả về.
  ///
  /// Không lạc quan, và có lý do: mọi thứ đi qua đây đều là sửa dữ liệu điều
  /// phối — hạn, ưu tiên, người làm. Chúng được sửa vài lần một ngày, và một
  /// giá trị hiện lên rồi lặng lẽ quay về cũ vì mạng hỏng thì tệ hơn nhiều so
  /// với một giây chờ. Tick việc con thì ngược lại, nên nó có đường riêng.
  Future<void> _apply(Future<Task> Function(TasksApi api) call) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final updated = await call(ref.read(tasksApiProvider));
    if (_disposed) return;

    state = AsyncData(current.copyWith(task: updated));
  }

  /// Đặt state mới VÀ ghi hàng chờ xuống đĩa, trong một lời gọi.
  ///
  /// Mọi chỗ đổi `pending` phải đi qua đây. Để hai việc đó ở hai chỗ là mời
  /// một chỗ nào đó quên ghi, và khi ấy màn hình nói một đằng còn đĩa nhớ một
  /// nẻo — sai lặng lẽ, đúng kiểu đã làm mất tick ngay từ đầu.
  void _publish(TaskDetailState next) {
    state = AsyncData(next);

    // Không chờ lần ghi đĩa: ô phải nhúc nhích ngay dưới ngón tay. Lần đọc kế
    // tiếp vẫn thấy giá trị mới, vì SharedPreferences cập nhật bộ nhớ đệm ngay
    // khi được gọi chứ không đợi ghi xong.
    //
    // Và ghi đĩa hỏng thì KHÔNG được kéo theo thao tác chính. Ghi hàng chờ là
    // hiệu ứng phụ: mất nó thì tick vẫn gửi lên server bình thường, chỉ là
    // không sống sót qua một lần đóng app. Ném ra ở đây sẽ biến một sự cố lưu
    // trữ thành một cái tick không bấm được — đổi một mất mát nhỏ lấy một mất
    // mát lớn. Cùng lập luận với `TaskActivityService::safely()` bên API.
    try {
      ref.read(subtaskOutboxProvider).write(arg, next.pending);
    } on Object {
      // Cố ý nuốt: không có gì người dùng làm được với lỗi này.
    }
  }

  /// The server confirmed the tick: take it out of the outbox and adopt the
  /// server's copy of the task.
  void _settle(String subtaskId, Task updated) {
    final current = state.valueOrNull;
    if (_disposed || current == null) return;

    _publish(
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

    _publish(
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
