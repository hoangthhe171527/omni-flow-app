import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../../tasks/application/tasks_providers.dart';
import '../../tasks/data/tasks_api.dart';
import '../../tasks/domain/task.dart';
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
    HapticFeedback.selectionClick();
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
      appBar: OmniAppBar(
        title: 'Việc đã lưu trữ',
        fallbackBack: () => context.go('/plans/${widget.planId}'),
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: () async =>
            ref.invalidate(archivedTasksProvider(widget.planId)),
        child: OmniAsyncView(
          value: archived,
          onRetry: () => ref.invalidate(archivedTasksProvider(widget.planId)),
          data: (result) {
            final tasks = [
              for (final t in result.tasks)
                if (!_restored.contains(t.id)) t,
            ];
            if (tasks.isEmpty) {
              return const OmniEmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'Chưa có việc nào được lưu trữ',
                message: 'Việc lưu trữ từ menu của việc sẽ nằm ở đây.',
              );
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                OmniSpacing.lg,
                OmniSpacing.md,
                OmniSpacing.lg,
                OmniSpacing.bottomSafe,
              ),
              children: [
                // Dừng ở trần mà server còn nữa: nói ra ở ĐẦU danh sách, không
                // lặng lẽ dừng ở việc thứ 500.
                if (result.truncated) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                    child: Text(
                      'Chỉ hiện $kMaxArchivedTasks việc lưu trữ đầu tiên. '
                      'Tìm việc cũ hơn trên web.',
                      style: OmniType.caption.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
                OmniGroupSection(
                  dividerIndent: 14,
                  children: [
                    for (final task in tasks)
                      if (widget.canRestore)
                        Stack(
                          key: ValueKey('archived-${task.id}'),
                          alignment: Alignment.centerRight,
                          children: [
                            OmniGroupRow(
                              title: task.title,
                              subtitle: (task.sectionName ?? '').trim().isEmpty
                                  ? null
                                  : task.sectionName,
                              chevron: false,
                              onTap: () => context.pushNamed(
                                TasksModule.detail,
                                pathParameters: {'id': task.id},
                              ),
                              trailing: const SizedBox(width: 92, height: 32),
                            ),
                            Positioned(
                              right: 14,
                              child: _RestoreGlassPill(
                                taskTitle: task.title,
                                busy: _busy.contains(task.id),
                                onPressed: () => _restore(task),
                              ),
                            ),
                          ],
                        )
                      else
                        OmniGroupRow(
                          key: ValueKey('archived-${task.id}'),
                          title: task.title,
                          subtitle: (task.sectionName ?? '').trim().isEmpty
                              ? null
                              : task.sectionName,
                          chevron: true,
                          onTap: () => context.pushNamed(
                            TasksModule.detail,
                            pathParameters: {'id': task.id},
                          ),
                        ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RestoreGlassPill extends StatelessWidget {
  const _RestoreGlassPill({
    required this.taskTitle,
    required this.busy,
    required this.onPressed,
  });

  final String taskTitle;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      container: true,
      button: true,
      label: 'Khôi phục $taskTitle',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        child: Center(
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: busy ? null : onPressed,
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: OmniGlass.buttonDecoration(context),
                child: Text(
                  'Khôi phục',
                  style: OmniType.caption.copyWith(
                    color: busy ? scheme.onSurfaceVariant : scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
