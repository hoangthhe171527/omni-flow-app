import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/error/crash_reporting.dart';
import '../../../core/utils/client_id.dart';
import '../../../design/components/components.dart';
import '../../../design/platform/omni_motion_scope.dart';
import '../../../design/tokens/tokens.dart';
import '../../notifications/application/notifications_providers.dart';
import '../../notifications/routes.dart';
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
    final scheme = Theme.of(context).colorScheme;
    final bucket = ref.watch(taskBucketProvider);
    final tasks = ref.watch(myTasksProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: OmniAppBar(
        backgroundColor: scheme.surface,
        title: 'Việc của tôi',
        titleSpacing: OmniSpacing.lg,
        toolbarHeight: 56,
        actions: [
          // Tìm cây đàn. Ở đây vì đây là màn hình người thợ đang mở sẵn, và
          // câu "cây SN 471302 ở đâu" hỏi giữa lúc làm chứ không hỏi lúc
          // ngồi duyệt menu.
          IconButton(
            onPressed: () => context.pushNamed(TaskRoutes.search),
            tooltip: 'Tìm cây đàn',
            icon: const Icon(Icons.search_rounded),
          ),
          // The bell lives here because this is the screen a worker is already
          // on. Making them go through "Thêm" to find out they were given
          // something is a step too many.
          _BellButton(
            unread: ref.watch(unreadNotificationCountProvider),
            onTap: () => context.pushNamed(NotificationRoutes.centre),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _BucketBar(
            selected: bucket,
            onSelect: (next) =>
                ref.read(taskBucketProvider.notifier).state = next,
          ),
        ),
      ),
      body: RefreshIndicator(
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
          data: (state) => ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(
              OmniSpacing.lg,
              OmniSpacing.lg,
              OmniSpacing.lg,
              OmniSpacing.bottomSafe,
            ),
            itemCount: state.items.length + (state.hasMore ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: OmniSpacing.md),
            itemBuilder: (context, index) {
              if (index >= state.items.length) {
                return const Padding(
                  padding: EdgeInsets.all(OmniSpacing.lg),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }

              final task = state.items[index];

              return _TickOnSwipe(
                task: task,
                onTick: (next) => _tick(task, next, done: true),
                child: TaskCard(
                  task: task,
                  onTap: () => context.pushNamed(
                    TasksModule.detail,
                    pathParameters: {'id': task.id},
                  ),
                ),
              );
            },
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
    required this.onTick,
    required this.child,
  });

  final Task task;
  final ValueChanged<Subtask> onTick;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final next = task.nextOpenSubtask;
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

/// The bell, with a count when there is one.
///
/// 48dp of target, and the count is announced rather than left as a red dot a
/// screen reader would skip.
class _BellButton extends StatelessWidget {
  const _BellButton({required this.unread, required this.onTap});

  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: unread > 0 ? 'Thông báo, $unread chưa đọc' : 'Thông báo',
      child: IconButton(
        onPressed: onTap,
        iconSize: 24,
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.notifications_none_rounded),
            if (unread > 0)
              Positioned(
                top: -4,
                right: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: OmniSpacing.xs,
                  ),
                  constraints: const BoxConstraints(minWidth: 16),
                  decoration: const BoxDecoration(
                    color: OmniColors.dangerSurface,
                    borderRadius: OmniRadius.pillAll,
                  ),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    textAlign: TextAlign.center,
                    style: OmniType.micro.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BucketBar extends StatelessWidget {
  const _BucketBar({required this.selected, required this.onSelect});

  final TaskBucket selected;
  final ValueChanged<TaskBucket> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: OmniSpacing.lg),
        itemCount: TaskBucket.forMyWork.length,
        separatorBuilder: (_, _) => const SizedBox(width: OmniSpacing.sm),
        itemBuilder: (context, index) {
          final bucket = TaskBucket.forMyWork[index];

          return Center(
            child: OmniFilterPill(
              label: bucket.label,
              selected: bucket == selected,
              onTap: () => onSelect(bucket),
            ),
          );
        },
      ),
    );
  }
}
