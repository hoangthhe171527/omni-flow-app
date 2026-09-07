import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../design/tokens/tokens.dart';
import '../../domain/task.dart';

/// Phần chỉ người GIAO việc thấy.
///
/// Người thợ mở công việc để LÀM nó: tên đàn, công đoạn, tick, chụp ảnh.
/// Người quản đốc mở để ĐIỀU nó: ai làm, hạn nào, đang ở công đoạn nào, ưu
/// tiên ra sao. Cho thợ thấy nút gán người là mời họ làm một việc API sẽ từ
/// chối — và mỗi nút thừa là một chỗ để bấm nhầm khi tay đang bẩn.
///
/// Ranh giới đi qua `TaskAccess.isAssigner`, tức qua QUYỀN. Không qua tên vai
/// trò: vai trò do từng tenant tự đặt tên.
class AssignerPanel extends StatelessWidget {
  const AssignerPanel({super.key, required this.task, this.onMoveSection});

  final Task task;

  final VoidCallback? onMoveSection;

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
          Text(
            'Điều phối',
            style: OmniType.overline.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: OmniSpacing.md),
          _Row(
            icon: Icons.person_outline_rounded,
            label: 'Người làm',
            // Ô trống ở chỗ tên người đọc như lỗi tải. "Chưa gán ai" là câu
            // trả lời, và nó cũng là việc cần làm.
            value: task.assigneeNames.isEmpty
                ? 'Chưa gán ai'
                : task.assigneeNames.join(', '),
            muted: task.assigneeNames.isEmpty,
          ),
          // Hạn mang theo TÌNH TRẠNG của nó, không chỉ con số.
          //
          // Người nhận việc thấy điều này qua chip ở đầu màn; người giao việc
          // không thấy chip đó nữa (nó trùng với bảng này), nên nếu dòng này
          // chỉ in ngày thì họ mất hẳn tín hiệu quá hạn — đúng thứ họ mở màn
          // này ra để tìm.
          _Row(
            icon: task.daysOverdue != null
                ? Icons.error_outline_rounded
                : Icons.event_outlined,
            label: 'Hạn',
            value: switch (task) {
              _ when task.dueDate == null => 'Chưa đặt hạn',
              _ when task.daysOverdue != null =>
                '${Formatters.date(task.dueDate!)} · quá hạn ${task.daysOverdue} ngày',
              _ when task.isDueToday =>
                '${Formatters.date(task.dueDate!)} · hôm nay',
              _ => Formatters.date(task.dueDate!),
            },
            muted: task.dueDate == null,
            tone: switch (task) {
              _ when task.daysOverdue != null => _Tone.danger,
              _ when task.isDueToday => _Tone.warning,
              _ => _Tone.plain,
            },
          ),
          _Row(
            icon: Icons.flag_outlined,
            label: 'Ưu tiên',
            value: _priorityLabel(task.priority),
          ),
          _Row(
            icon: Icons.view_column_outlined,
            label: 'Công đoạn',
            value: task.sectionName ?? 'Chưa xếp nhóm việc',
            muted: task.sectionName == null,
          ),
          if (onMoveSection != null) ...[
            const SizedBox(height: OmniSpacing.md),
            OutlinedButton.icon(
              onPressed: onMoveSection,
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('Chuyển nhóm việc'),
            ),
          ],
        ],
      ),
    );
  }

  /// Nhãn tiếng Việt cho ba mức API dùng.
  ///
  /// Giá trị lạ hiện nguyên văn chứ không rơi về "Bình thường": một dự án
  /// thêm mức "khẩn" mà app im lặng hạ nó xuống bình thường là cách một việc
  /// gấp bị bỏ quên.
  String _priorityLabel(String priority) => switch (priority) {
    'high' => 'Cao',
    'med' || 'medium' => 'Bình thường',
    'low' => 'Thấp',
    _ => priority,
  };
}

/// Sắc thái của một dòng. Chỉ ba: bình thường, cần để ý, đã hỏng.
enum _Tone { plain, warning, danger }

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.value,
    this.muted = false,
    this.tone = _Tone.plain,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool muted;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    // Cả icon lẫn chữ cùng một màu, để dòng đọc ra là một khối. Icon cũng đổi
    // hình chứ không chỉ đổi màu — chênh độ sáng giữa các màu trạng thái chỉ
    // 1.04–1.20 lần, nên màu một mình không phân biệt được.
    final accent = switch (tone) {
      _Tone.danger => OmniColors.dangerTextOf(context),
      _Tone.warning => OmniColors.warningTextOf(context),
      _Tone.plain => muted ? scheme.onSurfaceVariant : scheme.onSurface,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: OmniSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: OmniIconSize.md,
            color: tone == _Tone.plain ? scheme.onSurfaceVariant : accent,
          ),
          const SizedBox(width: OmniSpacing.md),
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: text.bodyMedium?.copyWith(
                color: accent,
                fontWeight: muted ? FontWeight.w400 : FontWeight.w600,
                fontStyle: muted ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
