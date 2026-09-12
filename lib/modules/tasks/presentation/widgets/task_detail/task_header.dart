import 'package:flutter/material.dart';

import '../../../../../design/tokens/tokens.dart';
import '../../../domain/task.dart';
import '../due_chip.dart';
import 'task_chip.dart';

/// Đầu màn chi tiết: dự án, tên việc, dải dữ kiện, và tiến độ.
class TaskHeader extends StatelessWidget {
  const TaskHeader({
    super.key,
    required this.task,
    this.showFacts = true,
    this.onEditTitle,
  });

  final Task task;

  /// Hiện dải chip hạn + người làm.
  ///
  /// Tắt với người giao việc: họ có cùng những dữ kiện đó ngay dưới, trong
  /// bảng điều phối, ở dạng sửa được. Hiện cả hai là in cùng một thông tin
  /// hai lần trên một màn hình bằng bàn tay.
  final bool showFacts;

  /// Đổi tên việc. Null = chỉ đọc.
  final VoidCallback? onEditTitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      color: scheme.surface,
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.lg,
        OmniSpacing.lg,
        OmniSpacing.lg,
        OmniSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (task.projectName != null) ...[
            Text(
              task.projectName!,
              style: OmniType.overline.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: OmniSpacing.xs),
          ],
          // Chạm vào chính cái tên để sửa nó. Một nút bút chì ở góc trên là
          // thêm một thứ phải tìm, trong khi cái tên thì đang ở ngay đó.
          if (onEditTitle == null)
            Text(task.title, style: OmniType.title)
          else
            InkWell(
              onTap: onEditTitle,
              borderRadius: OmniRadius.mdAll,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(task.title, style: OmniType.title)),
                  const SizedBox(width: OmniSpacing.sm),
                  Icon(
                    Icons.edit_outlined,
                    size: OmniIconSize.md,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          if (showFacts) ...[
            const SizedBox(height: OmniSpacing.lg),
            // Deadline and people are chips, not sentences: at a glance from a
            // workbench, three short facts beat one long line.
            Wrap(
              spacing: OmniSpacing.sm,
              runSpacing: OmniSpacing.sm,
              children: [
                DueChip(task: task),
                for (final name in task.assigneeNames)
                  TaskChip(icon: Icons.person_outline_rounded, label: name),
              ],
            ),
          ],
          if (task.hasSubtasks) ...[
            const SizedBox(height: OmniSpacing.lg),
            _Progress(task: task),
          ],
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Đã xong ${task.doneCount}/${task.totalCount} việc con',
          style: OmniType.caption.copyWith(
            color: scheme.onSurfaceVariant,
            fontFeatures: OmniType.tabular,
          ),
        ),
        const SizedBox(height: OmniSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(OmniRadius.xs),
          child: LinearProgressIndicator(
            value: task.progress,
            minHeight: 8,
            backgroundColor: scheme.surfaceContainerHighest,
            // Xong hay chưa đọc qua CON SỐ bên trên và qua độ dài thanh,
            // không qua sắc màu. Đổi sang xanh lá khi đầy là đưa vào một màu
            // thương hiệu thứ hai — cùng lỗi đã sửa ở ô tick công đoạn, và
            // người mù màu lục-đỏ không thấy khác biệt nào cả.
            valueColor: AlwaysStoppedAnimation(scheme.primary),
          ),
        ),
      ],
    );
  }
}
