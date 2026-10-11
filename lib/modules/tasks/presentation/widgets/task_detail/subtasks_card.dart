import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/error/app_exception.dart';
import '../../../../../design/platform/omni_motion_scope.dart';
import '../../../../../design/tokens/tokens.dart';
import '../../../../team/team.dart';
import '../../../application/task_controller.dart';
import '../../../domain/task.dart';
import '../edit_sheets.dart';
import '../subtask_assignee_sheet.dart';
import '../subtask_row.dart';
import 'detail_card.dart';
import 'menu_sheet.dart';
import 'subtask_create_sheet.dart';

/// Thẻ Việc con (`TaskDetail.dc.html`, `TaskSubtasks.dc.html`): đầu thẻ
/// "Việc con" + "xong/tổng" + nút + (mở sheet tạo), thanh tiến độ 4px chạy
/// 400ms, rồi các dòng [SubtaskRow].
///
/// Quyền:
///  * [canTick] (`taskAccess.canComplete`): tick và giao / đổi / bỏ gán người
///    làm. Người thợ tự nhận một công đoạn trống vẫn đi qua đường này.
///  * [canEdit] (người giao việc): thêm, đổi tên, xoá việc con.
class SubtasksCard extends ConsumerWidget {
  const SubtasksCard({
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
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final subtasks = task.subtasks;
    final done = subtasks.where((s) => s.done).length;
    final byId = ref.watch(teamMemberByIdProvider);
    final fraction = subtasks.isEmpty ? 0.0 : done / subtasks.length;
    final motion = OmniMotion.enabled(context);

    return DetailCard(
      children: [
        DetailCardHeader(
          icon: Icons.checklist_rounded,
          title: 'Việc con',
          count: '$done/${subtasks.length}',
          actions: [
            if (canEdit)
              DetailHeaderButton(
                tooltip: 'Thêm việc con',
                icon: Icons.add_rounded,
                onPressed: () => _create(context),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Container(
              key: const ValueKey('subtask-progress-track'),
              height: 4,
              color: OmniColors.trackOf(context),
              alignment: Alignment.centerLeft,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: fraction),
                duration: motion
                    ? const Duration(milliseconds: 400)
                    : Duration.zero,
                curve: OmniCurves.standard,
                builder: (context, value, _) => FractionallySizedBox(
                  key: const ValueKey('subtask-progress-fill'),
                  widthFactor: value,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            children: [
              for (var i = 0; i < subtasks.length; i++)
                _row(context, subtasks[i], byId, first: i == 0),
            ],
          ),
        ),
        if (subtasks.isNotEmpty) const SizedBox(height: 4),
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
      pending: state.pendingFor(s.id),
      enabled: canTick,
      assigneeName: s.assigneeName ?? known?.name,
      assigneeAvatar: s.assigneeAvatar ?? known?.avatarUrl,
      onToggle: (value) => controller.toggleSubtask(s.id, done: value),
      onRetry: () => controller.toggleSubtask(
        s.id,
        done: state.pendingFor(s.id)?.done ?? s.done,
      ),
      onDiscard: () => controller.discard(s.id),
      onMenu: canEdit || canTick ? () => _menu(context, s) : null,
      onAssign: canTick ? () => _assign(context, s) : null,
    );
  }

  /// Sheet "Việc con mới". Tạo (`POST checklist {title}`), rồi giao người nếu
  /// đã chọn. Giao hỏng thì việc con vẫn còn: báo "Đã tạo nhưng chưa giao
  /// được." chứ không xoá nó đi.
  Future<void> _create(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context);
    final taskId = task.id;

    await showSubtaskCreateSheet(
      context,
      projectId: task.projectId,
      canAssign: canTick,
      onCreate: (draft) async {
        final before = {
          for (final s
              in container
                      .read(taskDetailProvider(taskId))
                      .valueOrNull
                      ?.task
                      .subtasks ??
                  task.subtasks)
            s.id,
        };
        await controller.addSubtask(draft.title);
        final userId = draft.assigneeId;
        if (userId == null) return;

        void notAssigned() => messenger.showSnackBar(
          const SnackBar(content: Text('Đã tạo nhưng chưa giao được.')),
        );
        // Id do server sinh: việc con mới là id chưa có trước lượt tạo.
        final after = container
            .read(taskDetailProvider(taskId))
            .valueOrNull
            ?.task;
        final fresh = [
          for (final s in after?.subtasks ?? const <Subtask>[])
            if (!before.contains(s.id)) s.id,
        ];
        if (fresh.isEmpty) return notAssigned();
        try {
          await controller.assignSubtask(fresh.last, userId);
        } on Object {
          notAssigned();
        }
      },
    );
  }

  /// Giao / đổi / bỏ gán người làm.
  ///
  /// Bắt lỗi tại chỗ: [TaskController.assignSubtask] chờ server và NÉM khi hỏng,
  /// mà một Future ném ra từ callback thì không ai bắt.
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

  /// ⋮: Đổi tên, Giao, Xoá (đường hiện có).
  Future<void> _menu(BuildContext context, Subtask s) async {
    final messenger = ScaffoldMessenger.of(context);
    final action = await showDetailMenuSheet<_SubAction>(
      context,
      semanticsLabel: 'Tuỳ chọn việc con',
      title: s.title,
      groups: [
        [
          if (canEdit)
            const DetailMenuItem(
              value: _SubAction.rename,
              icon: Icons.edit_outlined,
              label: 'Đổi tên',
            ),
          if (canTick)
            const DetailMenuItem(
              value: _SubAction.assign,
              icon: Icons.person_add_alt_outlined,
              label: 'Giao người làm',
            ),
        ],
        [
          if (canEdit)
            const DetailMenuItem(
              value: _SubAction.remove,
              icon: Icons.delete_outline,
              label: 'Xoá việc con',
              danger: true,
            ),
        ],
      ],
    );
    if (action == null || !context.mounted) return;

    try {
      switch (action) {
        case _SubAction.remove:
          await controller.removeSubtask(s.id);
        case _SubAction.assign:
          await _assign(context, s);
        case _SubAction.rename:
          final renamed = await showTextEditSheet(
            context: context,
            title: 'Đổi tên việc con',
            initial: s.title,
          );
          if (renamed == null) return;
          await controller.renameSubtask(s.id, renamed);
      }
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

enum _SubAction { rename, assign, remove }
