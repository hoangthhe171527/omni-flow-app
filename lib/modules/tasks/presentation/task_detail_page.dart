import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../../../security/session/session_controller.dart';
import '../application/task_controller.dart';
import '../application/task_detail_actions.dart';
import '../application/tasks_providers.dart';
import '../domain/task.dart';
import 'widgets/activity_log.dart';
import 'widgets/assign_task_sheet.dart';
import 'widgets/assigner_panel.dart';
import 'widgets/comment_section.dart';
import 'widgets/edit_sheets.dart';
import 'widgets/move_section_sheet.dart';
import 'widgets/rating_row.dart';
import 'widgets/task_detail/task_action_bar.dart';
import 'widgets/task_detail/task_attachments.dart';
import 'widgets/task_detail/task_claim_bar.dart';
import 'widgets/task_detail/task_description.dart';
import 'widgets/task_detail/task_header.dart';
import 'widgets/task_detail/task_stage_list.dart';
import 'widgets/task_detail/task_viewers.dart';

/// One task, and the two things a worker does with it: tick stages, and say it
/// is finished.
///
/// Those two actions are the entire screen. Everything else — project, deadline,
/// who else is on it — is context placed above them, never between them.
///
/// Từng khối là một widget riêng dưới `widgets/task_detail/`; file này chỉ còn
/// XẾP chúng và nối sheet với [TaskDetailActions]. Bản trước là 1200 dòng
/// trong một file, và mỗi lần sửa một khối là đọc lại cả mười một khối.
class TaskDetailPage extends ConsumerWidget {
  const TaskDetailPage({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(taskDetailProvider(taskId));
    final access = ref.watch(taskAccessProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết công việc'),
        toolbarHeight: 56,
      ),
      body: OmniAsyncView(
        value: detail,
        onRetry: () => ref.invalidate(taskDetailProvider(taskId)),
        data: (state) => _Loaded(
          taskId: taskId,
          state: state,
          canComplete: access.canComplete,
          canAttach: access.canAttach,
          isAssigner: access.isAssigner,
        ),
      ),
    );
  }
}

class _Loaded extends ConsumerWidget {
  const _Loaded({
    required this.taskId,
    required this.state,
    required this.canComplete,
    required this.canAttach,
    required this.isAssigner,
  });

  final String taskId;
  final TaskDetailState state;
  final bool canComplete;
  final bool canAttach;
  final bool isAssigner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = state.visible;
    final controller = ref.read(taskDetailProvider(taskId).notifier);
    final actions = TaskDetailActions(controller);
    // `select`: màn này chỉ cần id người đang cầm máy. Theo dõi cả Session là
    // dựng lại toàn bộ màn chi tiết mỗi khi phiên đổi bất kỳ trường nào.
    //
    // §3: người nhận việc là CHÍNH người đang cầm máy, nên id lấy từ phiên chứ
    // không nhận từ đâu khác — không có màn nào trong app chọn hộ người khác.
    final myUserId = ref.watch(sessionProvider.select((s) => s.user?.id));
    final hasDescription = task.description?.trim().isNotEmpty ?? false;

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: controller.refresh,
            child: CustomScrollView(
              // Luôn kéo được, kể cả khi nội dung ngắn hơn màn — nếu không thì
              // kéo-để-tải-lại không hoạt động đúng ở việc ít công đoạn.
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Người giao việc thấy cùng những dữ kiện đó trong bảng điều
                // phối ngay dưới, ở dạng sửa được.
                SliverToBoxAdapter(
                  child: TaskHeader(
                    task: task,
                    showFacts: !isAssigner,
                    onEditTitle: isAssigner
                        ? () => _editTitle(context, actions, task)
                        : null,
                  ),
                ),
                // §3 là pull-based: ai rảnh TỰ NHẬN. Bảng điều phối chỉ hiện
                // với người có `tasks.projects.manage.all`, nên người thợ đứng
                // trước cây đàn chưa ai nhận cần một nút của riêng họ. Server
                // chưa bao giờ chặn (`tasks.write` thì `worker` có sẵn) — chỗ
                // đứt là ở đây, không có gì để bấm.
                //
                // Chỉ hiện khi mình CHƯA có tên trong việc: đây là nút thêm
                // mình vào, không phải nút bật/tắt. Bỏ mình ra là một quyết
                // định khác hẳn và vẫn là việc của quản đốc.
                if (!isAssigner &&
                    myUserId != null &&
                    !task.assigneeIds.contains(myUserId))
                  SliverToBoxAdapter(
                    child: TaskClaimBar(
                      // Lấy messenger TRƯỚC khi await: ghi xong thì widget này
                      // biến mất (mình đã có tên) và context rời cây widget.
                      onClaim: () => _guard(
                        ScaffoldMessenger.of(context),
                        () => actions.claim(task, myUserId),
                      ),
                    ),
                  ),
                if (isAssigner)
                  SliverToBoxAdapter(
                    child: AssignerPanel(
                      task: task,
                      onMoveSection: () => _moveSection(context, actions, task),
                      onAssign: () => _assign(context, actions, task),
                      onEditDueDate: () => _editDueDate(context, actions, task),
                      onEditPriority: () =>
                          _editPriority(context, actions, task),
                    ),
                  ),
                // Người giao việc thấy khối việc con KỂ CẢ khi trống — nút
                // "Thêm việc con" nằm BÊN TRONG khối này, nên gói nó theo
                // `hasSubtasks` là khoá mất chính đường tạo việc con đầu tiên.
                // Người thợ vẫn không thấy gì khi trống — họ tick chứ không
                // dựng danh sách.
                if (isAssigner || task.hasSubtasks)
                  SliverPadding(
                    padding: const EdgeInsets.only(top: OmniSpacing.sm),
                    sliver: TaskStageList(
                      task: task,
                      state: state,
                      enabled: canComplete,
                      controller: controller,
                      canEdit: isAssigner,
                      currentUserId: myUserId,
                    ),
                  ),
                // Người giao việc thấy khối mô tả KỂ CẢ khi trống — nếu không
                // thì không có chỗ nào để thêm mô tả lần đầu.
                if (isAssigner || hasDescription)
                  SliverToBoxAdapter(
                    child: TaskDescription(
                      text: task.description ?? '',
                      onEdit: isAssigner
                          ? () => _editDescription(context, actions, task)
                          : null,
                    ),
                  ),
                // Ảnh đính kèm đứng NGAY TRƯỚC điểm chấm: người kiểm nhìn ảnh
                // rồi mới chấm, còn người bị trả việc về xem lại chính tấm
                // mình đã gửi.
                SliverToBoxAdapter(
                  child: TaskAttachments(attachments: task.attachments),
                ),
                // Điểm kiểm đứng ngay sau công việc và TRƯỚC trao đổi: nó là
                // kết luận, còn trao đổi là lý do phía sau kết luận đó.
                SliverToBoxAdapter(
                  child: RatingRow(
                    task: task,
                    taskId: taskId,
                    canRate: isAssigner,
                  ),
                ),
                // Trao đổi đứng TRÊN "đã xem": lý do một cây bị trả về là
                // thứ người thợ cần đọc, còn ai đã mở việc là câu hỏi của
                // quản đốc.
                SliverToBoxAdapter(
                  child: CommentSection(
                    task: task,
                    taskId: taskId,
                    canWrite: canComplete,
                  ),
                ),
                if (task.viewers.isNotEmpty)
                  SliverToBoxAdapter(child: TaskViewers(viewers: task.viewers)),
                // Cuối cùng, và GẤP lại: nhật ký là thứ người ta tra khi có
                // nghi vấn, không phải thứ đọc mỗi lần mở việc.
                SliverToBoxAdapter(child: ActivityLog(task: task)),
                const SliverToBoxAdapter(
                  child: SizedBox(height: OmniSpacing.xxl),
                ),
              ],
            ),
          ),
        ),
        TaskActionBar(
          task: task,
          canComplete: canComplete,
          canAttach: canAttach,
          taskId: taskId,
        ),
      ],
    );
  }

  // Mỗi hàm dưới đây chỉ MỞ SHEET rồi giao phần "có gì để ghi không" cho
  // [TaskDetailActions]. Messenger lấy TRƯỚC khi await: sau khi sheet đóng,
  // `context` có thể đã rời khỏi cây widget.

  /// Giao việc cho ai, ngay tại chỗ — thao tác từng bắt buộc phải mở máy tính.
  Future<void> _assign(
    BuildContext context,
    TaskDetailActions actions,
    Task task,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final chosen = await showAssignTaskSheet(
      context: context,
      currentIds: task.assigneeIds,
    );

    await _guard(messenger, () => actions.assign(task, chosen));
  }

  Future<void> _editDueDate(
    BuildContext context,
    TaskDetailActions actions,
    Task task,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final now = DateTime.now();
    final chosen = await showDueDateSheet(
      context: context,
      current: task.dueDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (chosen == null) return;

    await _guard(
      messenger,
      () => actions.editDueDate(task, chosen.clear ? null : chosen.date),
    );
  }

  Future<void> _editPriority(
    BuildContext context,
    TaskDetailActions actions,
    Task task,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final chosen = await showPrioritySheet(
      context: context,
      current: task.priority,
    );

    await _guard(messenger, () => actions.editPriority(task, chosen));
  }

  Future<void> _editTitle(
    BuildContext context,
    TaskDetailActions actions,
    Task task,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final chosen = await showTextEditSheet(
      context: context,
      title: 'Tên việc',
      initial: task.title,
      hint: 'Việc cần làm là gì?',
    );

    await _guard(messenger, () => actions.editTitle(task, chosen));
  }

  Future<void> _editDescription(
    BuildContext context,
    TaskDetailActions actions,
    Task task,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final chosen = await showTextEditSheet(
      context: context,
      title: 'Mô tả',
      initial: task.description ?? '',
      hint: 'Ghi chú, yêu cầu, lưu ý khi làm…',
      multiline: true,
      // Xoá sạch mô tả là một lựa chọn hợp lệ, khác với tên việc.
      allowEmpty: true,
    );

    await _guard(messenger, () => actions.editDescription(task, chosen));
  }

  Future<void> _moveSection(
    BuildContext context,
    TaskDetailActions actions,
    Task task,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    // Danh sách công đoạn đi kèm phản hồi chi tiết — không gọi module plans.
    final chosen = await showMoveSectionSheet(
      context: context,
      sections: task.planSections,
      current: task.sectionId,
    );

    await _guard(messenger, () => actions.moveSection(task, chosen));
  }

  /// Lỗi API hiện snackbar; mọi thứ khác nổ ra như một lỗi lập trình.
  static Future<void> _guard(
    ScaffoldMessengerState messenger,
    Future<void> Function() run,
  ) async {
    try {
      await run();
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}
