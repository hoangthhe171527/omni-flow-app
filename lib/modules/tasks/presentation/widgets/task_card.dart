import 'package:flutter/material.dart';

import '../../../../design/components/omni_avatar.dart';
import '../../../../design/tokens/tokens.dart';
import '../../domain/task.dart';
import 'due_chip.dart';

/// One task in the list.
///
/// Progress leads, because "how far along is this piano" is the only question a
/// worker opens the app to answer. The deadline is second, and it never relies
/// on colour alone — a red chip with no words is unreadable to somebody
/// colour-blind and meaningless in workshop light.
class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.onTap,
    this.showPlanName = true,
  });

  final Task task;
  final VoidCallback onTap;

  /// Hiện tên dự án phía trên tiêu đề.
  ///
  /// Tắt trên BẢNG của một dự án: tiêu đề màn đã là tên đó, và cả bảng
  /// chỉ thuộc một dự án — in lại trên từng thẻ là ba dòng giống nhau
  /// trên một màn hình. Bật ở "Việc của tôi", nơi việc đến từ nhiều
  /// dự án và dòng này chính là thứ phân biệt chúng.
  final bool showPlanName;

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
                if (showPlanName && task.projectName != null) ...[
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
                    // Flexible chứ không Expanded: chip giờ có nền, và
                    // Expanded kéo cái nền đó chạy hết bề ngang thẻ. Cũ thì
                    // không thấy vì chip chỉ là chữ với icon, không có nền.
                    Flexible(child: DueChip(task: task)),
                    const Spacer(),
                    // "Ai đang làm cây này" là câu hỏi thứ hai của quản đốc,
                    // ngay sau "nó đang ở công đoạn nào". Trước đây thẻ chỉ
                    // nói khi có TỪ HAI người trở lên — tức là im lặng đúng
                    // trường hợp thường gặp nhất.
                    _Assignees(
                      names: task.assigneeNames,
                      avatars: task.assigneeAvatars,
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
      parts.add('${task.doneCount} trên ${task.totalCount} việc con xong');
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${task.doneCount}/${task.totalCount} việc con',
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

/// Ai đang làm, dạng avatar chồng mép.
///
/// Avatar chứ không phải tên: ba người trên một thẻ vẫn đọc được mà không
/// chiếm một dòng riêng, và trên bảng thì mỗi dp chiều cao đều phải trả giá
/// bằng một thẻ ít đi. Tên đầy đủ nằm trong nhãn trợ năng và trong chi tiết.
class _Assignees extends StatelessWidget {
  const _Assignees({required this.names, this.avatars = const []});

  final List<String> names;

  /// Ảnh thật, thẳng hàng với [names]; null (hoặc thiếu) thì rơi về chữ tắt.
  final List<String?> avatars;

  /// Ba là đủ. Cái thứ tư trở đi thành một con số.
  static const _max = 3;

  static const double _size = 24;
  static const double _ring = 2;

  /// Bước giữa hai avatar: 24 − 6 chồng.
  static const double _step = 18;

  @override
  Widget build(BuildContext context) {
    if (names.isEmpty) {
      return Text(
        'Chưa gán',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final shown = names.take(_max).toList();
    final extra = names.length - shown.length;
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: names.join(', '),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            // Mỗi avatar 24dp, chồng lên nhau 6dp (một phần tư). Bản trước
            // 22dp chồng 8dp — 36% — và trong ảnh chụp thật "HN" bị "LU" che
            // mất nửa chữ. Một phần tư là mức các app việc trên thị trường
            // dùng: đủ để đọc là "một nhóm", vẫn thấy trọn chữ của từng người.
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
                        // Viền cùng màu mặt thẻ: nó cắt hai avatar chồng nhau
                        // ra thành hai hình, không phải một vệt.
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
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
