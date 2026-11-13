import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/error/crash_reporting.dart';
import '../../../core/utils/client_id.dart';
import '../../../design/components/components.dart';
import '../../../design/platform/omni_motion_scope.dart';
import '../../../design/tokens/tokens.dart';
import '../../../security/session/session_controller.dart';
import '../application/tasks_providers.dart';
import '../data/tasks_api.dart';
import '../domain/task.dart';
import '../routes.dart';
import '../tasks_module.dart';
import 'widgets/task_card.dart';

/// The work assigned to whoever is signed in.
///
/// Four buckets in the order a worker actually asks the question: what is due
/// now, what am I late on, what is coming, and everything. This mirrors the
/// tool the workshop already uses, so nobody has to be retrained.
class MyTasksPage extends ConsumerStatefulWidget {
  const MyTasksPage({super.key});

  @override
  ConsumerState<MyTasksPage> createState() => _MyTasksPageState();
}

class _MyTasksPageState extends ConsumerState<MyTasksPage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 400) {
      ref.read(myTasksProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bucket = ref.watch(taskBucketProvider);
    final tasks = ref.watch(myTasksProvider);
    final currentUserId = ref.watch(sessionProvider.select((s) => s.user?.id));
    final canManageAll = ref.watch(
      taskAccessProvider.select((a) => a.isAssigner),
    );

    return Scaffold(
      // Thanh trên kiểu B (viomni-apple-uiux.html): tiêu đề lớn, tìm cây đàn
      // và chuông là viên kính rời; bốn nhóm việc là bộ chọn đoạn kính.
      // Danh sách chạy dưới thanh và nhoè dần.
      extendBodyBehindAppBar: true,
      appBar: OmniTopBar(
        semanticsTitle: 'Việc của tôi',
        actions: [
          // Tìm cây đàn. Ở đây vì đây là màn hình người thợ đang mở sẵn, và
          // câu "cây SN 471302 ở đâu" hỏi giữa lúc làm chứ không hỏi lúc
          // ngồi duyệt menu.
          OmniTopBarAction(
            icon: Icons.search_rounded,
            tooltip: 'Tìm cây đàn',
            onPressed: () => context.pushNamed(TaskRoutes.search),
          ),
        ],
        searchBottom: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(OmniTabStrip.height),
          child: _BucketBar(
            selected: bucket,
            counts: {
              TaskBucket.overdue: ?ref
                  .watch(taskOverdueCountProvider)
                  .valueOrNull,
              if (tasks.valueOrNull case final state? when !state.hasMore)
                bucket: state.items.length,
            },
            onSelect: (next) =>
                ref.read(taskBucketProvider.notifier).state = next,
          ),
        ),
      ),
      body: OmniTopBarOverlap.wrap(
        child: Builder(
          builder: (context) => RefreshIndicator.adaptive(
            edgeOffset: OmniTopBarOverlap.of(context),
            onRefresh: () => ref.read(myTasksProvider.notifier).refresh(),
            child: OmniAsyncView(
              value: tasks,
              onRetry: () => ref.invalidate(myTasksProvider),
              isEmpty: (state) => state.items.isEmpty,
              empty: OmniEmptyState(
                icon: Icons.checklist_rounded,
                title: _emptyTitle(bucket),
                message: _emptyMessage(bucket),
              ),
              data: (state) {
                final groups = _groupByPlan(state.items);
                final scheme = Theme.of(context).colorScheme;
                return ListView.separated(
                  controller: _scrollController,
                  padding: EdgeInsets.fromLTRB(
                    OmniSpacing.lg,
                    OmniSpacing.lg + OmniTopBarOverlap.of(context),
                    OmniSpacing.lg,
                    OmniSpacing.bottomSafe,
                  ),
                  itemCount: groups.length + (state.hasMore ? 1 : 0),
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: OmniGroupSection.gap),
                  itemBuilder: (context, index) {
                    if (index >= groups.length) {
                      return const Padding(
                        padding: EdgeInsets.all(OmniSpacing.lg),
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator.adaptive(
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      );
                    }

                    final group = groups[index];
                    return OmniGroupSection(
                      title: group.title,
                      trailingTitle: Text(
                        '${group.tasks.length} việc',
                        style: OmniType.caption.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontFeatures: OmniType.tabular,
                        ),
                      ),
                      dividerIndent: 14,
                      children: [
                        for (final task in group.tasks)
                          _TickOnSwipe(
                            task: task,
                            currentUserId: currentUserId,
                            canManage: canManageAll,
                            onTick: (next) => _tick(task, next, done: true),
                            child: TaskCard(
                              task: task,
                              showPlanName: false,
                              onTap: () => context.pushNamed(
                                TasksModule.detail,
                                pathParameters: {'id': task.id},
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Tick (hoặc bỏ tick) một công đoạn thẳng từ danh sách.
  ///
  /// Lạc quan: thẻ đổi NGAY, bản của server thay vào khi về tới. Không đi qua
  /// hàng chờ ngoại tuyến của màn chi tiết — một cú vuốt là thao tác "nhanh",
  /// và nếu mạng hỏng thì nói ngay tại chỗ rồi trả thẻ về như cũ, thay vì để
  /// một tick nằm chờ mà thẻ đã báo xong. Ai cần tick chắc chắn khi mất sóng
  /// thì mở thẻ ra: đường đó vẫn ghi xuống đĩa trước khi gọi mạng.
  Future<void> _tick(Task task, Subtask next, {required bool done}) async {
    final messenger = ScaffoldMessenger.of(context);
    final list = ref.read(myTasksProvider.notifier);
    final api = ref.read(tasksApiProvider);

    list.patch(
      task.copyWith(
        subtasks: [
          for (final s in task.subtasks)
            if (s.id == next.id) s.copyWith(done: done) else s,
        ],
      ),
    );

    try {
      final updated = await api.setSubtaskDone(
        task.id,
        next.id,
        done: done,
        clientRequestId: newClientId(),
      );
      if (!mounted) return;
      list.patch(updated);

      // Vuốt nhầm là chuyện của một buổi sáng. Không có đường lui thì người
      // ta không dám vuốt nữa, và tính năng chết dù vẫn chạy.
      if (done) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text('Đã xong: ${next.title}'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'HOÀN TÁC',
              onPressed: () => _tick(updated, next, done: false),
            ),
          ),
        );
      }
    } on AppException catch (error) {
      if (!mounted) return;
      list.patch(task);
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } on Object catch (error, stackTrace) {
      // Lỗi lạ là một bug, nhưng thẻ vẫn phải về như cũ và người thợ vẫn
      // phải được báo. Một thẻ lặng lẽ nhảy về 1/3 đọc như "đã lưu rồi mà".
      if (!mounted) return;
      list.patch(task);
      messenger.showSnackBar(
        const SnackBar(content: Text('Không lưu được. Vui lòng thử lại.')),
      );
      CrashReporting.recordHandled(
        error,
        stackTrace,
        reason: 'tasks: swipe-ticking a subtask from the list',
      );
    }
  }

  /// An empty bucket is usually good news, and should read that way.
  String _emptyTitle(TaskBucket bucket) => switch (bucket) {
    TaskBucket.today => 'Hôm nay không có việc nào',
    TaskBucket.overdue => 'Không có việc quá hạn',
    TaskBucket.upcoming => 'Chưa có việc sắp tới',
    // `open` không có nút trên màn này (xem `TaskBucket.forMyWork`), nhưng
    // switch phải phủ hết: bỏ sót một case là một lỗi biên dịch hôm nay và
    // một dòng chữ trống nếu ai đó thêm `default`.
    TaskBucket.open => 'Không còn việc nào đang mở',
    TaskBucket.all => 'Chưa có việc nào được giao',
  };

  String _emptyMessage(TaskBucket bucket) => switch (bucket) {
    TaskBucket.overdue => 'Bạn đang theo kịp tiến độ.',
    TaskBucket.all => 'Việc được giao cho bạn sẽ hiện ở đây.',
    _ => 'Kéo xuống để làm mới.',
  };

  List<({String title, List<Task> tasks})> _groupByPlan(List<Task> items) {
    final map = <String, List<Task>>{};
    for (final task in items) {
      final raw = task.projectName?.trim();
      final key = (raw != null && raw.isNotEmpty) ? raw : 'Việc chung';
      map.putIfAbsent(key, () => []).add(task);
    }
    return [
      for (final entry in map.entries) (title: entry.key, tasks: entry.value),
    ];
  }
}

/// Vuốt phải để tick công đoạn ĐANG MỞ đầu tiên của cây đàn.
///
/// Thao tác lặp nhiều nhất trong ngày của người thợ là "xong một công đoạn":
/// mở thẻ, cuộn tới việc con, tick, quay lại — bốn bước cho một cái tick, tay
/// còn dính dầu. Ở đây một thẻ là một cây đàn chứ không phải một việc, nên
/// vuốt không "xong cây đàn" mà xong công đoạn kế tiếp, và nhãn trên dải nói
/// rõ tên công đoạn đó TRƯỚC khi buông tay.
///
/// Thẻ không bao giờ bị gạt đi: `confirmDismiss` luôn trả false để thẻ trượt
/// về chỗ cũ, vì cây đàn vẫn còn đó — chỉ tiến độ trên thẻ đổi.
class _TickOnSwipe extends StatelessWidget {
  const _TickOnSwipe({
    required this.task,
    required this.currentUserId,
    required this.canManage,
    required this.onTick,
    required this.child,
  });

  final Task task;
  final String? currentUserId;
  final bool canManage;
  final ValueChanged<Subtask> onTick;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final next = task.nextOpenSubtaskFor(
      currentUserId: currentUserId,
      canManage: canManage,
    );
    // Không còn gì để tick thì không phải là thứ vuốt được — không dải, không
    // đàn hồi, để người dùng không tưởng mình vuốt hụt.
    if (next == null) return child;

    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Dismissible(
      key: ValueKey('tick:${task.id}'),
      direction: DismissDirection.startToEnd,
      // Trả false NGAY, không chờ mạng: thẻ trượt về chỗ, tiến độ trên thẻ đã
      // đổi lạc quan, và kết quả thật (hoặc lỗi) tới qua thanh thông báo.
      confirmDismiss: (_) {
        HapticFeedback.mediumImpact();
        onTick(next);
        return Future.value(false);
      },
      movementDuration: OmniMotion.of(context).base,
      background: Container(
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(OmniRadius.lg),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: OmniSpacing.lg),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, color: scheme.onPrimary),
            const SizedBox(width: OmniSpacing.sm),
            Flexible(
              child: Text(
                'Xong: ${next.title}',
                style: text.labelLarge?.copyWith(color: scheme.onPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      child: child,
    );
  }
}

/// Bộ chọn bốn nhóm việc — cùng MỘT kiểu tab với cả app: bộ chọn đoạn kính
/// ([OmniTabStrip]). "Quá hạn" mang số đếm trong chip đỏ để
/// luôn đọc ra là chỗ cần xử lý; các nhóm khác số xám.
///
/// Số đếm chỉ hiện khi đã BIẾT chắc mà không phải gọi thêm API: số quá hạn đã
/// được đếm sẵn cho huy hiệu tab, và nhóm đang mở biết số của chính nó khi đã
/// tải hết trang. Nhóm khác không có số — đoán số là tệ hơn không có số.
class _BucketBar extends StatelessWidget {
  const _BucketBar({
    required this.selected,
    required this.onSelect,
    required this.counts,
  });

  final TaskBucket selected;
  final ValueChanged<TaskBucket> onSelect;
  final Map<TaskBucket, int> counts;

  @override
  Widget build(BuildContext context) {
    const buckets = TaskBucket.forMyWork;

    return OmniTabStrip(
      // Thanh trên đã chừa lề hai bên.
      padding: EdgeInsets.zero,
      selected: buckets.indexOf(selected),
      onSelected: (i) => onSelect(buckets[i]),
      tabs: [
        for (final bucket in buckets)
          OmniTab(
            label: bucket.label,
            count: counts[bucket],
            alert: bucket == TaskBucket.overdue,
          ),
      ],
    );
  }
}
