import 'package:flutter/material.dart';

import '../../../../design/components/omni_avatar.dart';
import '../../../../design/components/omni_tabs.dart';
import '../../../../design/components/omni_task_chip.dart';
import '../../../../design/platform/omni_motion_scope.dart';
import '../../../../design/tokens/tokens.dart';
import '../../../tasks/domain/task.dart';
import '../../../tasks/tasks.dart';

/// Thẻ việc trên bảng dự án (`Plan.dc.html` `.tc`): bo 8 viền, đệm 10/12.
///
/// Hàng 1 tiêu đề (+ công đoạn kế tiếp nếu còn), hàng 2 chip hạn / "Ưu tiên
/// cao" và avatar chồng, hàng 3 thanh tiến độ việc con + số đếm. Hàng 3 ẩn khi
/// việc không có việc con và không có đính kèm / trao đổi / điểm.
///
/// `TaskCard` vẫn là thẻ của "Việc của tôi", Workload và tìm kiếm.
class BoardTaskCard extends StatelessWidget {
  const BoardTaskCard({
    super.key,
    required this.task,
    required this.onTap,
    this.delay = Duration.zero,
  });

  final Task task;
  final VoidCallback onTap;

  /// Độ trễ của hiệu ứng `rise`, để các thẻ trong một cột hiện lần lượt.
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondary = dark
        ? scheme.onSurfaceVariant
        : OmniColors.secondaryForeground;
    final next = task.nextOpenSubtask;
    final counts = <Widget>[
      if (task.attachmentCount > 0)
        _Count(
          icon: Icons.attachment_outlined,
          value: task.attachmentCount,
          what: 'ảnh đính kèm',
        ),
      if (task.commentCount > 0)
        _Count(
          icon: Icons.forum_outlined,
          value: task.commentCount,
          what: 'trao đổi',
        ),
      if (task.rating > 0)
        _Count(
          icon: Icons.star_rounded,
          value: task.rating,
          what: 'điểm kiểm tra',
        ),
    ];

    final card = Semantics(
      button: true,
      label: _semanticLabel,
      child: Material(
        color: scheme.surface,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: const BorderRadius.all(Radius.circular(8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: OmniType.body.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: scheme.onSurface,
                  ),
                ),
                // Công đoạn đang mở kế tiếp và ai cầm: câu quản đốc hỏi khi
                // lướt bảng. Giữ từ thẻ cũ, không có trong mock.
                if (next != null) ...[
                  const SizedBox(height: OmniSpacing.xs),
                  Row(
                    children: [
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: OmniSpacing.xs),
                      Expanded(
                        child: Text(
                          next.assigneeName == null
                              ? next.title
                              : '${next.title} · ${next.assigneeName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: OmniType.micro.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          DueChip(task: task),
                          if (task.priority == 'high')
                            const OmniTaskChip.high('Ưu tiên cao'),
                        ],
                      ),
                    ),
                    const SizedBox(width: OmniSpacing.sm),
                    _Assignees(
                      names: task.assigneeNames,
                      avatars: task.assigneeAvatars,
                    ),
                  ],
                ),
                if (task.hasSubtasks || counts.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (task.hasSubtasks) ...[
                        Expanded(child: OmniProgressBar(value: task.progress)),
                        const SizedBox(width: OmniSpacing.sm),
                        Text(
                          '${task.doneCount}/${task.totalCount}',
                          style: OmniType.micro.copyWith(
                            fontWeight: FontWeight.w600,
                            color: secondary,
                            fontFeatures: OmniType.tabular,
                          ),
                        ),
                      ] else
                        const Spacer(),
                      for (final w in counts) ...[
                        const SizedBox(width: OmniSpacing.sm),
                        w,
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return _Rise(delay: delay, child: card);
  }

  String get _semanticLabel {
    final parts = <String>[task.title];
    if (task.hasSubtasks) {
      parts.add('${task.doneCount} trên ${task.totalCount} việc con xong');
    }
    final due = dueToneOf(task);
    if (due.tone == DueTone.late) parts.add(due.label.toLowerCase());

    return parts.join(', ');
  }
}

/// Hiệu ứng `rise`: mờ → rõ và trượt lên 10px trong 400ms (+ [delay]).
/// Tắt hẳn khi người dùng giảm chuyển động.
class _Rise extends StatelessWidget {
  const _Rise({required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!OmniMotion.enabled(context)) return child;
    final total = 400 + delay.inMilliseconds;
    final start = delay.inMilliseconds / total;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - t)),
          child: child,
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.icon, required this.value, required this.what});

  final IconData icon;
  final int value;
  final String what;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: '$value $what',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: OmniIconSize.sm, color: scheme.onSurfaceVariant),
          const SizedBox(width: OmniSpacing.xxs),
          Text(
            '$value',
            style: OmniType.micro.copyWith(
              color: scheme.onSurfaceVariant,
              fontFeatures: OmniType.tabular,
            ),
          ),
        ],
      ),
    );
  }
}

/// Avatar 20 chồng (viền 2 màu `surface`, lùi 6), tối đa 3 + "+n";
/// không ai làm thì "Chưa gán" mờ.
class _Assignees extends StatelessWidget {
  const _Assignees({required this.names, this.avatars = const []});

  final List<String> names;
  final List<String?> avatars;

  static const _max = 3;
  static const double _size = 20;
  static const double _ring = 2;
  static const double _overlap = 6;
  static const double _step = _size + 2 * _ring - _overlap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (names.isEmpty) {
      return Text(
        'Chưa gán',
        style: OmniType.micro.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
      );
    }

    final shown = names.take(_max).toList();
    final extra = names.length - shown.length;

    return Semantics(
      label: names.join(', '),
      child: Row(
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
                        imageUrl: i < avatars.length ? avatars[i] : null,
                        size: _size,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (extra > 0) ...[
            const SizedBox(width: OmniSpacing.xs),
            Text(
              '+$extra',
              style: OmniType.micro.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
