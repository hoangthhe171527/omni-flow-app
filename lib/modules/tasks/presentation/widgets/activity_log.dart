import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../design/tokens/tokens.dart';
import '../../domain/task.dart';
import '../../domain/task_activity.dart';

/// "Ai đã kéo cây này về lại Đang làm, và lúc nào."
///
/// API ghi nhật ký này từ lâu và gửi kèm ở mỗi lần mở công việc — app chỉ chưa
/// đọc. Trao đổi (§B3) ghi LÝ DO một cây bị trả về; nhật ký ghi việc đã xảy
/// ra: ai chuyển, từ cột nào sang cột nào, tick xong công đoạn nào, gửi tấm
/// ảnh nào. Hai thứ trả lời hai nửa của cùng một câu hỏi, và nửa thứ hai
/// trước nay không có chỗ nào để đọc trên điện thoại.
///
/// GẤP mặc định. Một cây đàn đi hết vòng phục chế để lại hàng trăm dòng, và
/// mở sẵn là đẩy thanh thao tác — chỗ người thợ tick và chụp ảnh — ra khỏi tầm
/// ngón tay. Nhật ký là thứ người ta tra khi có nghi vấn, không phải thứ đọc
/// mỗi lần mở việc.
class ActivityLog extends StatefulWidget {
  const ActivityLog({super.key, required this.task});

  final Task task;

  @override
  State<ActivityLog> createState() => _ActivityLogState();
}

class _ActivityLogState extends State<ActivityLog> {
  /// Số dòng hiện ra ở lần mở đầu tiên.
  static const _pageSize = 20;

  bool _open = false;
  int _shown = _pageSize;

  @override
  Widget build(BuildContext context) {
    final entries = widget.task.activity;
    if (entries.isEmpty) {
      // Không có dòng nào thì không có gì để gấp. Một khối "Nhật ký (0)" chỉ
      // dạy người dùng rằng bấm vào nó không ra gì.
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    // Mới nhất trước: câu hỏi luôn là "vừa có chuyện gì", không phải "hồi đầu
    // có chuyện gì". API trả về cũ nhất trước vì đó là thứ tự nó ghi.
    final newestFirst = entries.reversed.toList();
    final shown = newestFirst.take(_shown).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.lg,
        OmniSpacing.md,
        OmniSpacing.lg,
        OmniSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            expanded: _open,
            child: InkWell(
              onTap: () => setState(() => _open = !_open),
              borderRadius: OmniRadius.smAll,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: OmniSpacing.sm),
                child: Row(
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: OmniIconSize.sm,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: OmniSpacing.sm),
                    Text(
                      'Nhật ký (${entries.length})',
                      style: OmniType.bodyStrong.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _open
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_open) ...[
            const SizedBox(height: OmniSpacing.xs),
            for (final entry in shown)
              _Line(entry: entry, sections: widget.task.planSections),
            if (newestFirst.length > shown.length)
              TextButton(
                onPressed: () => setState(
                  () => _shown = (_shown + _pageSize).clamp(0, entries.length),
                ),
                child: Text(
                  'Xem thêm ${newestFirst.length - shown.length} dòng',
                  style: text.labelMedium,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Một dòng: ai, làm gì, lúc nào.
class _Line extends StatelessWidget {
  const _Line({required this.entry, required this.sections});

  final TaskActivityEntry entry;
  final List<TaskSection> sections;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: OmniSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon, size: OmniIconSize.sm, color: scheme.onSurfaceVariant),
          const SizedBox(width: OmniSpacing.sm),
          Expanded(
            child: Text(
              // Tên người đứng trước hành động khi biết được: "Hằng Ni đã
              // chuyển Nhập xưởng → Chờ QC" đọc như một câu, còn thiếu tên
              // thì vẫn là một câu — chỉ là câu không có chủ ngữ, và một
              // UUID ở đó còn tệ hơn.
              entry.userName == null
                  ? entry.summary(sections)
                  : '${entry.userName} ${entry.summary(sections)}',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: OmniSpacing.sm),
          // NGÀY và giờ, không phải "2 giờ trước": một cây đàn nằm ở xưởng
          // hàng tuần, nên "3 ngày trước" không đối chiếu được với ca làm nào
          // cả. Ngày trên, giờ dưới — hai dòng hẹp thay vì một dòng dài ăn
          // mất chỗ của câu bên trái.
          if (entry.at != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Formatters.date(entry.at),
                  style: text.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontFeatures: OmniType.tabular,
                  ),
                ),
                Text(
                  Formatters.time(entry.at),
                  style: text.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontFeatures: OmniType.tabular,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  IconData get _icon => switch (entry.kind) {
    TaskActivityKind.created => Icons.add_circle_outline_rounded,
    TaskActivityKind.section => Icons.swap_horiz_rounded,
    TaskActivityKind.status => Icons.check_circle_outline_rounded,
    TaskActivityKind.dueDate => Icons.event_outlined,
    TaskActivityKind.assignees => Icons.person_outline_rounded,
    TaskActivityKind.subtaskCompleted => Icons.task_alt_rounded,
    TaskActivityKind.subtaskAssigned => Icons.how_to_reg_outlined,
    TaskActivityKind.attachmentAdded => Icons.image_outlined,
    TaskActivityKind.attachmentRemoved => Icons.hide_image_outlined,
    TaskActivityKind.other => Icons.circle_outlined,
  };
}
