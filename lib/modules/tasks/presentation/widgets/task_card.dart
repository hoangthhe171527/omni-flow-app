import 'package:flutter/material.dart';

import '../../../../design/tokens/tokens.dart';
import '../../domain/task.dart';

/// One task in the list.
///
/// Progress leads, because "how far along is this piano" is the only question a
/// worker opens the app to answer. The deadline is second, and it never relies
/// on colour alone — a red chip with no words is unreadable to somebody
/// colour-blind and meaningless in workshop light.
class TaskCard extends StatelessWidget {
  const TaskCard({super.key, required this.task, required this.onTap});

  final Task task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: _semanticLabel,
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(OmniRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(OmniRadius.lg),
          child: Container(
            padding: const EdgeInsets.all(OmniSpacing.lg),
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(OmniRadius.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (task.projectName != null) ...[
                  Text(
                    task.projectName!,
                    style: text.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      letterSpacing: 0.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: OmniSpacing.xs),
                ],
                Text(
                  task.title,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (task.hasSubtasks) ...[
                  const SizedBox(height: OmniSpacing.md),
                  _Progress(task: task),
                ],
                const SizedBox(height: OmniSpacing.md),
                Row(
                  children: [
                    Expanded(child: _DueChip(task: task)),
                    if (task.assigneeNames.length > 1)
                      Text(
                        '+${task.assigneeNames.length - 1} người',
                        style: text.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Read aloud as one sentence rather than as four disconnected fragments.
  String get _semanticLabel {
    final parts = <String>[task.title];
    if (task.hasSubtasks) {
      parts.add('${task.doneCount} trên ${task.totalCount} công đoạn xong');
    }
    final overdue = task.daysOverdue;
    if (overdue != null) parts.add('quá hạn $overdue ngày');

    return parts.join(', ');
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final complete = task.doneCount == task.totalCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${task.doneCount}/${task.totalCount} công đoạn',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                // Tabular so the numbers do not jitter as stages complete.
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: OmniSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(OmniRadius.xs),
          child: LinearProgressIndicator(
            value: task.progress,
            minHeight: 6,
            backgroundColor: scheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(
              complete ? OmniColors.success : scheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}

/// The deadline, in words as well as colour.
class _DueChip extends StatelessWidget {
  const _DueChip({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme.labelMedium;
    final overdue = task.daysOverdue;

    final (label, colour) = switch (task) {
      _ when overdue != null => (
        'Quá hạn $overdue ngày',
        OmniColors.destructive,
      ),
      _ when task.isDueToday => ('Hạn hôm nay', OmniColors.warning),
      _ when task.dueDate != null => (
        'Hạn ${task.dueDate!.day}/${task.dueDate!.month}',
        scheme.onSurfaceVariant,
      ),
      _ => ('Chưa đặt hạn', scheme.onSurfaceVariant),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.schedule_rounded, size: OmniIconSize.sm, color: colour),
        const SizedBox(width: OmniSpacing.xs),
        Flexible(
          child: Text(
            label,
            style: text?.copyWith(color: colour, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
