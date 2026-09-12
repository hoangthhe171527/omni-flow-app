import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/tasks_api.dart';
import '../domain/task.dart';
import 'task_controller.dart';

/// Cỡ trang khi xin bình luận cũ hơn. Trần API là 50; 20 là một cú bấm đọc
/// hết trong một lần cuộn.
const kCommentsPerPage = 20;

/// Bình luận của một việc, MỚI NHẤT TRƯỚC, cộng những trang cũ đã xin thêm.
class CommentsState {
  const CommentsState({
    required this.items,
    required this.total,
    this.seeded = true,
    this.loadingOlder = false,
    this.reachedEnd = false,
  });

  /// Mới nhất trước — đúng thứ tự API; màn hình lật lại để đọc như trò chuyện.
  final List<TaskComment> items;

  /// Đã có bản Task để gieo hạt chưa. false trong khoảnh khắc chi tiết còn
  /// đang tải: màn hình khi ấy vẽ bình luận từ Task nó đang cầm, không vẽ
  /// một danh sách trống.
  final bool seeded;

  /// Tổng thật: `comments_count` của việc, hoặc `pagination.total` nếu server
  /// đã trả một trang — lấy số lớn hơn, vì hai con số có thể lệch một nhịp.
  final int total;

  final bool loadingOlder;

  /// Server đã khai hết trang. Khác [hasMore]: tổng có thể lệch một chút khi
  /// một bình luận mới chen vào giữa hai lần xin, và khi ấy không xin nữa.
  final bool reachedEnd;

  /// Còn bao nhiêu dòng cũ hơn chưa có trên màn.
  int get hiddenCount => max(0, total - items.length);

  bool get hasMore => !reachedEnd && hiddenCount > 0;

  CommentsState copyWith({bool? loadingOlder}) => CommentsState(
    items: items,
    total: total,
    seeded: seeded,
    loadingOlder: loadingOlder ?? this.loadingOlder,
    reachedEnd: reachedEnd,
  );
}

/// Trao đổi trên một việc, đọc được HẾT ngay trong app.
///
/// Hạt giống là bình luận đi kèm phản hồi chi tiết — đã có trong tay, không
/// tốn lượt gọi nào khi mở việc. Endpoint `GET /tasks/{id}/comments` chỉ được
/// hỏi khi người ta bấm "Xem thêm". Trước đây phần bị cắt được thay bằng dòng
/// "xem trên web", và ở xưởng thì không ai mở web: lý do một cây đàn bị trả
/// về ba tuần trước nằm đúng trong phần bị cắt.
class TaskCommentsController
    extends AutoDisposeFamilyAsyncNotifier<CommentsState, String> {
  /// Trang cũ đã xin qua endpoint. Sống qua các lần [build]: Riverpod giữ
  /// nguyên notifier khi dependency đổi, chỉ gọi lại build — nên một bản Task
  /// mới về (gửi bình luận, realtime) không làm mất những trang đã tải.
  final _older = <TaskComment>[];
  int? _serverTotal;
  bool _reachedEnd = false;
  bool _loading = false;
  bool _disposed = false;
  Task? _task;

  @override
  FutureOr<CommentsState> build(String taskId) {
    _disposed = false;
    ref.onDispose(() => _disposed = true);

    // `select` theo Task: build chạy lại đúng khi server trả một bản việc mới,
    // không phải khi một tick đang chờ đổi trạng thái.
    _task = ref.watch(
      taskDetailProvider(taskId).select((s) => s.valueOrNull?.task),
    );

    return _compose();
  }

  /// Hạt giống (mới nhất trước) + trang cũ, bỏ trùng theo id.
  ///
  /// Bỏ trùng là bắt buộc: một bình luận vừa gửi nằm trong bản Task mới VÀ có
  /// thể nằm trong trang server trả sau đó, vì nó đẩy mọi trang xuống một dòng.
  CommentsState _compose() {
    final task = _task;
    final seen = <String>{};
    final items = <TaskComment>[
      if (task != null)
        for (final c in task.comments.reversed)
          if (seen.add(c.id)) c,
      for (final c in _older)
        if (seen.add(c.id)) c,
    ];

    return CommentsState(
      items: items,
      total: [
        task?.commentCount ?? 0,
        _serverTotal ?? 0,
        items.length,
      ].reduce(max),
      seeded: task != null,
      loadingOlder: _loading,
      reachedEnd: _reachedEnd,
    );
  }

  /// Xin trang cũ hơn kế tiếp.
  ///
  /// Trang tính theo SỐ ĐÃ CÓ, không theo "trang đã xin": hạt giống từ phản
  /// hồi chi tiết có thể là 10 hay 20 dòng tuỳ server cắt ở đâu, và không được
  /// giả định con số ấy bằng cỡ trang. `have ~/ 20 + 1` là trang chứa dòng kế
  /// tiếp; `have % 20` là phần đầu trang đó đã có trên màn, bỏ qua.
  ///
  /// Lỗi NÉM RA sau khi giữ nguyên những gì đang có: màn hiện snackbar và nút
  /// vẫn còn đó để bấm lại. Nuốt ở đây là bấm không thấy gì xảy ra.
  Future<void> loadOlder() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || _loading) return;

    _loading = true;
    state = AsyncData(current.copyWith(loadingOlder: true));

    try {
      final have = current.items.length;
      final page = await ref
          .read(tasksApiProvider)
          .comments(
            arg,
            page: have ~/ kCommentsPerPage + 1,
            perPage: kCommentsPerPage,
          );
      if (_disposed) return;

      final known = {
        for (final c in current.items) c.id,
        for (final c in _older) c.id,
      };
      _older.addAll(
        page.items.skip(have % kCommentsPerPage).where((c) => known.add(c.id)),
      );
      _serverTotal = page.pagination.total;
      _reachedEnd = !page.pagination.hasMore;
    } finally {
      _loading = false;
      if (!_disposed) state = AsyncData(_compose());
    }
  }
}

final taskCommentsProvider =
    AutoDisposeAsyncNotifierProvider.family<
      TaskCommentsController,
      CommentsState,
      String
    >(TaskCommentsController.new);
