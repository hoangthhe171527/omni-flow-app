import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../../tasks/application/tasks_providers.dart';
import '../../tasks/data/tasks_api.dart';
import '../../tasks/domain/task.dart';
import '../../tasks/tasks.dart';
import '../../tasks/tasks_module.dart';
import '../application/plans_providers.dart';

/// Việc đã lưu trữ của một kế hoạch (menu kế hoạch, nhóm 2).
///
/// `GET /tasks?project_id=&archived=archived`. "Khôi phục" gửi
/// `PUT /tasks/{id} {archived:false}`; dòng biến mất ngay khi server nhận,
/// việc quay về bảng.
class ArchivedTasksPage extends ConsumerStatefulWidget {
  const ArchivedTasksPage({
    super.key,
    required this.planId,
    required this.canRestore,
  });

  final String planId;

  /// Có `tasks.write` và không phải người xem của kế hoạch — đúng điều kiện
  /// `ProjectAccessService::assertCanEditTasks` phía API.
  final bool canRestore;

  @override
  ConsumerState<ArchivedTasksPage> createState() => _ArchivedTasksPageState();
}

class _ArchivedTasksPageState extends ConsumerState<ArchivedTasksPage> {
  /// Đã khôi phục trong phiên này: ẩn ngay, không chờ danh sách tải lại.
  final _restored = <String>{};

  /// Đang gửi: nút tắt để không gửi hai lần.
  final _busy = <String>{};

  Future<void> _restore(Task task) async {
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context);
    setState(() => _busy.add(task.id));
    try {
      await container.read(tasksApiProvider).setArchived(task.id, false);
      if (mounted) setState(() => _restored.add(task.id));
      container.invalidate(planTasksProvider(widget.planId));
      messenger.showSnackBar(
        SnackBar(content: Text('Đã khôi phục “${task.title}”.')),
      );
    } on AppException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _busy.remove(task.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final archived = ref.watch(archivedTasksProvider(widget.planId));
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Việc đã lưu trữ')),
      body: OmniAsyncView(
        value: archived,
        onRetry: () => ref.invalidate(archivedTasksProvider(widget.planId)),
        data: (all) {
          final tasks = [
            for (final t in all)
              if (!_restored.contains(t.id)) t,
          ];
          if (tasks.isEmpty) {
            return const OmniEmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'Chưa có việc nào được lưu trữ',
              message: 'Việc lưu trữ từ menu của việc sẽ nằm ở đây.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              OmniSpacing.lg,
              OmniSpacing.md,
              OmniSpacing.lg,
              OmniSpacing.bottomSafe,
            ),
            itemCount: tasks.length,
            separatorBuilder: (_, _) => const SizedBox(height: OmniSpacing.sm),
            itemBuilder: (context, i) {
              final task = tasks[i];

              return Column(
                key: ValueKey('archived-${task.id}'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TaskCard(
                    task: task,
                    showPlanName: false,
                    onTap: () => context.pushNamed(
                      TasksModule.detail,
                      pathParameters: {'id': task.id},
                    ),
                  ),
                  if (widget.canRestore)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Semantics(
                        button: true,
                        label: 'Khôi phục ${task.title}',
                        excludeSemantics: true,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(44, 44),
                            foregroundColor: scheme.primary,
                          ),
                          onPressed: _busy.contains(task.id)
                              ? null
                              : () => _restore(task),
                          icon: const Icon(Icons.unarchive_outlined),
                          label: const Text('Khôi phục'),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
