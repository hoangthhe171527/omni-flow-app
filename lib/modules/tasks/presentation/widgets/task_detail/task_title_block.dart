import 'package:flutter/material.dart';

import '../../../../../design/tokens/tokens.dart';
import '../../../domain/task.dart';

/// Tên việc + tiến độ việc con (`TaskDetail.dc.html`).
///
/// [task] phải là bản HIỂN THỊ (`TaskDetailState.visible`) để số đã xong gồm cả
/// tick đang chờ trong outbox — người thợ vừa tick mà số không nhích là đọc
/// như app không ăn.
class TaskTitleBlock extends StatelessWidget {
  const TaskTitleBlock({super.key, required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final secondary = OmniColors.byBrightness(
      context,
      OmniColors.mutedForeground,
      scheme.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          task.title,
          style: text.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            height: 1.3,
            color: scheme.onSurface,
          ),
        ),
        if (task.hasSubtasks) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 6,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ColoredBox(color: OmniColors.trackOf(context)),
                        ),
                        Positioned.fill(
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: task.progress.clamp(0.0, 1.0),
                            child: ColoredBox(color: scheme.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Đã xong ${task.doneCount}/${task.totalCount} việc con',
                style: OmniType.micro.copyWith(
                  fontWeight: FontWeight.w600,
                  color: secondary,
                  fontFeatures: OmniType.tabular,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
