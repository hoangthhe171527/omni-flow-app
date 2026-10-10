import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../design/components/components.dart';
import '../../../design/platform/omni_motion_scope.dart';
import '../../../design/tokens/tokens.dart';
import '../../../security/session/session_controller.dart';
import '../application/task_controller.dart';
import '../application/task_detail_actions.dart';
import '../application/tasks_providers.dart';
import '../data/tasks_api.dart';
import '../domain/task.dart';
import 'widgets/activity_log.dart';
import 'widgets/assign_task_sheet.dart';
import 'widgets/comment_section.dart';
import 'widgets/edit_sheets.dart';
import 'widgets/rating_row.dart';
import 'widgets/task_detail/coordination_card.dart';
import 'widgets/task_detail/option_sheet.dart';
import 'widgets/task_detail/section_title.dart';
import 'widgets/task_detail/task_action_bar.dart';
import 'widgets/task_detail/task_description.dart';
import 'widgets/task_detail/subtask_card.dart';
import 'widgets/task_detail/task_title_block.dart';

/// One task, and the two things a worker does with it: tick stages, and say it
/// is finished.
///
/// Those two actions are the entire screen. Everything else — project, deadline,
/// who else is on it — is context placed above them, never between them.
///
/// Từng khối là một widget riêng dưới `widgets/task_detail/`; file này chỉ còn
/// XẾP chúng và nối sheet với [TaskDetailActions].
class TaskDetailPage extends ConsumerWidget {
  const TaskDetailPage({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(taskDetailProvider(taskId));
    final access = ref.watch(taskAccessProvider);
    final loadedTask = detail.valueOrNull?.visible;

    return Scaffold(
      appBar: _DetailHeader(
        title: _headerTitle(loadedTask),
        // Đổi tên và xoá đều là việc của người giao việc; thợ không có menu.
        onRename: access.isAssigner && loadedTask != null
            ? () => _editTitle(
                context,
                TaskDetailActions(
                  ref.read(taskDetailProvider(taskId).notifier),
                ),
                loadedTask,
              )
            : null,
        onDelete: access.isAssigner && loadedTask != null
            ? () => _deleteTask(context, loadedTask)
            : null,
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

  /// "{Dự án} · {Nhóm việc}"; thiếu cái nào bỏ cái đó.
  static String _headerTitle(Task? task) {
    final project = task?.projectName?.trim() ?? '';
    final section = task?.sectionName?.trim() ?? '';
    final parts = [
      if (project.isNotEmpty) project,
      if (section.isNotEmpty) section,
    ];

    return parts.isEmpty ? 'Chi tiết công việc' : parts.join(' · ');
  }

  Future<void> _deleteTask(BuildContext context, Task task) async {
    // Lấy mọi thứ cần dùng SAU khi await trước khi await: màn có thể đã rời
    // cây widget lúc người dùng xác nhận xong.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final container = ProviderScope.containerOf(context);
    final confirmed = await showOmniConfirm(
      context: context,
      title: 'Xoá công việc “${task.title}”?',
      message:
          'Công việc sẽ biến mất trên web và điện thoại. Bạn có thể khôi phục từ thùng rác trên web.',
      confirmLabel: 'Xoá công việc',
      destructive: true,
    );
    if (!confirmed) return;

    try {
      await container.read(tasksApiProvider).deleteTask(task.id);
      container.read(subtaskOutboxProvider).write(task.id, const []);
      container.invalidate(taskDetailProvider(task.id));
      container.read(taskRealtimeSignalProvider.notifier).bump();
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Đã xoá công việc.')),
      );
    } on AppException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

enum _TaskAction { rename, delete }

/// Header kính mờ (`TaskDetail.dc.html`): ‹ quay lại, "{Dự án} · {Nhóm việc}"
/// giữa, ⋯ "Tuỳ chọn công việc" (chỉ người giao việc). Tap target 44.
class _DetailHeader extends StatelessWidget implements PreferredSizeWidget {
  const _DetailHeader({
    required this.title,
    required this.onRename,
    required this.onDelete,
  });

  final String title;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final glass = OmniColors.byBrightness(
      context,
      OmniColors.background.withValues(alpha: 0.82),
      OmniColors.darkBackground.withValues(alpha: 0.82),
    );
    final secondary = OmniColors.byBrightness(
      context,
      OmniColors.mutedForeground,
      scheme.onSurfaceVariant,
    );
    final danger = OmniColors.dangerTextOf(context);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: glass,
            border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
          ),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 52,
              child: Row(
                children: [
                  const SizedBox(width: 2),
                  IconButton(
                    tooltip: 'Quay lại',
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      maximumSize: const Size(44, 44),
                      padding: EdgeInsets.zero,
                      foregroundColor: scheme.onSurface,
                    ),
                    icon: const Icon(Icons.chevron_left_rounded, size: 28),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: OmniType.overline.copyWith(color: secondary),
                    ),
                  ),
                  if (onRename != null || onDelete != null)
                    PopupMenuButton<_TaskAction>(
                      tooltip: 'Tuỳ chọn công việc',
                      onSelected: (action) => switch (action) {
                        _TaskAction.rename => onRename?.call(),
                        _TaskAction.delete => onDelete?.call(),
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: _TaskAction.rename,
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined),
                              SizedBox(width: OmniSpacing.sm),
                              Text('Đổi tên việc'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: _TaskAction.delete,
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, color: danger),
                              const SizedBox(width: OmniSpacing.sm),
                              Text(
                                'Xoá công việc',
                                style: TextStyle(color: danger),
                              ),
                            ],
                          ),
                        ),
                      ],
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(
                          Icons.more_horiz_rounded,
                          color: scheme.onSurface,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 44),
                  const SizedBox(width: 2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hiệu ứng `rise`: mờ → rõ và trượt lên 10px, mỗi khối lệch 40ms. Tắt hẳn
/// khi người dùng giảm chuyển động.
class _Rise extends StatelessWidget {
  const _Rise({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!OmniMotion.enabled(context)) return child;
    final delay = 40 * index;
    final total = 400 + delay;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - t)),
          child: child,
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

  static const _gap = SizedBox(height: 14);

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
    final myName = ref.watch(sessionProvider.select((s) => s.user?.fullName));
    final myAvatar = ref.watch(
      sessionProvider.select((s) => s.user?.avatarUrl),
    );
    final hasDescription = task.description?.trim().isNotEmpty ?? false;

    // §3 là pull-based: ai rảnh TỰ NHẬN. Chỉ hiện khi mình CHƯA có tên trong
    // việc: đây là thao tác thêm mình vào, không phải bật/tắt. Bỏ mình ra là
    // một quyết định khác hẳn và vẫn là việc của quản đốc.
    final canClaim =
        !isAssigner && myUserId != null && !task.assigneeIds.contains(myUserId);

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
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  sliver: SliverList.list(
                    children: [
                      _Rise(index: 0, child: TaskTitleBlock(task: task)),
                      _gap,
                      _Rise(
                        index: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const DetailSectionTitle('ĐIỀU PHỐI'),
                            CoordinationCard(
                              task: task,
                              canEdit: isAssigner,
                              canClaim: canClaim,
                              onAssignees: isAssigner
                                  ? () => _assign(context, actions, task)
                                  : canClaim
                                  ? () => _claimSheet(
                                      context,
                                      actions,
                                      task,
                                      myUserId,
                                      myName ?? '',
                                      myAvatar,
                                    )
                                  : () {},
                              onDue: () => _editDueDate(context, actions, task),
                              onSection: () =>
                                  _moveSection(context, actions, task),
                              onPriority: () =>
                                  _editPriority(context, actions, task),
                            ),
                          ],
                        ),
                      ),
                      // Người giao việc thấy khối mô tả KỂ CẢ khi trống — nếu
                      // không thì không có chỗ nào để thêm mô tả lần đầu.
                      // Người thợ + trống thì ẩn cả khối.
                      if (isAssigner || hasDescription) ...[
                        _gap,
                        _Rise(
                          index: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const DetailSectionTitle('MÔ TẢ'),
                              TaskDescription(
                                text: task.description ?? '',
                                onEdit: isAssigner
                                    ? () => _editDescription(
                                        context,
                                        actions,
                                        task,
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Người giao việc thấy khối việc con KỂ CẢ khi trống — nút
                // "Thêm việc con" nằm BÊN TRONG khối này, nên gói nó theo
                // `hasSubtasks` là khoá mất chính đường tạo việc con đầu tiên.
                // Người thợ vẫn không thấy gì khi trống — họ tick chứ không
                // dựng danh sách.
                if (isAssigner || task.hasSubtasks)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: SubtaskCard(
                        task: task,
                        state: state,
                        controller: controller,
                        canTick: canComplete,
                        canEdit: isAssigner,
                      ),
                    ),
                  ),
                // Điểm kiểm tra (trái) và tệp đính kèm (phải) chung một lưới:
                // người kiểm nhìn ảnh rồi mới chấm, còn người bị trả việc về
                // xem lại chính tấm mình đã gửi.
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: ScoreAndFilesRow(
                      task: task,
                      taskId: taskId,
                      canRate: isAssigner,
                    ),
                  ),
                ),
                // Trao đổi đứng sau điểm: nó là lý do phía sau kết luận. Dải
                // "Đã xem" nằm ngay tiêu đề của nó — ai đã mở việc là câu hỏi
                // của quản đốc, không chen giữa người thợ và công đoạn.
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: CommentSection(
                      task: task,
                      taskId: taskId,
                      canWrite: canComplete,
                    ),
                  ),
                ),
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

  /// "Nhận việc này": sheet MỘT dòng, không phải bộ chọn người.
  ///
  /// Cố ý KHÔNG mở bộ chọn người: nó chỉ gửi đúng một id, id của chính người
  /// đang bấm. Bộ chọn lấy danh sách từ `GET /memberships`, đường cần
  /// `membership.members.read` — quyền mà vai `worker` cố ý không có, nên với
  /// đúng người cần tự nhận thì bộ chọn đó luôn rỗng. Gán NGƯỜI KHÁC vẫn là
  /// việc của quản đốc.
  Future<void> _claimSheet(
    BuildContext context,
    TaskDetailActions actions,
    Task task,
    String userId,
    String name,
    String? avatarUrl,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final claim = await showOmniSheet<bool>(
      context: context,
      builder: (ctx) {
        final text = Theme.of(ctx).textTheme;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Người làm',
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () => Navigator.of(ctx).pop(true),
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        OmniAvatar(
                          name: name.isEmpty ? '?' : name,
                          imageUrl: avatarUrl,
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('Nhận việc này', style: text.bodyLarge),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (claim != true) return;

    await _guard(messenger, () => actions.claim(task, userId));
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
    final tones = OmniTaskTones.of(context);
    // Khoá lấy từ `kPriorities` (high / med / low): đó đúng là giá trị
    // `actions.editPriority` vẫn gửi từ trước tới nay, không phải "medium".
    final keys = kPriorities.keys.toList();
    final picked = await showOptionSheet(
      context,
      title: 'Mức ưu tiên',
      selected: keys.indexOf(task.priority == 'medium' ? 'med' : task.priority),
      items: [
        for (final key in keys)
          OptionItem(
            label: kPriorities[key]!,
            round: true,
            color: switch (key) {
              'high' => tones.priorityHigh,
              'med' => tones.priorityNormal,
              _ => tones.priorityLow,
            },
          ),
      ],
    );
    if (picked == null) return;

    await _guard(messenger, () => actions.editPriority(task, keys[picked]));
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
    final tones = OmniTaskTones.of(context);
    // Danh sách nhóm việc đi kèm phản hồi chi tiết — không gọi module plans.
    final sections = task.planSections;
    final picked = await showOptionSheet(
      context,
      title: 'Chuyển nhóm việc',
      emptyMessage: 'Dự án này chưa khai báo nhóm việc nào.',
      selected: sections.indexWhere((s) => s.id == task.sectionId),
      items: [
        for (var i = 0; i < sections.length; i++)
          OptionItem(label: sections[i].name, color: tones.sectionColor(i)),
      ],
    );
    if (picked == null) return;

    await _guard(
      messenger,
      () => actions.moveSection(task, sections[picked].id),
    );
  }
}

/// Đổi tên việc — mở ô nhập rồi giao cho [TaskDetailActions].
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

/// Lỗi API hiện snackbar; mọi thứ khác nổ ra như một lỗi lập trình.
Future<void> _guard(
  ScaffoldMessengerState messenger,
  Future<void> Function() run,
) async {
  try {
    await run();
  } on AppException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  }
}
