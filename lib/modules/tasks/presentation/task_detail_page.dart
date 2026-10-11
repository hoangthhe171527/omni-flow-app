import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../design/components/components.dart';
import '../../../design/platform/omni_motion_scope.dart';
import '../../../design/tokens/tokens.dart';
import '../../../security/session/session_controller.dart';
import '../../plans/routes.dart';
import '../application/task_controller.dart';
import '../application/task_detail_actions.dart';
import '../application/tasks_providers.dart';
import '../data/tasks_api.dart';
import '../domain/task.dart';
import 'widgets/activity_log.dart';
import 'widgets/assign_task_sheet.dart';
import 'widgets/comment_section.dart';
import 'widgets/edit_sheets.dart';
import 'widgets/labels_sheet.dart';
import 'widgets/task_detail/breadcrumb.dart';
import 'widgets/task_detail/description_card.dart';
import 'widgets/task_detail/detail_header.dart';
import 'widgets/task_detail/label_strip.dart';
import 'widgets/task_detail/option_sheet.dart';
import 'widgets/task_detail/section_title.dart';
import 'widgets/task_detail/subtask_card.dart';
import 'widgets/task_detail/task_action_bar.dart';
import 'widgets/task_detail/task_attachments.dart';
import 'widgets/task_detail/task_info_card.dart';
import 'widgets/task_detail/title_row.dart';

/// Chi tiết một việc (`TaskDetail.dc.html`).
///
/// Nửa trên (Task 8 của Việc mới): header kính có tên việc hiện khi cuộn,
/// dải nhãn, tiêu đề có ô tích, breadcrumb kế hoạch › nhóm, thẻ thông tin
/// (người làm, thời gian, đánh giá + thích, ưu tiên) và thẻ mô tả. Nửa dưới
/// (việc con, tệp, trao đổi, nhật ký) còn là các khối cũ tới Task 9.
///
/// Từng khối là một widget riêng dưới `widgets/task_detail/`; file này chỉ
/// XẾP chúng và nối sheet với controller / [TaskDetailActions].
class TaskDetailPage extends ConsumerStatefulWidget {
  const TaskDetailPage({super.key, required this.taskId});

  final String taskId;

  @override
  ConsumerState<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends ConsumerState<TaskDetailPage> {
  final _scroll = ScrollController();
  final _titleShown = ValueNotifier(false);
  final _titleKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    _titleShown.dispose();
    super.dispose();
  }

  /// Tên việc lên header khi dòng tiêu đề trong thân đã khuất dưới header.
  void _onScroll() {
    // Vị trí cuộn đổi TRƯỚC khi khung mới được xếp: đo sau khung đó, nếu
    // không thì đọc vị trí cũ của dòng tiêu đề.
    if (_measureQueued) return;
    _measureQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureQueued = false;
      _measure();
    });
  }

  bool _measureQueued = false;

  void _measure() {
    final box = _titleKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !mounted) return;
    final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
    final headerBottom =
        MediaQuery.paddingOf(context).top + DetailHeader.height;
    _titleShown.value = bottom <= headerBottom;
  }

  @override
  Widget build(BuildContext context) {
    final taskId = widget.taskId;
    final detail = ref.watch(taskDetailProvider(taskId));
    final access = ref.watch(taskAccessProvider);
    final loadedTask = detail.valueOrNull?.visible;

    return Scaffold(
      appBar: DetailHeader(
        title: loadedTask?.title ?? '',
        titleShown: _titleShown,
        // Đổi tên và xoá đều là việc của người giao việc. Menu chia nhóm của
        // bản mẫu là Task 9.
        menu: access.isAssigner && loadedTask != null
            ? _TaskMenuButton(
                onRename: () => _editTitle(
                  context,
                  TaskDetailActions(
                    ref.read(taskDetailProvider(taskId).notifier),
                  ),
                  loadedTask,
                ),
                onDelete: () => _deleteTask(context, loadedTask),
              )
            : null,
      ),
      body: OmniAsyncView(
        value: detail,
        onRetry: () => ref.invalidate(taskDetailProvider(taskId)),
        data: (state) => _Loaded(
          taskId: taskId,
          state: state,
          scroll: _scroll,
          titleKey: _titleKey,
        ),
      ),
    );
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

/// ⋯ "Tuỳ chọn công việc" (44). Tạm giữ menu bật xuống cũ (Đổi tên, Xoá)
/// tới khi sheet menu việc của Task 9 thay nó.
class _TaskMenuButton extends StatelessWidget {
  const _TaskMenuButton({required this.onRename, required this.onDelete});

  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final danger = OmniColors.dangerTextOf(context);

    return PopupMenuButton<_TaskAction>(
      tooltip: 'Tuỳ chọn công việc',
      onSelected: (action) => switch (action) {
        _TaskAction.rename => onRename(),
        _TaskAction.delete => onDelete(),
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
              Text('Xoá công việc', style: TextStyle(color: danger)),
            ],
          ),
        ),
      ],
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(
          Icons.more_horiz_rounded,
          size: OmniIconSize.lg,
          color: scheme.onSurface,
        ),
      ),
    );
  }
}

/// Hiệu ứng `rise` của khối trên: mờ → rõ, trượt lên 8px, 350ms
/// cubic(.2,.8,.2,1). Tắt hẳn khi người dùng giảm chuyển động.
class _Rise extends StatelessWidget {
  const _Rise({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!OmniMotion.enabled(context)) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: OmniCurves.standard,
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - t)),
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
    required this.scroll,
    required this.titleKey,
  });

  final String taskId;
  final TaskDetailState state;
  final ScrollController scroll;
  final GlobalKey titleKey;

  static const _gap = SizedBox(height: 10);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = state.visible;
    final access = ref.watch(taskAccessProvider);
    final isAssigner = access.isAssigner;
    final canWrite = access.canUpdate || access.canComplete;
    final controller = ref.read(taskDetailProvider(taskId).notifier);
    final actions = TaskDetailActions(controller);
    // `select`: màn này chỉ cần id người đang cầm máy.
    final myUserId = ref.watch(sessionProvider.select((s) => s.user?.id));
    final myName = ref.watch(sessionProvider.select((s) => s.user?.fullName));
    final myAvatar = ref.watch(
      sessionProvider.select((s) => s.user?.avatarUrl),
    );
    final catalog = ref.watch(taskLabelsProvider).valueOrNull ?? const [];

    // §3 là pull-based: ai rảnh TỰ NHẬN. Chỉ khi mình CHƯA có tên trong việc.
    final canClaim =
        !isAssigner &&
        canWrite &&
        myUserId != null &&
        !task.assigneeIds.contains(myUserId);

    final description = task.description?.trim() ?? '';
    final projectId = task.projectId;
    final canOpenBoard =
        access.canRead &&
        projectId != null &&
        GoRouter.maybeOf(context) != null;
    final sectionName =
        task.sectionName ?? (isAssigner ? 'Chưa xếp nhóm việc' : null);
    final normalPriority = task.priority == 'med' || task.priority == 'medium';
    final onAddLabel = canWrite && access.canReadLabels
        ? () => _labels(context, controller, task)
        : null;

    final top = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (task.labels.isNotEmpty || onAddLabel != null) ...[
          LabelStrip(codes: task.labels, catalog: catalog, onAdd: onAddLabel),
          _gap,
        ],
        KeyedSubtree(
          key: titleKey,
          child: TaskTitleRow(
            task: task,
            taskId: taskId,
            canComplete: access.canComplete,
          ),
        ),
        if (task.projectName != null || sectionName != null) ...[
          _gap,
          TaskBreadcrumb(
            planName: task.projectName,
            sectionName: sectionName,
            onPlan: canOpenBoard
                ? () => context.pushNamed(
                    PlanRoutes.board,
                    pathParameters: {'id': projectId},
                  )
                : null,
            onSection: isAssigner
                ? () => _moveSection(context, actions, task)
                : null,
          ),
        ],
        _gap,
        TaskInfoCard(
          task: task,
          likedByMe: myUserId != null && task.isLikedBy(myUserId),
          onAddAssignee: isAssigner
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
              : null,
          onTime: isAssigner
              ? () => _editTime(context, controller, actions, task)
              : null,
          onRate: isAssigner
              ? (n) => _rate(context, controller, task, n)
              : null,
          onLike: canWrite && myUserId != null
              ? () => _like(context, controller, myUserId)
              : null,
          showPriority: isAssigner || !normalPriority,
          onPriority: isAssigner
              ? () => _editPriority(context, actions, task)
              : null,
        ),
        _gap,
        DescriptionCard(
          text: description,
          onCopy: description.isEmpty
              ? null
              : () => _copyDescription(context, description),
          onEdit: isAssigner
              ? () => _editDescription(context, actions, task)
              : null,
        ),
      ],
    );

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: controller.refresh,
            child: CustomScrollView(
              controller: scroll,
              // Luôn kéo được, kể cả khi nội dung ngắn hơn màn — nếu không thì
              // kéo-để-tải-lại không hoạt động đúng ở việc ít công đoạn.
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  sliver: SliverToBoxAdapter(child: _Rise(child: top)),
                ),
                // Người giao việc thấy khối việc con KỂ CẢ khi trống — nút
                // "Thêm việc con" nằm BÊN TRONG khối này.
                if (isAssigner || task.hasSubtasks)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: SubtaskCard(
                        task: task,
                        state: state,
                        controller: controller,
                        canTick: access.canComplete,
                        canEdit: isAssigner,
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DetailSectionTitle(
                          'TỆP ĐÍNH KÈM (${task.attachments.length})',
                        ),
                        TaskAttachments(attachments: task.attachments),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: CommentSection(
                      task: task,
                      taskId: taskId,
                      canWrite: access.canComplete,
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: ActivityLog(task: task)),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          ),
        ),
        TaskActionBar(canAttach: access.canAttach, taskId: taskId),
      ],
    );
  }

  // Mỗi hàm dưới đây chỉ MỞ SHEET rồi giao phần "có gì để ghi không" cho
  // [TaskDetailActions] / controller. Messenger lấy TRƯỚC khi await: sau khi
  // sheet đóng, `context` có thể đã rời khỏi cây widget.

  /// Sheet Nhãn màu ở chế độ bật/tắt; mỗi lần bật/tắt gửi cả danh sách mới
  /// (`labels[]`) tính từ bản đang hiện — lạc quan, lỗi thì hoàn tác và báo.
  Future<void> _labels(
    BuildContext context,
    TaskController controller,
    Task task,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context);

    await showLabelsSheet(
      context,
      selected: task.labels.toSet(),
      onToggle: (code) {
        final current =
            container
                .read(taskDetailProvider(taskId))
                .valueOrNull
                ?.task
                .labels ??
            task.labels;
        final next = current.contains(code)
            ? [
                for (final c in current)
                  if (c != code) c,
              ]
            : [...current, code];
        unawaited(
          controller
              .setLabels(next)
              .then<void>(
                (_) {},
                onError: (Object _) => messenger.showSnackBar(
                  const SnackBar(content: Text('Không lưu được nhãn.')),
                ),
              ),
        );
      },
    );
  }

  Future<void> _like(
    BuildContext context,
    TaskController controller,
    String myUserId,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await controller.toggleLike(myUserId);
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text('Không thích được.')),
      );
    }
  }

  /// Chấm điểm QC (chỉ người giao việc). Chạm lại đúng sao đang chọn là XOÁ
  /// điểm: chấm nhầm phải gỡ được, và không có nút nào khác để làm việc đó.
  Future<void> _rate(
    BuildContext context,
    TaskController controller,
    Task task,
    int star,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final next = task.rating == star ? 0 : star;
    unawaited(HapticFeedback.selectionClick());
    try {
      await controller.setRating(next);
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text('Chưa lưu được. Thử lại khi có mạng.')),
      );
    }
  }

  Future<void> _copyDescription(BuildContext context, String text) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: text));
    messenger.showSnackBar(const SnackBar(content: Text('Đã chép mô tả.')));
  }

  /// Ngày bắt đầu và hạn trong một sheet. Gửi `start_date` khi đổi ngày, rồi
  /// đi đường đổi hạn hiện có (`due_date`, không bao giờ `due_at`).
  Future<void> _editTime(
    BuildContext context,
    TaskController controller,
    TaskDetailActions actions,
    Task task,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final chosen = await showTaskTimeSheet(
      context,
      start: task.startDate,
      due: task.dueDate,
    );
    if (chosen == null) return;

    await _guard(messenger, () async {
      if (!_sameDay(chosen.start, task.startDate)) {
        await controller.setStartDate(chosen.start);
      }
      await actions.editDueDate(task, chosen.due);
    });
  }

  static bool _sameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a == b;

    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Giao việc cho ai, ngay tại chỗ.
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
  /// Bộ chọn lấy danh sách từ `GET /memberships`, đường cần
  /// `membership.members.read` — quyền mà vai `worker` cố ý không có. Gán
  /// NGƯỜI KHÁC vẫn là việc của quản đốc.
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

  Future<void> _editPriority(
    BuildContext context,
    TaskDetailActions actions,
    Task task,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final tones = OmniTaskTones.of(context);
    // Khoá lấy từ `kPriorities` (high / med / low): đúng giá trị
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
      emptyMessage: 'Kế hoạch này chưa khai báo nhóm việc nào.',
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
