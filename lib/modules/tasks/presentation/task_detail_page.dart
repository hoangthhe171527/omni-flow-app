import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../design/components/components.dart';
import '../../../design/platform/omni_motion_scope.dart';
import '../../../design/tokens/tokens.dart';
import '../../../security/session/session_controller.dart';
import '../application/task_controller.dart';
import '../application/tasks_providers.dart';
import '../data/tasks_api.dart';
import '../domain/task.dart';
import 'widgets/activity_log.dart';
import 'widgets/assign_task_sheet.dart';
import 'widgets/assigner_panel.dart';
import 'widgets/comment_section.dart';
import 'widgets/due_chip.dart';
import 'widgets/edit_sheets.dart';
import 'widgets/move_section_sheet.dart';
import 'widgets/rating_row.dart';
import 'widgets/subtask_row.dart';

/// One task, and the two things a worker does with it: tick stages, and say it
/// is finished.
///
/// Those two actions are the entire screen. Everything else — project, deadline,
/// who else is on it — is context placed above them, never between them.
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
    final myUserId = ref.watch(sessionProvider).user?.id;

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: controller.refresh,
            child: ListView(
              padding: const EdgeInsets.only(bottom: OmniSpacing.xxl),
              children: [
                // Người giao việc thấy cùng những dữ kiện đó trong bảng điều
                // phối ngay dưới, ở dạng sửa được. Hiện cả hai là in cùng một
                // thông tin hai lần trên một màn hình bằng bàn tay.
                _Header(
                  task: task,
                  showFacts: !isAssigner,
                  onEditTitle: isAssigner
                      ? () => _editTitle(context, controller, task)
                      : null,
                ),
                // §3 là pull-based: ai rảnh TỰ NHẬN. Nhưng cho tới giờ chỗ
                // duy nhất chạm được `assignee_ids` là bảng điều phối ngay
                // dưới, mà bảng đó chỉ hiện với người có
                // `tasks.projects.manage.all` — nên người thợ đứng ngay trước
                // cây đàn chưa ai nhận vẫn phải nhắn quản đốc mới được gán.
                // Thông báo "Công đoạn đang trống" (NotifyStageOpen) dẫn họ
                // tới đúng màn này rồi bỏ họ ở đó.
                //
                // Server chưa bao giờ chặn: `assertCanEditTasks` chỉ chặn vai
                // `viewer`, còn `tasks.write` thì `worker` có sẵn. Chỗ đứt là
                // ở đây — không có gì để bấm.
                //
                // Chỉ hiện khi mình CHƯA có tên trong việc: đây là nút thêm
                // mình vào, không phải nút bật/tắt. Bỏ mình ra là một quyết
                // định khác hẳn và vẫn là việc của quản đốc.
                if (!isAssigner &&
                    myUserId != null &&
                    !task.assigneeIds.contains(myUserId))
                  _ClaimBar(
                    onClaim: () => _claim(context, controller, task, myUserId),
                  ),
                if (isAssigner)
                  AssignerPanel(
                    task: task,
                    onMoveSection: () =>
                        _moveSection(context, controller, task),
                    onAssign: () => _assign(context, controller, task),
                    onEditDueDate: () =>
                        _editDueDate(context, controller, task),
                    onEditPriority: () =>
                        _editPriority(context, controller, task),
                  ),
                // Người giao việc thấy khối việc con KỂ CẢ khi trống — nút
                // "Thêm việc con" nằm BÊN TRONG khối này, nên gói nó theo
                // `hasSubtasks` là khoá mất chính đường tạo việc con đầu tiên:
                // một công việc vừa tạo luôn có checklist rỗng, và dựng danh
                // sách công đoạn lại buộc phải mở máy tính. Người thợ vẫn
                // không thấy gì khi trống — họ tick chứ không dựng danh sách.
                if (isAssigner || task.hasSubtasks) ...[
                  const SizedBox(height: OmniSpacing.sm),
                  _StageList(
                    task: task,
                    state: state,
                    enabled: canComplete,
                    controller: controller,
                    canEdit: isAssigner,
                    // §3: người nhận việc là CHÍNH người đang cầm máy, nên id
                    // lấy từ phiên chứ không nhận từ đâu khác — không có màn
                    // nào trong app chọn hộ người khác.
                    currentUserId: ref.watch(sessionProvider).user?.id,
                  ),
                ],
                // Người giao việc thấy khối mô tả KỂ CẢ khi trống — nếu không
                // thì không có chỗ nào để thêm mô tả lần đầu.
                if (isAssigner ||
                    (task.description?.trim().isNotEmpty ?? false))
                  _Description(
                    text: task.description ?? '',
                    onEdit: isAssigner
                        ? () => _editDescription(context, controller, task)
                        : null,
                  ),
                // Ảnh đính kèm đứng NGAY TRƯỚC điểm chấm: người kiểm nhìn ảnh
                // rồi mới chấm, còn người bị trả việc về xem lại chính tấm
                // mình đã gửi. Trước đây app gửi ảnh lên rồi không xem lại
                // được ở đâu cả.
                _Attachments(attachments: task.attachments),
                // Điểm kiểm đứng ngay sau công việc và TRƯỚC trao đổi: nó là
                // kết luận, còn trao đổi là lý do phía sau kết luận đó.
                RatingRow(task: task, taskId: taskId, canRate: isAssigner),
                // Trao đổi đứng TRÊN "đã xem": lý do một cây bị trả về là
                // thứ người thợ cần đọc, còn ai đã mở việc là câu hỏi của
                // quản đốc.
                CommentSection(
                  task: task,
                  taskId: taskId,
                  canWrite: canComplete,
                ),
                if (task.viewers.isNotEmpty) _Viewers(viewers: task.viewers),
                // Cuối cùng, và GẤP lại: nhật ký là thứ người ta tra khi có
                // nghi vấn, không phải thứ đọc mỗi lần mở việc. Trao đổi ở
                // trên ghi LÝ DO một cây bị trả về; chỗ này ghi việc đã xảy
                // ra — ai chuyển, từ cột nào sang cột nào, lúc nào.
                ActivityLog(task: task),
              ],
            ),
          ),
        ),
        _ActionBar(
          task: task,
          canComplete: canComplete,
          canAttach: canAttach,
          taskId: taskId,
        ),
      ],
    );
  }

  /// Tự nhận việc: THÊM mình vào danh sách người làm.
  ///
  /// Gửi lại CẢ danh sách kèm id của mình, chứ không gửi mỗi id của mình:
  /// `PUT /tasks/{id}` ghi đè `assignee_ids`, nên gửi một mình là lặng lẽ gỡ
  /// những người đang cùng làm ra khỏi việc — họ mất luôn việc trong danh
  /// sách của mình và không có gì báo cho ai biết.
  ///
  /// Không hỏi lại: nhận nhầm thì quản đốc gỡ ra trong một giây, còn thêm một
  /// hộp thoại giữa người thợ và việc họ định làm thì ngày nào cũng tốn.
  Future<void> _claim(
    BuildContext context,
    TaskController controller,
    Task task,
    String userId,
  ) async {
    // Lấy messenger TRƯỚC khi await: ghi xong thì widget này biến mất (mình đã
    // có tên trong việc) và `context` không còn trong cây widget nữa.
    final messenger = ScaffoldMessenger.of(context);

    try {
      await controller.setAssignees([...task.assigneeIds, userId]);
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// Giao việc cho ai, ngay tại chỗ.
  ///
  /// Trước đây dòng "Người làm" chỉ đọc được, nên giao việc là thao tác duy
  /// nhất trong cả luồng bắt buộc phải mở máy tính — trong khi người giao việc
  /// ở xưởng thì đứng giữa nhà xưởng.
  Future<void> _assign(
    BuildContext context,
    TaskController controller,
    Task task,
  ) async {
    // Lấy messenger TRƯỚC khi await: sau khi sheet đóng, `context` có thể đã
    // rời khỏi cây widget.
    final messenger = ScaffoldMessenger.of(context);

    final chosen = await showAssignTaskSheet(
      context: context,
      currentIds: task.assigneeIds,
    );

    // Đóng sheet mà không lưu, hoặc lưu lại đúng danh sách cũ: không có gì để
    // ghi, và một lượt ghi rỗng vẫn chạm `updated_at` lẫn nhật ký hoạt động.
    if (chosen == null || _sameIds(chosen, task.assigneeIds)) return;

    try {
      await controller.setAssignees(chosen);
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// So hai danh sách người làm mà không quan tâm thứ tự.
  static bool _sameIds(List<String> a, List<String> b) =>
      a.length == b.length && a.toSet().containsAll(b);

  /// Đặt hoặc xoá hạn.
  ///
  /// Xoá được là điều kiện đủ để chức năng này dùng thật: đặt nhầm ngày rồi
  /// kẹt luôn thì lần sau người ta không dám đặt nữa. "Chưa hẹn" là một trạng
  /// thái có nghĩa, không phải một ô còn thiếu.
  Future<void> _editDueDate(
    BuildContext context,
    TaskController controller,
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

    final value = chosen.clear ? null : chosen.date;
    if (_sameDay(value, task.dueDate)) return;

    try {
      await controller.setDueDate(value);
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  static bool _sameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a == b;

    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _editPriority(
    BuildContext context,
    TaskController controller,
    Task task,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final chosen = await showPrioritySheet(
      context: context,
      current: task.priority,
    );

    if (chosen == null || chosen == task.priority) return;

    try {
      await controller.setPriority(chosen);
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _editTitle(
    BuildContext context,
    TaskController controller,
    Task task,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final chosen = await showTextEditSheet(
      context: context,
      title: 'Tên việc',
      initial: task.title,
      hint: 'Việc cần làm là gì?',
    );

    if (chosen == null) return;

    try {
      await controller.setTitle(chosen);
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _editDescription(
    BuildContext context,
    TaskController controller,
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

    if (chosen == null) return;

    try {
      await controller.setDescription(chosen);
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _moveSection(
    BuildContext context,
    TaskController controller,
    Task task,
  ) async {
    // Lấy messenger TRƯỚC khi await: sau khi sheet đóng, `context` có thể đã
    // rời khỏi cây widget, và tra nó lúc đó là một lỗi lúc chạy.
    final messenger = ScaffoldMessenger.of(context);

    // Danh sách công đoạn đi kèm phản hồi chi tiết. Trước đây chỗ này gọi
    // `planProvider` — một lượt mạng thứ hai chỉ để lấy vài cái tên, và là
    // cạnh duy nhất khiến module tasks phụ thuộc module plans.
    final chosen = await showMoveSectionSheet(
      context: context,
      sections: task.planSections,
      current: task.sectionId,
    );

    // Đóng sheet mà không chọn, hoặc chọn lại đúng công đoạn đang đứng: không
    // có gì để ghi, và một lượt ghi rỗng vẫn chạm updated_at.
    if (chosen == null || chosen == task.sectionId) return;

    try {
      await controller.moveToSection(chosen);
    } on AppException catch (e) {
      // Cổng QC từ chối bằng 422 kèm TÊN các công đoạn còn thiếu. Nuốt lỗi ở
      // đây là để quản đốc bấm lại lần nữa mà không hiểu vì sao thẻ không
      // nhúc nhích — và câu trả lời thì đã nằm sẵn trong phản hồi.
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

/// "Nhận việc này" — người thợ tự thêm mình vào một việc chưa nhận.
///
/// Cố ý KHÔNG mở bộ chọn người: nó chỉ gửi đúng một id, id của chính người
/// đang bấm. Bộ chọn người lấy danh sách từ `GET /memberships`, đường cần
/// `membership.members.read` — quyền mà vai `worker` cố ý không có, nên với
/// đúng người cần tự nhận thì bộ chọn đó luôn rỗng. Gán NGƯỜI KHÁC vẫn là
/// việc của quản đốc, và vẫn nằm trong bảng điều phối.
class _ClaimBar extends StatefulWidget {
  const _ClaimBar({required this.onClaim});

  final Future<void> Function() onClaim;

  @override
  State<_ClaimBar> createState() => _ClaimBarState();
}

class _ClaimBarState extends State<_ClaimBar> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      color: scheme.surface,
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.lg,
        0,
        OmniSpacing.lg,
        OmniSpacing.lg,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton.icon(
          onPressed: _busy ? null : _claim,
          icon: const Icon(Icons.person_add_alt_rounded),
          label: const Text('Nhận việc này'),
        ),
      ),
    );
  }

  /// Khoá nút trong lúc gửi: hai lần chạm liên tiếp là hai lượt ghi, và lượt
  /// sau mang theo bản chụp cũ nên nó nhân đôi id của mình trong danh sách.
  Future<void> _claim() async {
    setState(() => _busy = true);
    try {
      await widget.onClaim();
    } finally {
      // Nhận xong thì widget này biến mất cùng lần dựng lại, nên chỉ đường
      // THẤT BẠI mới thật sự cần mở khoá.
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.task, this.showFacts = true, this.onEditTitle});

  final Task task;

  /// Hiện dải chip hạn + người làm.
  ///
  /// Tắt với người giao việc: họ có cùng những dữ kiện đó ngay dưới, trong
  /// bảng điều phối, ở dạng sửa được.
  final bool showFacts;

  /// Đổi tên việc. Null = chỉ đọc.
  final VoidCallback? onEditTitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.surface,
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.lg,
        OmniSpacing.lg,
        OmniSpacing.lg,
        OmniSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (task.projectName != null) ...[
            Text(
              task.projectName!,
              style: OmniType.overline.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: OmniSpacing.xs),
          ],
          // Chạm vào chính cái tên để sửa nó. Một nút bút chì ở góc trên là
          // thêm một thứ phải tìm, trong khi cái tên thì đang ở ngay đó.
          if (onEditTitle == null)
            Text(task.title, style: OmniType.title)
          else
            InkWell(
              onTap: onEditTitle,
              borderRadius: OmniRadius.mdAll,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(task.title, style: OmniType.title)),
                  const SizedBox(width: OmniSpacing.sm),
                  Icon(
                    Icons.edit_outlined,
                    size: OmniIconSize.md,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          if (showFacts) ...[
            const SizedBox(height: OmniSpacing.lg),
            // Deadline and people are chips, not sentences: at a glance from a
            // workbench, three short facts beat one long line.
            Wrap(
              spacing: OmniSpacing.sm,
              runSpacing: OmniSpacing.sm,
              children: [
                DueChip(task: task),
                for (final name in task.assigneeNames)
                  _Chip(icon: Icons.person_outline_rounded, label: name),
              ],
            ),
          ],
          if (task.hasSubtasks) ...[
            const SizedBox(height: OmniSpacing.lg),
            _Progress(task: task),
          ],
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Đã xong ${task.doneCount}/${task.totalCount} việc con',
          style: OmniType.caption.copyWith(
            color: scheme.onSurfaceVariant,
            fontFeatures: OmniType.tabular,
          ),
        ),
        const SizedBox(height: OmniSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(OmniRadius.xs),
          child: LinearProgressIndicator(
            value: task.progress,
            minHeight: 8,
            backgroundColor: scheme.surfaceContainerHighest,
            // Xong hay chưa đọc qua CON SỐ bên trên và qua độ dài thanh,
            // không qua sắc màu. Đổi sang xanh lá khi đầy là đưa vào một màu
            // thương hiệu thứ hai — cùng lỗi đã sửa ở ô tick công đoạn, và
            // người mù màu lục-đỏ không thấy khác biệt nào cả.
            valueColor: AlwaysStoppedAnimation(scheme.primary),
          ),
        ),
      ],
    );
  }
}

class _StageList extends StatelessWidget {
  const _StageList({
    required this.task,
    required this.state,
    required this.enabled,
    required this.controller,
    required this.canEdit,
    required this.currentUserId,
  });

  final Task task;
  final TaskDetailState state;
  final bool enabled;
  final TaskController controller;

  /// Thêm / đổi tên / xoá việc con. Dựng checklist là việc của người GIAO
  /// việc; thợ tick chứ không đổi danh sách phải làm.
  final bool canEdit;

  /// Ai đang cầm máy. Null = chưa có phiên người dùng (token máy), và khi đó
  /// không mời nhận việc: không biết nhận về cho ai.
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surface,
      padding: const EdgeInsets.symmetric(vertical: OmniSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              OmniSpacing.lg,
              OmniSpacing.sm,
              OmniSpacing.lg,
              OmniSpacing.sm,
            ),
            child: Text(
              'Việc con',
              style: OmniType.overline.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          for (final subtask in task.subtasks) ...[
            SubtaskRow(
              subtask: subtask,
              pending: state.pendingFor(subtask.id),
              enabled: enabled,
              onToggle: (done) =>
                  controller.toggleSubtask(subtask.id, done: done),
              onRetry: () => controller.toggleSubtask(
                subtask.id,
                done: state.pendingFor(subtask.id)?.done ?? subtask.done,
              ),
              onDiscard: () => controller.discard(subtask.id),
              onEdit: canEdit ? () => _editSubtask(context, subtask) : null,
              // Nhận việc KHÔNG khoá theo `canEdit`: dựng checklist là việc của
              // quản đốc, còn nhận một công đoạn trống là việc của thợ (§3).
              onClaim: currentUserId == null
                  ? null
                  : () => _claim(context, subtask.id),
            ),
            // 12dp between rows rather than the usual 8: a mis-tap here marks
            // the wrong stage of a piano complete.
            const SizedBox(height: OmniSpacing.md),
          ],
          if (canEdit)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: OmniSpacing.lg),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _addSubtask(context),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Thêm việc con'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Nhận công đoạn này về mình.
  ///
  /// Bắt lỗi tại chỗ: [TaskController.claimSubtask] chờ server và NÉM khi hỏng,
  /// mà một Future ném ra từ callback của nút thì không ai bắt — bấm xong không
  /// có gì xảy ra và cũng không có gì báo, đúng kiểu hỏng im lặng đã lặp lại
  /// nhiều lần ở dự án này.
  Future<void> _claim(BuildContext context, String subtaskId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await controller.claimSubtask(subtaskId, currentUserId!);
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _addSubtask(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final title = await showTextEditSheet(
      context: context,
      title: 'Việc con mới',
      initial: '',
      hint: 'Công đoạn, bước cần làm…',
    );

    if (title == null) return;

    try {
      await controller.addSubtask(title);
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// Đổi tên hoặc xoá một việc con.
  Future<void> _editSubtask(BuildContext context, Subtask subtask) async {
    final messenger = ScaffoldMessenger.of(context);
    final action = await showSubtaskActionSheet(
      context: context,
      title: subtask.title,
    );

    if (action == null) return;

    try {
      if (action == SubtaskAction.remove) {
        await controller.removeSubtask(subtask.id);
        return;
      }

      if (!context.mounted) return;
      final renamed = await showTextEditSheet(
        context: context,
        title: 'Đổi tên việc con',
        initial: subtask.title,
      );
      if (renamed == null) return;

      await controller.renameSubtask(subtask.id, renamed);
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

class _Description extends StatelessWidget {
  const _Description({required this.text, this.onEdit});

  final String text;

  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: OmniSpacing.sm),
      color: scheme.surface,
      padding: const EdgeInsets.all(OmniSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mô tả',
            style: OmniType.overline.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: OmniSpacing.sm),
          if (onEdit == null)
            Text(text, style: OmniType.body)
          else
            InkWell(
              onTap: onEdit,
              borderRadius: OmniRadius.mdAll,
              child: SizedBox(
                width: double.infinity,
                child: Text(
                  text.trim().isEmpty ? 'Thêm mô tả…' : text,
                  style: text.trim().isEmpty
                      ? OmniType.body.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        )
                      : OmniType.body,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "Thành viên đã xem" — who has opened this task.
///
/// Placed last, below the work itself: it answers the manager's question
/// ("did they get it") and never the worker's, so it must not sit between a
/// worker and the stage they came to tick.
class _Viewers extends StatelessWidget {
  const _Viewers({required this.viewers});

  final List<TaskViewer> viewers;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: OmniSpacing.sm),
      color: scheme.surface,
      padding: const EdgeInsets.all(OmniSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.visibility_outlined,
                size: OmniIconSize.sm,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: OmniSpacing.xs),
              Text(
                'Thành viên đã xem',
                style: OmniType.overline.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: OmniSpacing.md),
          Wrap(
            spacing: OmniSpacing.sm,
            runSpacing: OmniSpacing.sm,
            children: [
              for (final viewer in viewers)
                Tooltip(
                  message: viewer.viewedAt == null
                      ? viewer.label
                      : '${viewer.label} · ${Formatters.relative(viewer.viewedAt)}',
                  child: _Chip(
                    // Mặt người thay dấu tích: "đã xem" đã nằm ở tiêu đề khối,
                    // còn AI xem thì mặt người nói nhanh hơn tên.
                    leading: OmniAvatar(
                      name: viewer.label,
                      imageUrl: viewer.avatar,
                      size: OmniIconSize.md,
                    ),
                    label: viewer.label,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Ảnh và tệp đã đính trên công việc.
///
/// Hiện cho MỌI người đọc được việc, không gắn với quyền đính kèm: người thợ
/// bị trả việc về cần nhìn lại tấm ảnh chỗ lỗi, kể cả khi họ không gửi thêm
/// ảnh mới.
class _Attachments extends StatelessWidget {
  const _Attachments({required this.attachments});

  final List<TaskAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    // Chưa có tệp nào thì không chiếm chỗ: mỗi khối rỗng đẩy nút "Hoàn thành"
    // xa thêm một quãng trên màn hình cầm một tay giữa xưởng.
    if (attachments.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: OmniSpacing.sm),
      color: scheme.surface,
      padding: const EdgeInsets.all(OmniSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.attachment_outlined,
                size: OmniIconSize.sm,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: OmniSpacing.xs),
              Text(
                'Tệp đính kèm (${attachments.length})',
                style: OmniType.overline.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: OmniSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final attachment in attachments)
                  Padding(
                    padding: const EdgeInsets.only(right: OmniSpacing.sm),
                    child: _AttachmentThumb(attachment: attachment),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Một ô 96dp: ảnh thì hiện chính nó, tệp khác thì hiện tên.
class _AttachmentThumb extends StatelessWidget {
  const _AttachmentThumb({required this.attachment});

  final TaskAttachment attachment;

  /// Mở bản đầy đủ ra ngoài app, như module hộp thư vẫn làm với tệp đính kèm.
  /// Ô 96dp đủ để nhận ra là tấm nào, không đủ để soi một vết xước.
  Future<void> _open() async {
    final uri = Uri.tryParse(attachment.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Cạnh ô, dp. Cũng là cỡ giải mã (nhân tỉ lệ điểm ảnh).
  static const double _size = 96;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: _size,
      height: _size,
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(OmniRadius.sm),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _open,
          child: attachment.isImage
              // Bộ nhớ đệm đĩa + giải mã ở đúng cỡ vẽ: ảnh chụp công đoạn là
              // 3000×4000, và giải mã cỡ gốc cho một ô 96dp là 48 MB bitmap
              // mỗi tấm — ba tấm là màn chi tiết giật khi cuộn. Chỉ khoá
              // chiều rộng để ảnh 3:4 giữ tỉ lệ rồi mới được `cover` cắt.
              ? CachedNetworkImage(
                  imageUrl: attachment.url,
                  fit: BoxFit.cover,
                  memCacheWidth:
                      (_size * MediaQuery.devicePixelRatioOf(context)).round(),
                  fadeInDuration: OmniMotion.of(context).fast,
                  // Mất mạng hay ảnh hỏng thì rơi về cái tên, chứ không để lại
                  // một ô xám không nói gì.
                  errorWidget: (_, _, _) =>
                      _AttachmentName(name: attachment.name),
                )
              : _AttachmentName(name: attachment.name),
        ),
      ),
    );
  }
}

class _AttachmentName extends StatelessWidget {
  const _AttachmentName({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(OmniSpacing.sm),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.insert_drive_file_outlined,
            size: OmniIconSize.lg,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: OmniSpacing.xs),
          Text(
            name,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: OmniType.micro,
          ),
        ],
      ),
    );
  }
}

/// The bar that stays put while the stages scroll.
///
/// It sits above the home indicator rather than under it, and its buttons are
/// 52dp tall — this is the last thing a worker taps with a dirty thumb before
/// putting the phone down.
class _ActionBar extends ConsumerStatefulWidget {
  const _ActionBar({
    required this.task,
    required this.canComplete,
    required this.canAttach,
    required this.taskId,
  });

  final Task task;
  final bool canComplete;
  final bool canAttach;
  final String taskId;

  @override
  ConsumerState<_ActionBar> createState() => _ActionBarState();
}

class _ActionBarState extends ConsumerState<_ActionBar> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!widget.canComplete && !widget.canAttach) {
      return const SizedBox.shrink();
    }

    final done = widget.task.isDone;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(OmniSpacing.lg),
          child: Row(
            children: [
              if (widget.canAttach) ...[
                _SquareButton(
                  icon: Icons.photo_camera_outlined,
                  tooltip: 'Chụp ảnh đính kèm',
                  onPressed: _busy ? null : _attachPhoto,
                ),
                const SizedBox(width: OmniSpacing.md),
              ],
              if (widget.canComplete)
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : () => _setStatus(!done),
                      // Màu THƯƠNG HIỆU, không phải màu "thành công".
                      //
                      // Chữ trắng trên xanh lá #10B981 chỉ đạt 2,5:1 — trượt
                      // chuẩn 4,5:1 trên đúng cái nút được bấm nhiều nhất trong
                      // ngày, ngoài xưởng ánh sáng xấu. Và đó là màu xanh THỨ
                      // HAI đứng cạnh mòng két thương hiệu: hai xanh cạnh tranh
                      // nhau, không cái nào thắng. Trắng trên primary ≈ 7:1.
                      // `test/design/contrast_test.dart` giữ cặp này.
                      style: FilledButton.styleFrom(
                        backgroundColor: done
                            ? scheme.surfaceContainerHighest
                            : scheme.primary,
                        foregroundColor: done
                            ? scheme.onSurface
                            : scheme.onPrimary,
                      ),
                      icon: Icon(
                        done
                            ? Icons.undo_rounded
                            : Icons.check_circle_outline_rounded,
                      ),
                      label: Text(
                        done ? 'Mở lại công việc' : 'Hoàn thành công việc',
                        style: OmniType.bodyStrong,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _setStatus(bool done) async {
    // Finishing a whole task is a heavier act than ticking one stage, so it
    // gets the heavier haptic.
    await HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    try {
      await ref
          .read(taskDetailProvider(widget.taskId).notifier)
          .setStatus(done ? 'done' : 'in_progress');
      // The list behind this screen is showing the old progress until told.
      ref.read(myTasksProvider.notifier).refresh();
      if (mounted && done) {
        _say('Đã báo hoàn thành. Quản lý sẽ nhận thông báo.');
      }
    } on Object {
      if (mounted) _say('Chưa lưu được. Kiểm tra mạng rồi thử lại.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Đính ảnh: chụp mới, hoặc lấy ảnh đã có sẵn trong máy.
  ///
  /// Trước đây chỉ mở thẳng camera. Nhưng người thợ thường đã chụp rồi — ảnh
  /// vừa gửi trong nhóm Zalo, hoặc chụp lúc tháo máy nửa tiếng trước — và bắt
  /// chụp lại một cây đàn đã lắp xong thì đơn giản là không làm được.
  Future<void> _attachPhoto() async {
    final source = await _pickSource();
    if (source == null) return;

    final photo = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
    );
    if (photo == null) return;

    setState(() => _busy = true);
    try {
      await ref.read(tasksApiProvider).attach(widget.taskId, photo.path);
      await ref.read(taskDetailProvider(widget.taskId).notifier).refresh();
      if (mounted) _say('Đã đính kèm ảnh.');
    } on Object {
      if (mounted) _say('Chưa gửi được ảnh. Thử lại khi có mạng.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Hỏi chụp mới hay chọn từ máy. null = đóng lại, không đính gì.
  Future<ImageSource?> _pickSource() => showModalBottomSheet<ImageSource>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Chụp đứng trước: ở xưởng thì phần lớn là chụp ngay tại chỗ, và
          // mục đầu tiên là mục ngón tay bẩn chạm trúng.
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Chụp ảnh'),
            onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Chọn ảnh có sẵn'),
            onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );

  void _say(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 52,
        height: 52,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            side: BorderSide(color: scheme.outlineVariant),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(OmniRadius.md),
            ),
          ),
          // Never icon-only to a screen reader: the tooltip names it aloud.
          child: Icon(icon, color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({this.icon, this.leading, required this.label, this.color});

  final IconData? icon;

  /// Thay cho [icon] khi chip đại diện cho một NGƯỜI: mặt người thay biểu tượng.
  final Widget? leading;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tone = color ?? scheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: OmniSpacing.md,
        vertical: OmniSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: OmniRadius.chipAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null)
            leading!
          else if (icon != null)
            Icon(icon, size: OmniIconSize.sm, color: tone),
          const SizedBox(width: OmniSpacing.xs),
          Text(label, style: OmniType.caption.copyWith(color: tone)),
        ],
      ),
    );
  }
}

/// The deadline said in words, so it does not depend on colour alone.
