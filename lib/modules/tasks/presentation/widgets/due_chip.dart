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
({String label, DueTone tone}) dueToneOf(Task task, {DateTime? now}) =>
    dueToneFor(task.dueDate, done: task.status == 'done', now: now);

/// Như [dueToneOf] cho một ngày trần (hạn của việc con).
({String label, DueTone tone}) dueToneFor(
  DateTime? due, {
  required bool done,
  DateTime? now,
}) {
  if (due == null) return (label: 'Chưa đặt hạn', tone: DueTone.none);
  // Ngày VN (không theo múi giờ máy), như web và API.
  final today = VnTime.today(now);
  final day = VnTime.day(due);
  final diff = today.difference(day).inDays;
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
  DueChip({super.key, required Task task, this.icon})
    : due = task.dueDate,
      done = task.status == 'done';

  /// Hạn của một việc con (`Subtask.dueDate`).
  const DueChip.date({
    super.key,
    required this.due,
    required this.done,
    this.icon,
  });

  final DateTime? due;
  final bool done;

  /// Biểu tượng trước chữ (thẻ bảng kế hoạch: lịch 13).
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final d = dueToneFor(due, done: done);

    return switch (d.tone) {
      DueTone.today => OmniTaskChip.today(d.label, icon: icon),
      DueTone.late => OmniTaskChip.late(d.label, icon: icon),
      DueTone.upcoming => OmniTaskChip.upcoming(d.label, icon: icon),
      DueTone.none => OmniTaskChip.none(d.label, icon: icon),
    };
  }
}
