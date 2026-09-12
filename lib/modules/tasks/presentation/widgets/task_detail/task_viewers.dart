import 'package:flutter/material.dart';

import '../../../../../core/utils/formatters.dart';
import '../../../../../design/components/components.dart';
import '../../../../../design/tokens/tokens.dart';
import '../../../domain/task.dart';
import 'task_chip.dart';

/// "Thành viên đã xem" — who has opened this task.
///
/// Placed last, below the work itself: it answers the manager's question
/// ("did they get it") and never the worker's, so it must not sit between a
/// worker and the stage they came to tick.
class TaskViewers extends StatelessWidget {
  const TaskViewers({super.key, required this.viewers});

  final List<TaskViewer> viewers;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: OmniSpacing.sm),
      color: scheme.surface,
      padding: const EdgeInsets.all(OmniSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.visibility_outlined,
                size: OmniIconSize.sm,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: OmniSpacing.xs),
              Text(
                'Thành viên đã xem',
                style: OmniType.overline.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: OmniSpacing.md),
          Wrap(
            spacing: OmniSpacing.sm,
            runSpacing: OmniSpacing.sm,
            children: [
              for (final viewer in viewers)
                Tooltip(
                  message: viewer.viewedAt == null
                      ? viewer.label
                      : '${viewer.label} · ${Formatters.relative(viewer.viewedAt)}',
                  child: TaskChip(
                    // Mặt người thay dấu tích: "đã xem" đã nằm ở tiêu đề khối,
                    // còn AI xem thì mặt người nói nhanh hơn tên.
                    leading: OmniAvatar(
                      name: viewer.label,
                      imageUrl: viewer.avatar,
                      size: OmniIconSize.md,
                    ),
                    label: viewer.label,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
