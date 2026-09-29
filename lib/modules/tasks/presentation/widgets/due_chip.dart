import 'package:flutter/material.dart';

import '../../../../design/components/omni_status_chip.dart';
import '../../domain/task.dart';

/// Hạn của một công việc, bằng CHỮ chứ không chỉ bằng màu.
///
/// Trước đây widget này tồn tại hai bản gần giống hệt nhau — một trong
/// `task_card.dart`, một trong `task_detail_page.dart` — và cả hai đều tô chữ
/// bằng `OmniColors.destructive` (3.76:1) và `OmniColors.warning` (2.15:1).
/// Hai màu đó là màu ĐỒ HOẠ; làm chữ thì không đọc được. Gộp về một chỗ để
/// lần sửa tiếp theo chỉ phải sửa một lần.
class DueChip extends StatelessWidget {
  const DueChip({super.key, required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final overdue = task.daysOverdue;

    // Thứ tự các nhánh LÀ thứ tự ưu tiên: quá hạn nói to hơn hạn hôm nay, và
    // hạn hôm nay nói to hơn một ngày trong tương lai.
    // Bộ Orbit: viên bo tròn chữ đậm, không icon — CHỮ đã nói trạng thái,
    // màu chỉ nhắc lại. Quá hạn đỏ, hôm nay xanh dương, còn lại trung tính.
    final (label, tone) = switch (task) {
      _ when overdue != null => ('Quá hạn $overdue ngày', OmniTone.danger),
      _ when task.isDueToday => ('Hạn hôm nay', OmniTone.info),
      _ when task.dueDate != null => (
        'Hạn ${task.dueDate!.day}/${task.dueDate!.month}',
        OmniTone.neutral,
      ),
      _ => ('Chưa đặt hạn', OmniTone.neutral),
    };

    return OmniBadge(label: label, tone: tone, large: true);
  }
}
