import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/error/app_exception.dart';
import '../../../../../design/tokens/tokens.dart';
import '../../../../team/team.dart';
import '../../../application/task_controller.dart';
import '../../../domain/task.dart';
import '../edit_sheets.dart';
import '../subtask_assignee_sheet.dart';
import '../subtask_row.dart';
import 'section_title.dart';

/// Khối VIỆC CON (`TaskDetail.dc.html`): tiêu đề + "{xong}/{tổng}", thẻ bo 8
/// gồm các dòng [SubtaskRow], và (người giao việc) ô "Thêm việc con".
///
/// Là một widget hộp, không phải sliver: một cây đàn có hai chục công đoạn là
/// nhiều, nhưng không tới mức phải dựng lười, và hộp cho phép đặt trong
/// `SliverToBoxAdapter` cùng nhịp với các khối khác.
///
/// Quyền:
///  * [canTick] (`taskAccess.canComplete`): tick và giao / đổi / bỏ gán người
///    làm. Người thợ tự nhận một công đoạn trống vẫn đi qua đường này.
///  * [canEdit] (người giao việc): thêm, đổi tên, xoá việc con.
class SubtaskCard extends ConsumerStatefulWidget {
  const SubtaskCard({
    super.key,
    required this.task,
    required this.state,
    required this.controller,
    required this.canTick,
    required this.canEdit,
  });

  final Task task;
  final TaskDetailState state;
  final TaskController controller;
  final bool canTick;
  final bool canEdit;

  @override
  ConsumerState<SubtaskCard> createState() => _SubtaskCardState();
}

class _SubtaskCardState extends ConsumerState<SubtaskCard> {
  final _add = TextEditingController();

  @override
  void dispose() {
    _add.dispose();
    super.dispose();
  }

  Task get task => widget.task;
  TaskController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtasks = task.subtasks;
    final done = subtasks.where((s) => s.done).length;
    final byId = ref.watch(teamMemberByIdProvider);
    final secondary = OmniColors.byBrightness(
      context,
      OmniColors.mutedForeground,
      scheme.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: DetailSectionTitle('VIỆC CON')),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '$done/${subtasks.length}',
                style: OmniType.micro.copyWith(color: secondary),
              ),
            ),
          ],
        ),
        Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: scheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < subtasks.length; i++)
                _row(context, subtasks[i], byId, first: i == 0),
              if (widget.canEdit) _addRow(context, first: subtasks.isEmpty),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    Subtask s,
    Map<String, TeamMember> byId, {
    required bool first,
  }) {
    final known = s.assigneeId == null ? null : byId[s.assigneeId!];

    return SubtaskRow(
      key: ValueKey(s.id),
      subtask: s,
      first: first,
      pending: widget.state.pendingFor(s.id),
      enabled: widget.canTick,
      assigneeName: s.assigneeName ?? known?.name,
      assigneeAvatar: s.assigneeAvatar ?? known?.avatarUrl,
      onToggle: (value) => controller.toggleSubtask(s.id, done: value),
      onRetry: () => controller.toggleSubtask(
        s.id,
        done: widget.state.pendingFor(s.id)?.done ?? s.done,
      ),
      onDiscard: () => controller.discard(s.id),
      onEdit: widget.canEdit ? () => _edit(context, s) : null,
      onAssign: widget.canTick ? () => _assign(context, s) : null,
    );
  }

  Widget _addRow(BuildContext context, {required bool first}) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: first
            ? null
            : Border(top: BorderSide(color: OmniColors.trackOf(context))),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: SubtaskRow.tapSize),
        child: Row(
          children: [
            const SizedBox.square(
              dimension: SubtaskRow.tapSize,
              child: Icon(Icons.add_rounded, size: 20),
            ),
            Expanded(
              child: TextField(
                controller: _add,
                textInputAction: TextInputAction.done,
                onSubmitted: (value) => _submitAdd(context, value),
                style: OmniType.body,
                decoration: InputDecoration(
                  hintText: 'Thêm việc con',
                  hintStyle: OmniType.body.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: OmniSpacing.md,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Enter → thêm. Xoá ô khi thành công; giữ chữ + báo lỗi khi hỏng, để người
  /// dùng không phải gõ lại.
  bool _adding = false;

  Future<void> _submitAdd(BuildContext context, String value) async {
    final title = value.trim();
    if (title.isEmpty || _adding) return;
    _adding = true;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await controller.addSubtask(title);
      if (mounted) _add.clear();
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      _adding = false;
    }
  }

  /// Giao / đổi / bỏ gán người làm.
  ///
  /// Bắt lỗi tại chỗ: [TaskController.assignSubtask] chờ server và NÉM khi hỏng,
  /// mà một Future ném ra từ callback thì không ai bắt — bấm xong không có gì
  /// xảy ra và cũng không có gì báo.
  Future<void> _assign(BuildContext context, Subtask s) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await showSubtaskAssigneeSheet(
      context,
      projectId: task.projectId,
      subtask: s,
    );
    if (result == null) return;
    final userId = result is SubtaskAssignTo ? result.userId : null;
    try {
      await controller.assignSubtask(s.id, userId);
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// Đổi tên hoặc xoá một việc con.
  Future<void> _edit(BuildContext context, Subtask s) async {
    final messenger = ScaffoldMessenger.of(context);
    final action = await showSubtaskActionSheet(
      context: context,
      title: s.title,
    );
    if (action == null) return;

    try {
      if (action == SubtaskAction.remove) {
        await controller.removeSubtask(s.id);
        return;
      }

      if (!context.mounted) return;
      final renamed = await showTextEditSheet(
        context: context,
        title: 'Đổi tên việc con',
        initial: s.title,
      );
      if (renamed == null) return;

      await controller.renameSubtask(s.id, renamed);
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}
