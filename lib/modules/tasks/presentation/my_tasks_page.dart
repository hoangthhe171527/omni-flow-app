import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../application/tasks_providers.dart';
import '../data/tasks_api.dart';
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
      appBar: AppBar(
        backgroundColor: scheme.surface,
        title: const Text('Việc của tôi'),
        titleSpacing: OmniSpacing.lg,
        toolbarHeight: 56,
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

              return TaskCard(
                task: task,
                onTap: () => context.pushNamed(
                  TasksModule.detail,
                  pathParameters: {'id': task.id},
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// An empty bucket is usually good news, and should read that way.
  String _emptyTitle(TaskBucket bucket) => switch (bucket) {
    TaskBucket.today => 'Hôm nay không có việc nào',
    TaskBucket.overdue => 'Không có việc quá hạn',
    TaskBucket.upcoming => 'Chưa có việc sắp tới',
    TaskBucket.all => 'Chưa có việc nào được giao',
  };

  String _emptyMessage(TaskBucket bucket) => switch (bucket) {
    TaskBucket.overdue => 'Bạn đang theo kịp tiến độ.',
    TaskBucket.all => 'Việc được giao cho bạn sẽ hiện ở đây.',
    _ => 'Kéo xuống để làm mới.',
  };
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
        itemCount: TaskBucket.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: OmniSpacing.sm),
        itemBuilder: (context, index) {
          final bucket = TaskBucket.values[index];

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
