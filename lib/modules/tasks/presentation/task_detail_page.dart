import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../design/components/components.dart';
import '../../../design/platform/omni_motion_scope.dart';
import '../../../design/tokens/tokens.dart';
import '../../../security/session/session_controller.dart';
import '../../customers/routes.dart';
import '../../plans/routes.dart';
import '../application/task_controller.dart';
import '../application/task_detail_actions.dart';
import '../application/tasks_providers.dart';
import '../data/tasks_api.dart';
import '../domain/custom_field.dart';
import '../domain/task.dart';
import '../domain/task_permissions.dart';
import 'widgets/activity_log.dart';
import 'widgets/assign_task_sheet.dart';
import 'widgets/comment_section.dart';
import 'widgets/edit_sheets.dart';
import 'widgets/labels_sheet.dart';
import 'widgets/task_detail/breadcrumb.dart';
import 'widgets/task_detail/comment_bar.dart';
import 'widgets/task_detail/custom_fields_card.dart';
import 'widgets/task_detail/description_card.dart';
import 'widgets/task_detail/detail_header.dart';
import 'widgets/task_detail/files_card.dart';
import 'widgets/task_detail/label_strip.dart';
import 'widgets/task_detail/move_task_sheet.dart';
import 'widgets/task_detail/option_sheet.dart';
import 'widgets/task_detail/subtasks_card.dart';
import 'widgets/task_detail/task_info_card.dart';
import 'widgets/task_detail/task_menu_sheet.dart';
import 'widgets/task_detail/title_row.dart';

/// Chi tiết một việc (`TaskDetail.dc.html`).
///
/// Nửa trên (Task 8 của Việc mới): header kính có tên việc hiện khi cuộn,
/// dải nhãn, tiêu đề có ô tích, breadcrumb kế hoạch › nhóm, thẻ thông tin
/// (người làm, thời gian, đánh giá + thích, ưu tiên) và thẻ mô tả. Nửa dưới
/// (Task 9): trường tuỳ chỉnh, việc con, tệp, bình luận, nhật ký; ô bình luận
/// cố định ở đáy; ⋯ mở menu việc chia nhóm.
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
    final canWrite = access.canUpdate || access.canComplete;
    final groups = loadedTask == null
        ? const <List<TaskMenuAction>>[]
        : taskMenuGroups(
            canLabels: canWrite && access.canReadLabels,
            isAssigner: access.isAssigner,
            archived: loadedTask.archived,
          );

    return Scaffold(
      appBar: DetailHeader(
        title: loadedTask?.title ?? '',
        titleShown: _titleShown,
        // Không mục nào hiện thì không có ⋯.
        menu: groups.isEmpty
            ? null
            : IconButton(
                tooltip: 'Tuỳ chọn công việc',
                onPressed: () => _openMenu(context, loadedTask!, groups),
                style: IconButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  maximumSize: const Size(44, 44),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                icon: Icon(
                  Icons.more_horiz_rounded,
                  size: OmniIconSize.lg,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
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

  /// Menu việc (`TaskMenu.dc.html`): mở sheet rồi chạy mục đã chọn.
  Future<void> _openMenu(
    BuildContext context,
    Task task,
    List<List<TaskMenuAction>> groups,
  ) async {
    final controller = ref.read(taskDetailProvider(widget.taskId).notifier);
    final action = await showTaskMenuSheet(context, groups: groups);
    if (action == null || !context.mounted) return;

    switch (action) {
      case TaskMenuAction.labels:
        await _openLabels(context, widget.taskId, controller, task);
      case TaskMenuAction.rename:
        await _editTitle(context, TaskDetailActions(controller), task);
      case TaskMenuAction.move:
        await _move(context, controller, task);
      case TaskMenuAction.archive:
        await _archive(context, controller, archived: true);
      case TaskMenuAction.unarchive:
        await _archive(context, controller, archived: false);
      case TaskMenuAction.delete:
        await _deleteTask(context, task);
    }
  }

  /// Chuyển sang nhóm / kế hoạch khác. Xong thì báo bảng (cũ và mới) tải lại
  /// qua tín hiệu realtime chung.
  Future<void> _move(
    BuildContext context,
    TaskController controller,
    Task task,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context);
    final target = await showMoveTaskSheet(
      context,
      currentProjectId: task.projectId,
      currentSectionId: task.sectionId,
    );
    if (target == null) return;
    if (target.projectId == task.projectId &&
        target.sectionId == task.sectionId) {
      return;
    }

    try {
      await controller.moveTask(
        projectId: target.projectId,
        sectionId: target.sectionId,
      );
      container.read(taskRealtimeSignalProvider.notifier).bump();
      messenger.showSnackBar(
        const SnackBar(content: Text('Đã chuyển công việc.')),
      );
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// Lưu trữ thì rời màn (việc biến khỏi bảng); bỏ lưu trữ thì ở lại.
  Future<void> _archive(
    BuildContext context,
    TaskController controller, {
    required bool archived,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final container = ProviderScope.containerOf(context);
    try {
      await controller.setArchived(archived);
      container.read(taskRealtimeSignalProvider.notifier).bump();
      if (archived) unawaited(navigator.maybePop());
      messenger.showSnackBar(
        SnackBar(content: Text(archived ? 'Đã lưu trữ.' : 'Đã bỏ lưu trữ.')),
      );
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
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
        ? () => _openLabels(context, taskId, controller, task)
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

    final canOpenCustomer =
        ref.watch(accessProvider).canAny(TaskPermissions.openCustomer) &&
        GoRouter.maybeOf(context) != null;
    final customerId = task.customerId;

    final bottom = [
      CustomFieldsCard(
        task: task,
        onEdit: canWrite ? (def) => _editField(context, controller, def) : null,
        onOpenCustomer: canOpenCustomer && customerId != null
            ? () => context.pushNamed(
                CustomerRoutes.detail,
                pathParameters: {'id': customerId},
              )
            : null,
      ),
      // Người giao việc thấy thẻ việc con KỂ CẢ khi trống — nút + nằm BÊN
      // TRONG thẻ.
      if (isAssigner || task.hasSubtasks) ...[
        _gap,
        SubtasksCard(
          task: task,
          state: state,
          controller: controller,
          canTick: access.canComplete,
          canEdit: isAssigner,
        ),
      ],
      _gap,
      FilesCard(task: task, canAttach: access.canAttach),
      _gap,
      CommentSection(
        task: task,
        taskId: taskId,
        myUserId: myUserId,
        canWrite: access.canComplete,
        canModerate: isAssigner,
      ),
      if (task.activity.isNotEmpty || task.viewers.isNotEmpty) ...[
        _gap,
        ActivityCard(task: task),
      ],
    ];

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
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: bottom,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Ô bình luận cố định đáy; bàn phím đẩy nó lên (Scaffold co thân).
        if (access.canComplete) CommentBar(task: task, taskId: taskId),
      ],
    );
  }

  // Mỗi hàm dưới đây chỉ MỞ SHEET rồi giao phần "có gì để ghi không" cho
  // [TaskDetailActions] / controller. Messenger lấy TRƯỚC khi await: sau khi
  // sheet đóng, `context` có thể đã rời khỏi cây widget.

  /// Sửa một trường tuỳ chỉnh theo kiểu: chữ / số qua ô nhập, ngày qua lịch,
  /// lựa chọn qua bảng chọn. Gửi map ĐÃ GỘP (`setCustomField`).
  Future<void> _editField(
    BuildContext context,
    TaskController controller,
    CustomFieldDef def,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final task = state.visible;
    final raw = task.customFields[def.id];
    final current = raw?.toString() ?? '';

    Object? value;
    switch (def.type) {
      case CustomFieldType.text:
      case CustomFieldType.number:
        final number = def.type == CustomFieldType.number;
        final typed = await showTextEditSheet(
          context: context,
          title: def.name,
          initial: number ? (displayCustomValue(def, raw) ?? '') : current,
          hint: 'Nhập ${def.name.toLowerCase()}',
          allowEmpty: true,
          keyboardType: number
              ? const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                )
              : null,
        );
        if (typed == null) return;
        if (typed.isEmpty) {
          value = null;
        } else if (number) {
          final parsed = num.tryParse(typed.replaceAll(',', '.'));
          if (parsed == null) {
            messenger.showSnackBar(
              const SnackBar(content: Text('Nhập một số.')),
            );
            return;
          }
          value = parsed;
        } else {
          value = typed;
        }
      case CustomFieldType.date:
        final now = DateTime.now();
        final initial = DateUtilsX.parse(current) ?? now;
        // Khoảng lịch luôn chứa ngày đang có: ngày đặt từ web có thể nằm xa.
        final first = DateTime(now.year - 5);
        final last = DateTime(now.year + 5, 12, 31);
        final picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: initial.isBefore(first) ? initial : first,
          lastDate: initial.isAfter(last) ? initial : last,
        );
        if (picked == null) return;
        value =
            '${picked.year.toString().padLeft(4, '0')}-'
            '${picked.month.toString().padLeft(2, '0')}-'
            '${picked.day.toString().padLeft(2, '0')}';
      case CustomFieldType.select:
        final primary = Theme.of(context).colorScheme.primary;
        final picked = await showOptionSheet(
          context,
          title: def.name,
          emptyMessage: 'Trường này chưa có lựa chọn nào.',
          selected: def.options.indexOf(current),
          items: [
            for (final o in def.options)
              OptionItem(label: o, color: primary, round: true),
          ],
        );
        if (picked == null) return;
        value = def.options[picked];
    }
    if (value == raw || (value == null && current.isEmpty)) return;

    await _guard(messenger, () => controller.setCustomField(def.id, value));
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

/// Sheet Nhãn màu ở chế độ bật/tắt; mỗi lần bật/tắt gửi cả danh sách mới
/// (`labels[]`) tính từ bản đang hiện — lạc quan, lỗi thì hoàn tác và báo.
Future<void> _openLabels(
  BuildContext context,
  String taskId,
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
          container.read(taskDetailProvider(taskId)).valueOrNull?.task.labels ??
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
