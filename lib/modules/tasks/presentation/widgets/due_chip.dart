import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../design/components/omni_task_chip.dart';
import '../../domain/task.dart';

/// Bốn tông của ô hạn (`Tasks.dc.html`): hôm nay, trễ, sắp tới, chưa đặt.
enum DueTone { today, late, upcoming, none }

/// Nhãn + tông hạn của một việc, tính theo NGÀY LỊCH.
///
/// Tự tính từ `task.dueDate` và [now] thay vì đọc `Task.daysOverdue` (vốn đọc
/// `DateTime.now()` trực tiếp) để test dựng được ở một thời điểm cố định.
/// Việc đã xong không bị tô trễ: nó rơi về "Hạn dd/MM".
({String label, DueTone tone}) dueToneOf(Task task, {DateTime? now}) {
  final due = task.dueDate;
  if (due == null) return (label: 'Chưa đặt hạn', tone: DueTone.none);
  // Ngày VN (không theo múi giờ máy), như web và API.
  final today = VnTime.today(now);
  final day = VnTime.day(due);
  final diff = today.difference(day).inDays;
  final done = task.status == 'done';
  if (diff == 0 && !done) return (label: 'Hạn hôm nay', tone: DueTone.today);
  if (diff > 0 && !done) {
    return (label: 'Quá hạn $diff ngày', tone: DueTone.late);
  }
  final dd = day.day.toString().padLeft(2, '0');
  final mm = day.month.toString().padLeft(2, '0');

  return (label: 'Hạn $dd/$mm', tone: DueTone.upcoming);
}

/// Hạn của một công việc, bằng CHỮ chứ không chỉ bằng màu.
///
/// Một chỗ duy nhất cho thẻ việc, bảng dự án và đầu trang chi tiết. Màu lấy
/// từ [OmniTaskChip] (token theo chế độ sáng / tối).
class DueChip extends StatelessWidget {
  const DueChip({super.key, required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final d = dueToneOf(task);

    return switch (d.tone) {
      DueTone.today => OmniTaskChip.today(d.label),
      DueTone.late => OmniTaskChip.late(d.label),
      DueTone.upcoming => OmniTaskChip.upcoming(d.label),
      DueTone.none => OmniTaskChip.none(d.label),
    };
  }
}
