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
  const AssignerPanel({
    super.key,
    required this.task,
    required this.sectionName,
    this.onMoveSection,
  });

  final Task task;

  /// Tên công đoạn hiện tại, đã tra từ kế hoạch. Null khi chưa xếp.
  final String? sectionName;

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
          _Row(
            icon: Icons.event_outlined,
            label: 'Hạn',
            value: task.dueDate == null
                ? 'Chưa đặt hạn'
                : Formatters.date(task.dueDate!),
            muted: task.dueDate == null,
          ),
          _Row(
            icon: Icons.flag_outlined,
            label: 'Ưu tiên',
            value: _priorityLabel(task.priority),
          ),
          _Row(
            icon: Icons.view_column_outlined,
            label: 'Công đoạn',
            value: sectionName ?? 'Chưa xếp công đoạn',
            muted: sectionName == null,
          ),
          if (onMoveSection != null) ...[
            const SizedBox(height: OmniSpacing.md),
            OutlinedButton.icon(
              onPressed: onMoveSection,
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('Chuyển công đoạn'),
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

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.value,
    this.muted = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: OmniSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: OmniIconSize.md, color: scheme.onSurfaceVariant),
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
                color: muted ? scheme.onSurfaceVariant : scheme.onSurface,
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
