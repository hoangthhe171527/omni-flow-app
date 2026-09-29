import 'package:flutter/material.dart';

import '../../../../design/components/omni_avatar.dart';
import '../../../../design/components/omni_status_chip.dart';
import '../../../../design/tokens/tokens.dart';
import '../../domain/task.dart';
import 'due_chip.dart';
import 'edit_sheets.dart';

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
    this.highlight = '',
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

  /// Đoạn chữ cần tô trong tiêu đề — màn tìm cây đàn tô đúng số máy vừa gõ
  /// (nền vàng nhạt như thiết kế). Rỗng thì không tô.
  final String highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Ba con số, chỉ khi > 0: "0 ảnh · 0 trao đổi" trên mọi thẻ là tiếng ồn.
    // Chúng đứng CÙNG DÒNG với "2/4 việc con" (như Trello đặt badge cạnh tiến
    // độ) để hàng cuối chỉ còn hạn + ưu tiên + avatar; ảnh chụp cho thấy dồn
    // cả vào hàng cuối là gãy thành hai dòng. Việc không có công đoạn thì
    // không có dòng tiến độ, con số mới rơi xuống hàng cuối.
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

    return Semantics(
      button: true,
      label: _semanticLabel,
      child: Material(
        color: scheme.surface,
        borderRadius: OmniRadius.xlAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: OmniRadius.xlAll,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: OmniRadius.xlAll,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showPlanName && task.projectName != null) ...[
                  Text(
                    task.projectName!,
                    style: OmniType.micro.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: OmniSpacing.xs),
                ],
                Text.rich(
                  _highlighted(task.title, highlight, context),
                  style: OmniType.listTitle.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 22 / 16,
                    color: scheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                // Công đoạn ĐANG MỞ đầu tiên và ai làm — câu quản đốc hỏi khi
                // lướt bảng ("cây này tới đâu rồi, ai đang cầm"). Bản trước thẻ
                // chỉ có tên đàn + thanh tiến độ, và người dùng nói "không
                // thấy thông tin gì".
                if (task.nextOpenSubtask case final Subtask next) ...[
                  const SizedBox(height: OmniSpacing.xs),
                  Text(
                    next.assigneeName == null
                        ? '→ ${next.title}'
                        : '→ ${next.title} · ${next.assigneeName}',
                    style: OmniType.body.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (task.hasSubtasks) ...[
                  const SizedBox(height: OmniSpacing.sm),
                  _Progress(task: task, trailing: counts),
                ],
                const SizedBox(height: OmniSpacing.md),
                Row(
                  children: [
                    // Wrap chứ không Row: hạn + ưu tiên + ba con số có thể
                    // không đủ chỗ trên một dòng 380dp, và thẻ tràn đọc như
                    // lỗi. Chip ôm lấy chữ của nó (không Expanded từng chip).
                    Expanded(
                      child: Wrap(
                        spacing: OmniSpacing.sm,
                        runSpacing: OmniSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          DueChip(task: task),
                          // Chỉ "Cao" mới đáng một chip: mọi thẻ đều "Bình
                          // thường" thì chữ đó không phân biệt được gì.
                          if (task.priority == 'high')
                            OmniBadge(
                              label:
                                  'Ưu tiên ${priorityLabel(task.priority).toLowerCase()}',
                              tone: OmniTone.warning,
                              large: true,
                            ),
                          if (!task.hasSubtasks) ...counts,
                        ],
                      ),
                    ),
                    const SizedBox(width: OmniSpacing.sm),
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

/// Một con số nhỏ kèm biểu tượng: 📎 2, 💬 3, ★ 4 — cùng cỡ, cùng màu phụ.
///
/// Biểu tượng nói loại, số nói bao nhiêu; đọc thành tiếng cho trợ năng là
/// "2 ảnh đính kèm" chứ không phải một con số trần.
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
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontFeatures: OmniType.tabular,
            ),
          ),
        ],
      ),
    );
  }
}

/// Thanh tiến độ và "n/m việc con" trên CÙNG một dòng (`MMyTasks.dc.html`).
///
/// Thanh màu quỹ đạo sáng — màu đồ hoạ của bộ Orbit, chỉ dùng cho đồ hoạ.
/// Xong hay chưa đọc qua CON SỐ và độ dài thanh, không qua sắc màu.
class _Progress extends StatelessWidget {
  const _Progress({required this.task, this.trailing = const []});

  final Task task;

  /// Các con số nhỏ (📎 💬 ★) đứng sau dòng "n/m việc con".
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: OmniRadius.pillAll,
            child: LinearProgressIndicator(
              value: task.progress,
              minHeight: 6,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(
                dark ? scheme.primary : OmniColors.orbit,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${task.doneCount}/${task.totalCount} việc con',
          style: OmniType.micro.copyWith(
            color: dark
                ? scheme.onSurfaceVariant
                : OmniColors.secondaryForeground,
            // Tabular so the numbers do not jitter as stages complete.
            fontFeatures: OmniType.tabular,
          ),
        ),
        for (final w in trailing) ...[const SizedBox(width: OmniSpacing.sm), w],
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

  static const double _size = 26;
  static const double _ring = 2;

  /// Bước giữa hai avatar: 26 − 6 chồng. Thiết kế chồng 8 (31%), nhưng
  /// `task_card_test` giữ trần 25% vì ảnh chụp thật từng che mất nửa chữ tắt.
  static const double _step = 20;

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

/// Tiêu đề với mọi chỗ khớp [query] (không phân biệt hoa thường) tô nền vàng.
TextSpan _highlighted(String text, String query, BuildContext context) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return TextSpan(text: text);

  final dark = Theme.of(context).brightness == Brightness.dark;
  final mark = TextStyle(
    backgroundColor: dark ? OmniColors.darkWarningSoft : OmniColors.warningSoft,
  );
  final lower = text.toLowerCase();
  final spans = <TextSpan>[];
  var start = 0;
  while (true) {
    final hit = lower.indexOf(needle, start);
    if (hit < 0) break;
    if (hit > start) spans.add(TextSpan(text: text.substring(start, hit)));
    spans.add(
      TextSpan(text: text.substring(hit, hit + needle.length), style: mark),
    );
    start = hit + needle.length;
  }
  if (start < text.length) spans.add(TextSpan(text: text.substring(start)));

  return TextSpan(children: spans);
}
