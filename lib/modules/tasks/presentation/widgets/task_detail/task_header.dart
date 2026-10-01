import 'package:flutter/material.dart';

import '../../../../../design/components/omni_tabs.dart';
import '../../../../../design/tokens/tokens.dart';
import '../../../domain/task.dart';
import '../due_chip.dart';
import 'task_chip.dart';

/// Đầu màn chi tiết: dự án, tên việc, dải dữ kiện, và tiến độ.
/// 20/28 SemiBold — tiêu đề của màn chi tiết (đề xuất "Chuẩn hoá phong cách").
final _titleStyle = OmniType.title.copyWith(
  fontWeight: FontWeight.w600,
  letterSpacing: -0.22,
);

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
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
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
            Text(
              task.title,
              style: _titleStyle.copyWith(color: scheme.onSurface),
            )
          else
            InkWell(
              onTap: onEditTitle,
              borderRadius: OmniRadius.mdAll,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      style: _titleStyle.copyWith(color: scheme.onSurface),
                    ),
                  ),
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

/// Khối tiến độ (`MTaskDetail.dc.html`): nền xám bo 14, "Đã xong n/m việc
/// con" đậm bên trái, phần trăm bên phải, thanh quỹ đạo sáng dày 8.
class _Progress extends StatelessWidget {
  const _Progress({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final percent = (task.progress * 100).round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: dark ? scheme.surfaceContainerHighest : OmniColors.background,
        borderRadius: OmniRadius.lgAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Đã xong ${task.doneCount}/${task.totalCount} việc con',
                  style: OmniType.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                    fontFeatures: OmniType.tabular,
                  ),
                ),
              ),
              Text(
                '$percent%',
                style: OmniType.body.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: OmniType.tabular,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Xong hay chưa đọc qua CON SỐ và độ dài thanh, không qua sắc màu.
          OmniProgressBar(value: task.progress),
        ],
      ),
    );
  }
}
