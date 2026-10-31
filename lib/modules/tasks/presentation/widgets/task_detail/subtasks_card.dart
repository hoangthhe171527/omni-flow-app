import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/error/app_exception.dart';
import '../../../../../design/components/components.dart';
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
    this.details = false,
    this.canReorder = false,
  });

  final Task task;
  final TaskDetailState state;
  final TaskController controller;
  final bool canTick;
  final bool canEdit;

  /// Phiên khai `tasks.subtask_fields`: sheet tạo đủ trường, nút "Hạn", mục
  /// "Sửa mô tả" / "Ngày bắt đầu" trong ⋮ (người giao việc).
  final bool details;

  /// Phiên khai `tasks.checklist_move` VÀ người giao việc: tay kéo 24×44.
  final bool canReorder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final subtasks = task.subtasks;
    final done = subtasks.where((s) => s.done).length;
    final byId = ref.watch(teamMemberByIdProvider);
    final fraction = subtasks.isEmpty ? 0.0 : done / subtasks.length;
    final motion = OmniMotion.enabled(context);

    return DetailCard(
      flat: true,
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
          // Tắt chuyển động: ReorderableListView luôn trượt các dòng khi kéo,
          // nên vẽ Column tĩnh — sắp xếp vẫn được qua ⋮ "Chuyển lên/xuống".
          child: canReorder && motion && subtasks.length > 1
              ? ReorderableListView.builder(
                  key: const ValueKey('subtask-reorder'),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  onReorderStart: (_) => HapticFeedback.mediumImpact(),
                  itemCount: subtasks.length,
                  onReorderItem: (from, to) =>
                      _reorder(context, subtasks, from, to),
                  itemBuilder: (context, i) => _row(
                    context,
                    subtasks[i],
                    byId,
                    first: i == 0,
                    handle: ReorderableDragStartListener(
                      index: i,
                      child: const _DragHandle(),
                    ),
                  ),
                )
              : Column(
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
    Widget? handle,
  }) {
    final known = s.assigneeId == null ? null : byId[s.assigneeId!];

    return SubtaskRow(
      key: ValueKey(s.id),
      subtask: s,
      first: first,
      dragHandle: handle,
      onSetDue: details && canEdit ? () => _setDue(context, s) : null,
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
      onMenu: canEdit || canTick ? (anchor) => _menu(context, s, anchor) : null,
      onAssign: canTick ? (anchor) => _assign(context, s, anchor) : null,
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
      details: details,
      onCreate: (draft) async {
        // API Nhóm 2: MỘT lượt POST mang đủ trường, kể cả người làm — không
        // còn ca "đã tạo nhưng chưa giao được".
        if (details) {
          await controller.createSubtask(
            title: draft.title,
            description: draft.description,
            startDate: draft.startDate,
            dueDate: draft.dueDate,
            assigneeId: draft.assigneeId,
          );
          return;
        }
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
        final created = await controller.addSubtask(draft.title);
        final userId = draft.assigneeId;
        if (userId == null) return;

        void notAssigned() => messenger.showSnackBar(
          const SnackBar(content: Text('Đã tạo nhưng chưa giao được.')),
        );
        // Id do server sinh: việc con mới là id chưa có trước lượt tạo, đọc
        // từ PHẢN HỒI của chính lượt POST — state có thể đã bị realtime thay.
        final fresh = [
          for (final s in created?.subtasks ?? const <Subtask>[])
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

  /// Thả xong: gửi MỘT lệnh move (việc con đứng sau dòng liền trên nó). Lạc
  /// quan trong controller; lỗi thì thứ tự cũ quay lại và báo.
  Future<void> _reorder(
    BuildContext context,
    List<Subtask> shown,
    int from,
    int to,
  ) async {
    // `onReorderItem`: [to] đã tính sau khi gỡ dòng ở [from].
    final target = to;
    if (target == from) return;
    final messenger = ScaffoldMessenger.of(context);
    final order = [...shown];
    final moving = order.removeAt(from);
    order.insert(target, moving);
    try {
      await controller.moveSubtask(
        moving.id,
        afterId: target == 0 ? null : order[target - 1].id,
      );
    } on AppException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(failureText(e, 'Chưa đổi được thứ tự.'))),
      );
    }
  }

  /// Đặt / đổi / xoá hạn việc con (`PATCH … {due_date}`).
  Future<void> _setDue(BuildContext context, Subtask s) async {
    final messenger = ScaffoldMessenger.of(context);
    final today = DateUtils.dateOnly(DateTime.now());
    final choice = await showDueDateSheet(
      context: context,
      current: s.dueDate,
      firstDate: DateTime(today.year - 1),
      lastDate: DateTime(today.year + 3),
    );
    if (choice == null) return;
    final due = choice.date;
    final start = s.startDate;
    if (due != null && start != null && start.isAfter(due)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Hạn phải sau ngày bắt đầu.')),
      );
      return;
    }
    try {
      await controller.setSubtaskDueDate(s.id, due);
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// Đặt ngày bắt đầu bằng lịch. Ném [ValidationException] khi sau hạn —
  /// server không kiểm.
  Future<void> _setStart(BuildContext context, Subtask s) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final chosen = await pickOmniDate(
      context: context,
      initialDate: s.startDate ?? today,
      firstDate: DateTime(today.year - 1),
      lastDate: DateTime(today.year + 3),
    );
    if (chosen == null) return;
    final due = s.dueDate;
    if (due != null && chosen.isAfter(due)) {
      throw const ValidationException('Ngày bắt đầu phải trước hạn.');
    }
    await controller.setSubtaskStartDate(s.id, chosen);
  }

  /// Giao / đổi / bỏ gán người làm.
  ///
  /// Bắt lỗi tại chỗ: [TaskController.assignSubtask] chờ server và NÉM khi hỏng,
  /// mà một Future ném ra từ callback thì không ai bắt.
  Future<void> _assign(BuildContext context, Subtask s, Rect anchor) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await showSubtaskAssigneeMenu(
      context,
      anchor: anchor,
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

  /// ⋮: Đổi tên, Giao, Xoá (đường hiện có); "Chuyển lên / xuống" khi
  /// [canReorder] — đường không cần kéo (trình đọc màn hình, tắt chuyển động).
  Future<void> _menu(BuildContext context, Subtask s, Rect anchor) async {
    final messenger = ScaffoldMessenger.of(context);
    final shown = task.subtasks;
    final at = shown.indexWhere((x) => x.id == s.id);
    final canUp = canReorder && at > 0;
    final canDown = canReorder && at >= 0 && at < shown.length - 1;
    final action = await showDetailAnchoredMenu<_SubAction>(
      context,
      anchor: anchor,
      menuKey: const Key('subtask-options-menu'),
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
          if (canUp)
            const DetailMenuItem(
              value: _SubAction.up,
              icon: Icons.arrow_upward_rounded,
              label: 'Chuyển lên',
            ),
          if (canDown)
            const DetailMenuItem(
              value: _SubAction.down,
              icon: Icons.arrow_downward_rounded,
              label: 'Chuyển xuống',
            ),
        ],
        [
          if (details && canEdit) ...[
            DetailMenuItem(
              value: _SubAction.describe,
              icon: Icons.notes_rounded,
              label: s.description == null ? 'Thêm mô tả' : 'Sửa mô tả',
            ),
            DetailMenuItem(
              value: _SubAction.start,
              icon: Icons.event_outlined,
              label: s.startDate == null
                  ? 'Đặt ngày bắt đầu'
                  : 'Đổi ngày bắt đầu',
            ),
            if (s.startDate != null)
              const DetailMenuItem(
                value: _SubAction.clearStart,
                icon: Icons.event_busy_outlined,
                label: 'Xoá ngày bắt đầu',
              ),
          ],
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
        case _SubAction.up:
        case _SubAction.down:
          // Cùng đường với kéo thả: một lệnh move, `after_id` là dòng sẽ
          // đứng ngay trên nó.
          final up = action == _SubAction.up;
          await _reorder(context, shown, at, up ? at - 1 : at + 1);
        case _SubAction.remove:
          final confirmed = await showOmniConfirm(
            context: context,
            title: 'Xoá việc con “${s.title}”?',
            message: 'Thao tác này không thể hoàn tác.',
            confirmLabel: 'Xoá việc con',
            destructive: true,
          );
          if (!confirmed) return;
          await controller.removeSubtask(s.id);
        case _SubAction.assign:
          await _assign(context, s, anchor);
        case _SubAction.rename:
          final renamed = await showTextEditSheet(
            context: context,
            title: 'Đổi tên việc con',
            initial: s.title,
          );
          if (renamed == null) return;
          await controller.renameSubtask(s.id, renamed);
        case _SubAction.describe:
          final note = await showTextEditSheet(
            context: context,
            title: 'Mô tả việc con',
            initial: s.description ?? '',
            multiline: true,
            allowEmpty: true,
            // `UpdateChecklistItemRequest` `description` `max:2000`.
            maxLength: 2000,
          );
          if (note == null) return;
          await controller.setSubtaskDescription(s.id, note);
        case _SubAction.start:
          await _setStart(context, s);
        case _SubAction.clearStart:
          await controller.setSubtaskStartDate(s.id, null);
      }
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

enum _SubAction {
  rename,
  assign,
  up,
  down,
  describe,
  start,
  clearStart,
  remove,
}

/// Tay kéo `.drag`: 24×44, sáu chấm 14 màu mờ `#9AA5B8`. Kéo NGAY (không
/// cần giữ lâu) — `ReorderableDragStartListener`.
class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Kéo để sắp xếp',
    child: SizedBox(
      key: const ValueKey('subtask-drag-handle'),
      width: 24,
      height: 44,
      child: Icon(
        Icons.drag_indicator_rounded,
        size: 14,
        color: OmniTaskTones.of(context).faint,
      ),
    ),
  );
}
