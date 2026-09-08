import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../application/task_controller.dart';
import '../application/tasks_providers.dart';
import '../data/tasks_api.dart';
import '../domain/task.dart';
import 'widgets/assign_task_sheet.dart';
import 'widgets/assigner_panel.dart';
import 'widgets/comment_section.dart';
import 'widgets/due_chip.dart';
import 'widgets/edit_sheets.dart';
import 'widgets/move_section_sheet.dart';
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
                if (task.hasSubtasks) ...[
                  const SizedBox(height: OmniSpacing.sm),
                  _StageList(
                    task: task,
                    state: state,
                    enabled: canComplete,
                    controller: controller,
                    canEdit: isAssigner,
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
                // Trao đổi đứng TRÊN "đã xem": lý do một cây bị trả về là
                // thứ người thợ cần đọc, còn ai đã mở việc là câu hỏi của
                // quản đốc.
                CommentSection(
                  task: task,
                  taskId: taskId,
                  canWrite: canComplete,
                ),
                if (task.viewers.isNotEmpty) _Viewers(viewers: task.viewers),
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
  });

  final Task task;
  final TaskDetailState state;
  final bool enabled;
  final TaskController controller;

  /// Thêm / đổi tên / xoá việc con. Dựng checklist là việc của người GIAO
  /// việc; thợ tick chứ không đổi danh sách phải làm.
  final bool canEdit;

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
                    icon: Icons.check_rounded,
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
                      style: FilledButton.styleFrom(
                        backgroundColor: done
                            ? scheme.surfaceContainerHighest
                            : OmniColors.success,
                        foregroundColor: done ? scheme.onSurface : Colors.white,
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

  Future<void> _attachPhoto() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
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
  const _Chip({required this.icon, required this.label, this.color});

  final IconData icon;
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
          Icon(icon, size: OmniIconSize.sm, color: tone),
          const SizedBox(width: OmniSpacing.xs),
          Text(label, style: OmniType.caption.copyWith(color: tone)),
        ],
      ),
    );
  }
}

/// The deadline said in words, so it does not depend on colour alone.
