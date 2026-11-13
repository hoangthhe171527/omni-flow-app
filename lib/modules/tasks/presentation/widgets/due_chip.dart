import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../design/tokens/tokens.dart';
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

/// Viên thuốc trạng thái/hạn/ưu tiên chuẩn Liquid Glass (`radius: 999`).
class TaskPillChip extends StatelessWidget {
  const TaskPillChip(this.label, {super.key, required this.pick, this.icon});

  const TaskPillChip.late(this.label, {super.key, this.icon}) : pick = _late;
  const TaskPillChip.today(this.label, {super.key, this.icon}) : pick = _today;
  const TaskPillChip.upcoming(this.label, {super.key, this.icon})
    : pick = _upcoming;
  const TaskPillChip.none(this.label, {super.key, this.icon}) : pick = _none;
  const TaskPillChip.high(this.label, {super.key, this.icon}) : pick = _high;

  final String label;
  final IconData? icon;
  final OmniTaskTone Function(OmniTaskTones tones) pick;

  static OmniTaskTone _late(OmniTaskTones t) => t.late;
  static OmniTaskTone _today(OmniTaskTones t) => t.today;
  static OmniTaskTone _upcoming(OmniTaskTones t) => t.upcoming;
  static OmniTaskTone _none(OmniTaskTones t) => t.none;
  static OmniTaskTone _high(OmniTaskTones t) => t.highPriority;

  @override
  Widget build(BuildContext context) {
    final tone = pick(OmniTaskTones.of(context));
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: tone.foreground,
        fontWeight: icon == null ? FontWeight.w600 : FontWeight.w500,
        fontFeatures: OmniType.tabular,
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        child: icon == null
            ? text
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 13, color: tone.foreground),
                  const SizedBox(width: 4),
                  Flexible(child: text),
                ],
              ),
      ),
    );
  }
}

/// Hạn của một công việc, bằng CHỮ chứ không chỉ bằng màu.
///
/// Một chỗ duy nhất cho thẻ việc, bảng dự án và đầu trang chi tiết. Màu lấy
/// từ [OmniTaskTones] (token theo chế độ sáng / tối), bo viên thuốc 999px.
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
      DueTone.today => TaskPillChip.today(d.label, icon: icon),
      DueTone.late => TaskPillChip.late(d.label, icon: icon),
      DueTone.upcoming => TaskPillChip.upcoming(d.label, icon: icon),
      DueTone.none => TaskPillChip.none(d.label, icon: icon),
    };
  }
}
