import 'package:flutter/material.dart';

import '../../../../../core/error/app_exception.dart';
import '../../../../../design/tokens/tokens.dart';
import '../../../application/task_controller.dart';
import '../../../domain/task.dart';
import '../edit_sheets.dart';
import '../subtask_row.dart';

/// Danh sách việc con — một SLIVER, đặt thẳng vào `CustomScrollView`.
///
/// Các dòng dựng theo nhu cầu (`SliverList`) thay vì một `Column` dựng hết:
/// một cây đàn có hai chục công đoạn, và người thợ mở màn này để tick MỘT dòng
/// trong số đó. Trước đây mỗi lần một ô tick đổi là cả hai chục dòng dựng lại.
class TaskStageList extends StatelessWidget {
  const TaskStageList({
    super.key,
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
    final subtasks = task.subtasks;

    return DecoratedSliver(
      decoration: BoxDecoration(color: scheme.surface),
      sliver: SliverPadding(
        padding: const EdgeInsets.symmetric(vertical: OmniSpacing.sm),
        sliver: SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  OmniSpacing.lg,
                  OmniSpacing.sm,
                  OmniSpacing.lg,
                  OmniSpacing.sm,
                ),
                child: Text(
                  'Việc con',
                  style: OmniType.overline.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            SliverList.separated(
              itemCount: subtasks.length,
              itemBuilder: (context, index) => _row(context, subtasks[index]),
              // 12dp between rows rather than the usual 8: a mis-tap here marks
              // the wrong stage of a piano complete.
              separatorBuilder: (_, _) =>
                  const SizedBox(height: OmniSpacing.md),
            ),
            if (subtasks.isNotEmpty)
              const SliverToBoxAdapter(child: SizedBox(height: OmniSpacing.md)),
            if (canEdit)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: OmniSpacing.lg,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _addSubtask(context),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Thêm việc con'),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, Subtask subtask) => SubtaskRow(
    subtask: subtask,
    pending: state.pendingFor(subtask.id),
    enabled: enabled,
    onToggle: (done) => controller.toggleSubtask(subtask.id, done: done),
    onRetry: () => controller.toggleSubtask(
      subtask.id,
      done: state.pendingFor(subtask.id)?.done ?? subtask.done,
    ),
    onDiscard: () => controller.discard(subtask.id),
    onEdit: canEdit ? () => _editSubtask(context, subtask) : null,
    // Nhận việc KHÔNG khoá theo `canEdit`: dựng checklist là việc của quản
    // đốc, còn nhận một công đoạn trống là việc của thợ (§3).
    onClaim: currentUserId == null ? null : () => _claim(context, subtask.id),
  );

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
