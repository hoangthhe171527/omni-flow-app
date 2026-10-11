import 'package:flutter/material.dart';

import '../../../../../core/utils/formatters.dart';
import '../../../../../design/components/omni_avatar.dart';
import '../../../../../design/tokens/tokens.dart';
import '../../../domain/task.dart';
import '../due_chip.dart';
import '../edit_sheets.dart';

/// Khối ĐIỀU PHỐI (`TaskDetail.dc.html`): thẻ bo 8, bốn dòng Người làm / Hạn /
/// Nhóm việc / Ưu tiên.
///
/// Dòng sửa được (người giao việc) có mũi tên và mở sheet; người KHÔNG giao
/// việc thấy cùng dữ kiện nhưng dòng không phản hồi chạm và không mũi tên —
/// mỗi nút thừa là một chỗ bấm nhầm khi tay đang bẩn. Ngoại lệ duy nhất là
/// "Người làm" khi [canClaim]: người thợ chưa có tên chạm để tự nhận.
class CoordinationCard extends StatelessWidget {
  const CoordinationCard({
    super.key,
    required this.task,
    required this.canEdit,
    required this.canClaim,
    required this.onAssignees,
    required this.onDue,
    required this.onSection,
    required this.onPriority,
  });

  final Task task;

  /// Người giao việc: cả bốn dòng sửa được.
  final bool canEdit;

  /// Người thợ chưa có tên mình: dòng "Người làm" mở sheet "Nhận việc này".
  final bool canClaim;

  final VoidCallback onAssignees;
  final VoidCallback onDue;
  final VoidCallback onSection;
  final VoidCallback onPriority;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _Line(
            label: 'Người làm',
            onTap: canEdit || canClaim ? onAssignees : null,
            child: _Assignees(task: task),
          ),
          _Line(
            label: 'Hạn',
            divider: true,
            onTap: canEdit ? onDue : null,
            child: _Due(task: task),
          ),
          _Line(
            label: 'Nhóm việc',
            divider: true,
            onTap: canEdit ? onSection : null,
            child: _Value(
              task.sectionName ?? 'Chưa xếp nhóm việc',
              muted: task.sectionName == null,
            ),
          ),
          _Line(
            label: 'Ưu tiên',
            divider: true,
            onTap: canEdit ? onPriority : null,
            child: _Priority(priority: task.priority),
          ),
        ],
      ),
    );
  }
}

/// Một dòng cao ≥ 44: nhãn trái rộng 84, giá trị phải, mũi tên nếu bấm được.
class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.child,
    required this.onTap,
    this.divider = false,
  });

  final String label;
  final Widget child;
  final VoidCallback? onTap;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final secondary = OmniColors.byBrightness(
      context,
      OmniColors.mutedForeground,
      scheme.onSurfaceVariant,
    );

    final row = Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: divider
            ? Border(top: BorderSide(color: OmniColors.trackOf(context)))
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: OmniType.caption.copyWith(color: secondary),
            ),
          ),
          Expanded(
            child: Align(alignment: Alignment.centerRight, child: child),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: OmniTaskTones.of(context).chevron,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return row;

    return InkWell(onTap: onTap, child: row);
  }
}

TextStyle _valueStyle(
  BuildContext context, {
  Color? color,
  bool muted = false,
}) {
  final scheme = Theme.of(context).colorScheme;

  return OmniType.caption.copyWith(
    fontWeight: muted ? FontWeight.w400 : FontWeight.w600,
    color: color ?? (muted ? scheme.onSurfaceVariant : scheme.onSurface),
  );
}

class _Value extends StatelessWidget {
  const _Value(this.text, {this.color, this.muted = false});

  final String text;
  final Color? color;
  final bool muted;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.right,
    style: _valueStyle(context, color: color, muted: muted),
  );
}

/// Avatar 22 chồng (lùi −8, viền 2 màu thẻ) + tên nối ", ".
class _Assignees extends StatelessWidget {
  const _Assignees({required this.task});

  final Task task;

  static const _max = 3;
  static const double _size = 22;
  static const double _ring = 2;
  static const double _step = _size + 2 * _ring - 8;

  @override
  Widget build(BuildContext context) {
    final names = task.assigneeNames;
    if (names.isEmpty) return const _Value('Chưa giao ai', muted: true);

    final scheme = Theme.of(context).colorScheme;
    final shown = names.take(_max).toList();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: _size + 2 * _ring + (shown.length - 1) * _step,
          height: _size + 2 * _ring,
          child: Stack(
            children: [
              for (var i = 0; i < shown.length; i++)
                Positioned(
                  left: i * _step,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.surface, width: _ring),
                    ),
                    child: OmniAvatar(
                      name: shown[i],
                      imageUrl: i < task.assigneeAvatars.length
                          ? task.assigneeAvatars[i]
                          : null,
                      size: _size,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Flexible(child: _Value(names.join(', '))),
      ],
    );
  }
}

/// `dd/MM` + " · hôm nay" / " · quá hạn n ngày", chữ màu theo tông hạn.
class _Due extends StatelessWidget {
  const _Due({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final due = task.dueDate;
    if (due == null) return const _Value('Chưa đặt hạn', muted: true);

    final d = dueToneOf(task);
    final tones = OmniTaskTones.of(context);
    final date = Formatters.dayMonth(due);

    return switch (d.tone) {
      DueTone.today => _Value('$date · hôm nay', color: tones.today.foreground),
      DueTone.late => _Value(
        '$date · ${d.label.toLowerCase()}',
        color: tones.late.foreground,
      ),
      _ => _Value(date),
    };
  }
}

/// Chấm 7 màu theo mức + nhãn.
class _Priority extends StatelessWidget {
  const _Priority({required this.priority});

  final String priority;

  @override
  Widget build(BuildContext context) {
    final tones = OmniTaskTones.of(context);
    final dot = switch (priority) {
      'high' => tones.priorityHigh,
      'med' || 'medium' => tones.priorityNormal,
      _ => tones.priorityLow,
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(child: _Value(priorityLabel(priority))),
      ],
    );
  }
}
