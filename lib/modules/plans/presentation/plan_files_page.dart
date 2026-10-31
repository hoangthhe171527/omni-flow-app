import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../../tasks/data/tasks_api.dart';
import '../../tasks/domain/task.dart';
import '../../tasks/tasks.dart';
import '../application/plans_providers.dart';
import '../data/plans_api.dart';

/// Tệp của một kế hoạch (menu kế hoạch, nhóm 2).
///
/// API không có endpoint riêng: gộp `attachments[]` mà mỗi dòng việc trên
/// bảng đã mang sẵn (`TaskPresenter::listRow`). Lưới 3 cột, tên việc dưới
/// mỗi tệp; chạm mở tệp như ở chi tiết việc; bấm giữ để xoá khi có quyền.
class PlanFilesPage extends ConsumerWidget {
  const PlanFilesPage({
    super.key,
    required this.planId,
    required this.canDelete,
  });

  final String planId;

  /// Như "Khôi phục": `tasks.write` và không phải người xem của kế hoạch.
  final bool canDelete;

  static const _gap = 8.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(planTasksProvider(planId));
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Tệp đính kèm')),
      body: OmniAsyncView(
        value: tasks,
        onRetry: () => ref.invalidate(planTasksProvider(planId)),
        data: (loaded) {
          final files = [
            for (final task in loaded.tasks)
              for (final file in task.attachments) (task: task, file: file),
          ];
          if (files.isEmpty) {
            return const OmniEmptyState(
              icon: Icons.attach_file_rounded,
              title: 'Chưa có tệp nào',
              message: 'Tệp đính kèm trên các việc của kế hoạch sẽ hiện ở đây.',
            );
          }

          return LayoutBuilder(
            builder: (context, box) {
              final tile = ((box.maxWidth - 2 * OmniSpacing.lg - 2 * _gap) / 3)
                  .clamp(44.0, 160.0);

              return ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(
                  OmniSpacing.lg,
                  OmniSpacing.md,
                  OmniSpacing.lg,
                  OmniSpacing.bottomSafe,
                ),
                children: [
                  if (loaded.truncated)
                    Padding(
                      padding: const EdgeInsets.only(bottom: OmniSpacing.sm),
                      child: Text(
                        'Chỉ gồm tệp của $kMaxTasksOnBoard việc đầu trên bảng.',
                        style: OmniType.caption.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  Wrap(
                    spacing: _gap,
                    runSpacing: OmniSpacing.md,
                    children: [
                      for (final entry in files)
                        SizedBox(
                          key: ValueKey('plan-file-${entry.file.id}'),
                          width: tile,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AttachmentThumb(
                                attachment: entry.file,
                                size: tile,
                                onLongPress: canDelete
                                    ? () => _fileOptions(
                                        context,
                                        entry.task,
                                        entry.file,
                                      )
                                    : null,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                entry.task.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: OmniType.micro.copyWith(
                                  fontWeight: FontWeight.w400,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _fileOptions(
    BuildContext context,
    Task task,
    TaskAttachment file,
  ) async {
    final danger = OmniTaskTones.of(context).highPriority.foreground;
    final remove = await showOmniViecSheet<bool>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const OmniSheetHandle(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OmniType.section,
                ),
              ),
              InkWell(
                onTap: () => Navigator.of(sheet).pop(true),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                        size: OmniIconSize.lg,
                        color: danger,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Xoá tệp',
                        style: OmniType.body.copyWith(
                          fontWeight: FontWeight.w500,
                          color: danger,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (remove != true || !context.mounted) return;

    final confirmed = await showOmniConfirm(
      context: context,
      title: 'Xoá tệp “${file.name}”?',
      message: 'Tệp sẽ bị gỡ khỏi việc “${task.title}”.',
      confirmLabel: 'Xoá tệp',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context);
    try {
      await container.read(tasksApiProvider).deleteAttachment(task.id, file.id);
      container.invalidate(planTasksProvider(planId));
      messenger.showSnackBar(const SnackBar(content: Text('Đã xoá tệp.')));
    } on AppException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}
