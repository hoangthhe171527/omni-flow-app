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
  const TaskViewers({super.key, required this.viewers, this.compact = false});

  final List<TaskViewer> viewers;

  /// Dải "Đã xem" + avatar 18 chồng nhau (lùi −6), đặt bên phải tiêu đề
  /// "TRAO ĐỔI" (`TaskDetail.dc.html`). Không compact = khối đầy đủ cũ.
  final bool compact;

  /// Số avatar tối đa trong dải: nhiều hơn là dải tràn tiêu đề.
  static const _maxFaces = 5;

  Widget _strip(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shown = viewers.take(_maxFaces).toList();
    const face = 18.0;
    const step = face - 6;

    return Tooltip(
      message: 'Đã xem: ${viewers.map((v) => v.label).join(', ')}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Đã xem',
            style: OmniType.micro.copyWith(
              color: OmniColors.byBrightness(
                context,
                OmniColors.mutedForeground,
                scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: face + step * (shown.length - 1),
            height: face,
            child: Stack(
              children: [
                for (var i = 0; i < shown.length; i++)
                  Positioned(
                    left: step * i,
                    child: DecoratedBox(
                      position: DecorationPosition.foreground,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.surface),
                      ),
                      child: OmniAvatar(
                        name: shown[i].label,
                        imageUrl: shown[i].avatar,
                        size: face,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return viewers.isEmpty ? const SizedBox.shrink() : _strip(context);
    }
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
