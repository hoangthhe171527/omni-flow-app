import 'package:flutter/material.dart';

import '../../../../../core/utils/formatters.dart';
import '../../../../../design/components/components.dart';
import '../../../../../design/tokens/tokens.dart';
import '../../../domain/task.dart';

/// Dòng "Đã xem việc này" của thẻ Nhật ký (`TaskDetail.dc.html`): chữ 13 màu
/// phụ, bên phải là avatar 24 chồng nhau (lùi −6, viền 2 màu nền thẻ).
///
/// Trả lời câu hỏi của quản lý ("họ đã nhận chưa"); chạm giữ (tooltip) đọc
/// đủ tên và lúc xem.
class TaskViewers extends StatelessWidget {
  const TaskViewers({super.key, required this.viewers});

  final List<TaskViewer> viewers;

  /// Số avatar tối đa: nhiều hơn thì "+n".
  static const _maxFaces = 5;
  static const _face = 24.0;
  static const _step = _face - 6;

  @override
  Widget build(BuildContext context) {
    if (viewers.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final secondary = OmniColors.byBrightness(
      context,
      OmniColors.mutedForeground,
      scheme.onSurfaceVariant,
    );
    final shown = viewers.take(_maxFaces).toList();
    final more = viewers.length - shown.length;

    return Tooltip(
      message: viewers
          .map(
            (v) => v.viewedAt == null
                ? v.label
                : '${v.label} · ${Formatters.relative(v.viewedAt)}',
          )
          .join('\n'),
      child: Semantics(
        label: 'Đã xem: ${viewers.map((v) => v.label).join(', ')}',
        excludeSemantics: true,
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Đã xem việc này',
                style: OmniType.caption.copyWith(color: secondary),
              ),
            ),
            SizedBox(
              width: _face + _step * (shown.length - 1),
              height: _face,
              child: Stack(
                children: [
                  for (var i = 0; i < shown.length; i++)
                    Positioned(
                      left: _step * i,
                      child: DecoratedBox(
                        position: DecorationPosition.foreground,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: scheme.surface, width: 2),
                        ),
                        child: OmniAvatar(
                          name: shown[i].label,
                          imageUrl: shown[i].avatar,
                          size: _face,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (more > 0) ...[
              const SizedBox(width: 4),
              Text('+$more', style: OmniType.micro.copyWith(color: secondary)),
            ],
          ],
        ),
      ),
    );
  }
}
