import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/utils/formatters.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../application/task_controller.dart';
import '../application/tasks_providers.dart';
import '../data/tasks_api.dart';
import '../domain/task.dart';
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
  });

  final String taskId;
  final TaskDetailState state;
  final bool canComplete;
  final bool canAttach;

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
                _Header(task: task),
                if (task.hasSubtasks) ...[
                  const SizedBox(height: OmniSpacing.sm),
                  _StageList(
                    task: task,
                    state: state,
                    enabled: canComplete,
                    controller: controller,
                  ),
                ],
                if (task.description != null &&
                    task.description!.trim().isNotEmpty)
                  _Description(text: task.description!),
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
}

class _Header extends StatelessWidget {
  const _Header({required this.task});

  final Task task;

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
          Text(task.title, style: OmniType.title),
          const SizedBox(height: OmniSpacing.lg),
          // Deadline and people are chips, not sentences: at a glance from a
          // workbench, three short facts beat one long line.
          Wrap(
            spacing: OmniSpacing.sm,
            runSpacing: OmniSpacing.sm,
            children: [
              _DueChip(task: task),
              for (final name in task.assigneeNames)
                _Chip(icon: Icons.person_outline_rounded, label: name),
            ],
          ),
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
    final complete = task.doneCount == task.totalCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Đã xong ${task.doneCount}/${task.totalCount} công đoạn',
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
            valueColor: AlwaysStoppedAnimation(
              complete ? OmniColors.success : scheme.primary,
            ),
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
  });

  final Task task;
  final TaskDetailState state;
  final bool enabled;
  final TaskController controller;

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
              'Công đoạn',
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
            ),
            // 12dp between rows rather than the usual 8: a mis-tap here marks
            // the wrong stage of a piano complete.
            const SizedBox(height: OmniSpacing.md),
          ],
        ],
      ),
    );
  }
}

class _Description extends StatelessWidget {
  const _Description({required this.text});

  final String text;

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
          Text(text, style: OmniType.body),
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
        borderRadius: OmniRadius.pillAll,
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
class _DueChip extends StatelessWidget {
  const _DueChip({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final overdue = task.daysOverdue;
    final (label, colour) = switch (task) {
      _ when overdue != null => (
        'Quá hạn $overdue ngày',
        OmniColors.destructive,
      ),
      _ when task.isDueToday => ('Hạn hôm nay', OmniColors.warning),
      _ when task.dueDate != null => (
        'Hạn ${task.dueDate!.day}/${task.dueDate!.month}',
        scheme.onSurfaceVariant,
      ),
      _ => ('Chưa đặt hạn', scheme.onSurfaceVariant),
    };

    return _Chip(icon: Icons.schedule_rounded, label: label, color: colour);
  }
}
