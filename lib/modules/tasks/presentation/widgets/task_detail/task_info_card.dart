import 'package:flutter/material.dart';

import '../../../../../core/utils/formatters.dart';
import '../../../../../design/components/components.dart';
import '../../../../../design/tokens/tokens.dart';
import '../../../domain/task.dart';
import '../due_chip.dart';
import '../edit_sheets.dart';

/// Thẻ thông tin (`TaskDetail.dc.html` thẻ `.cd` đầu tiên): Người làm,
/// Thời gian, Đánh giá, cộng dòng Ưu tiên (giữ năng lực, bản mẫu không có).
///
/// Dòng 48, nhãn trái rộng 104 chữ 14 màu phụ. Mọi hành động là callback;
/// null = chỉ hiển thị.
///
/// Chuỗi "người giao → người làm" (Nhóm 2): avatar 30 của người giao, mũi
/// tên 14 màu mờ, rồi người làm. Chỉ vẽ khi API trang trí tên người giao
/// (`Task.assignerName`: `assigned_by_name`, việc cũ thì `created_by_name`)
/// và việc đã có người làm. API cũ không có tên → không vẽ, không đoán.
class TaskInfoCard extends StatelessWidget {
  const TaskInfoCard({
    super.key,
    required this.task,
    required this.likedByMe,
    this.onAddAssignee,
    this.onTime,
    this.onRate,
    this.onLike,
    this.showPriority = false,
    this.showAssigner = false,
    this.onPriority,
  });

  final Task task;
  final bool likedByMe;

  /// Vòng nét đứt +: người giao việc (giao) hoặc thợ chưa có tên (tự nhận).
  final ValueChanged<Rect>? onAddAssignee;
  final VoidCallback? onTime;

  /// Chạm sao thứ n (1–5). null = không chấm được.
  final ValueChanged<int>? onRate;
  final VoidCallback? onLike;
  final bool showPriority;

  /// Vẽ chuỗi "người giao → người làm" (khả năng `tasks.assigned_by`).
  final bool showAssigner;
  final VoidCallback? onPriority;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(color: scheme.surface),
      child: Column(
        children: [
          _Row(
            label: 'Người làm',
            child: _People(
              task: task,
              onAdd: onAddAssignee,
              showAssigner: showAssigner,
            ),
          ),
          _Row(
            label: 'Thời gian',
            divider: true,
            onTap: onTime,
            child: _Time(task: task, canEdit: onTime != null),
          ),
          _Row(
            label: 'Đánh giá',
            divider: true,
            child: _Rating(
              rating: task.rating,
              likes: task.likes.length,
              likedByMe: likedByMe,
              onRate: onRate,
              onLike: onLike,
            ),
          ),
          if (showPriority)
            _Row(
              label: 'Ưu tiên',
              divider: true,
              onTap: onPriority,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _priorityChip(task.priority),
              ),
            ),
        ],
      ),
    );
  }

  static Widget _priorityChip(String priority) {
    final label = priorityLabel(priority);

    return switch (priority) {
      'high' => OmniTaskChip.high(label),
      'low' => OmniTaskChip.none(label),
      _ => OmniTaskChip.upcoming(label),
    };
  }
}

/// `.row`: cao ≥48, đệm 0 6 0 12, cách 10; vạch `#EEF1F5` giữa các dòng.
class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.child,
    this.divider = false,
    this.onTap,
  });

  final String label;
  final Widget child;
  final bool divider;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final row = Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.fromLTRB(12, 0, 6, 0),
      decoration: BoxDecoration(
        border: divider
            ? Border(top: BorderSide(color: OmniColors.trackOf(context)))
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: OmniType.bodySm.copyWith(
                color: OmniColors.byBrightness(
                  context,
                  OmniColors.mutedForeground,
                  scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Align(alignment: Alignment.centerRight, child: child),
          ),
        ],
      ),
    );
    if (onTap == null) return row;

    return InkWell(onTap: onTap, child: row);
  }
}

class _People extends StatelessWidget {
  const _People({
    required this.task,
    required this.onAdd,
    required this.showAssigner,
  });

  final Task task;
  final ValueChanged<Rect>? onAdd;
  final bool showAssigner;

  static const _max = 3;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final names = task.assigneeNames;
    final shown = names.take(_max).toList();
    final more = names.length - shown.length;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (names.isEmpty)
          Flexible(
            child: Padding(
              padding: EdgeInsets.only(right: onAdd == null ? 8 : 4),
              child: Text(
                'Chưa giao ai',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: OmniType.bodySm.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          )
        else ...[
          if (showAssigner)
            if (task.assignerName case final assigner?) ...[
              Semantics(
                label: 'Người giao: $assigner',
                excludeSemantics: true,
                child: OmniAvatar(
                  key: const Key('assigner-avatar'),
                  name: assigner,
                  imageUrl: task.assignerAvatar,
                  size: 30,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: OmniTaskTones.of(context).faint,
              ),
              const SizedBox(width: 6),
            ],
          Semantics(
            label: 'Người làm: ${names.join(', ')}',
            excludeSemantics: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < shown.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  OmniAvatar(
                    name: shown[i],
                    imageUrl: task.assigneeAvatarAt(i),
                    size: 30,
                  ),
                ],
                if (more > 0) ...[
                  const SizedBox(width: 6),
                  Text(
                    '+$more',
                    style: OmniType.micro.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (onAdd == null) const SizedBox(width: 6),
              ],
            ),
          ),
        ],
        if (onAdd != null)
          Builder(
            builder: (buttonContext) => Semantics(
              button: true,
              label: 'Thêm người làm',
              excludeSemantics: true,
              child: InkWell(
                onTap: () {
                  final box = buttonContext.findRenderObject() as RenderBox?;
                  if (box == null || !box.hasSize) return;
                  onAdd!(box.localToGlobal(Offset.zero) & box.size);
                },
                borderRadius: BorderRadius.circular(6),
                child: SizedBox.square(
                  dimension: 44,
                  child: Center(
                    child: OmniDashedCircle(size: 30, color: scheme.primary),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Time extends StatelessWidget {
  const _Time({required this.task, required this.canEdit});

  final Task task;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final start = task.startDate;
    final due = task.dueDate;
    final scheme = Theme.of(context).colorScheme;

    if (start == null && due == null) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Text(
          canEdit ? 'Đặt thời gian' : 'Chưa đặt thời gian',
          style: OmniType.bodySm.copyWith(
            color: OmniColors.byBrightness(
              context,
              OmniColors.mutedForeground,
              scheme.onSurfaceVariant,
            ).withValues(alpha: 0.85),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (start != null)
              OmniTaskChip.upcoming(Formatters.dayMonth(start)),
            if (start != null && due != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Container(
                  width: 9,
                  height: 2,
                  decoration: BoxDecoration(
                    color: OmniTaskTones.of(context).faint,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            if (due != null) DueChip(task: task),
          ],
        ),
      ),
    );
  }
}

/// Năm sao 22 (vùng chạm 28×44, liền nhau) + "n/5 · m lượt" là nút thích.
///
/// Bản mẫu vẽ ô sao 30; ở 390 với Be Vietnam Pro thật, 5×30 cộng "4/5 · 3
/// lượt" vượt ô giá trị (~224) vài px và chữ rớt dòng. 28 giữ chữ một dòng;
/// sao vẫn 22.
class _Rating extends StatelessWidget {
  const _Rating({
    required this.rating,
    required this.likes,
    required this.likedByMe,
    required this.onRate,
    required this.onLike,
  });

  final int rating;
  final int likes;
  final bool likedByMe;
  final ValueChanged<int>? onRate;
  final VoidCallback? onLike;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tones = OmniTaskTones.of(context);
    final text = '$rating/5 · $likes lượt';
    final secondary = OmniColors.byBrightness(
      context,
      OmniColors.mutedForeground,
      scheme.onSurfaceVariant,
    );

    // Ô giá trị ở 390 chỉ còn ~224: năm sao 150 cộng chữ vừa khít. Màn hẹp
    // hơn (hoặc chữ phóng to) thì CHỮ xuống dòng, sao giữ nguyên cỡ — thu cả
    // cụm là thu luôn vùng chạm.
    return _row(tones, text, secondary, scheme);
  }

  Widget _row(
    OmniTaskTones tones,
    String text,
    Color secondary,
    ColorScheme scheme,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var n = 1; n <= 5; n++)
          Semantics(
            label: '$n sao',
            button: onRate != null,
            selected: n <= rating,
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onRate == null ? null : () => onRate!(n),
              child: SizedBox(
                width: 28,
                height: 44,
                child: Center(
                  child: Icon(
                    Icons.star_rounded,
                    key: const ValueKey('rating-star'),
                    size: 22,
                    color: n <= rating ? tones.star : tones.starIdle,
                  ),
                ),
              ),
            ),
          ),
        Flexible(
          child: Semantics(
            button: onLike != null,
            toggled: likedByMe,
            label: 'Thích việc này, $likes lượt',
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onLike,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44, minWidth: 48),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 6, 0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    widthFactor: 1,
                    child: Text(
                      text,
                      textAlign: TextAlign.right,
                      style: OmniType.micro.copyWith(
                        fontWeight: likedByMe
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: likedByMe ? scheme.primary : secondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Kết quả sheet Thời gian: ngày bắt đầu và hạn sau khi sửa (null = trống).
class TaskTimeChoice {
  const TaskTimeChoice({required this.start, required this.due});

  final DateTime? start;
  final DateTime? due;
}

/// Sheet Thời gian: hai ô ngày (bắt đầu / hạn) cùng chip nhanh Hôm nay /
/// Ngày mai / Tuần sau (đặt HẠN, như sheet tạo việc con của bản mẫu).
/// "Lưu" trả về cả hai; đóng sheet trả null.
Future<TaskTimeChoice?> showTaskTimeSheet(
  BuildContext context, {
  required DateTime? start,
  required DateTime? due,
}) => showOmniViecSheet<TaskTimeChoice>(
  context: context,
  builder: (_) => _TimeSheet(start: start, due: due),
);

class _TimeSheet extends StatefulWidget {
  const _TimeSheet({required this.start, required this.due});

  final DateTime? start;
  final DateTime? due;

  @override
  State<_TimeSheet> createState() => _TimeSheetState();
}

class _TimeSheetState extends State<_TimeSheet> {
  late DateTime? _start = widget.start;
  late DateTime? _due = widget.due;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<DateTime?> _pick(DateTime? current) {
    final now = DateTime.now();
    final initial = current ?? now;
    // Khoảng chọn luôn chứa ngày đang có: ngày đặt từ web có thể nằm ngoài
    // ±vài năm, và showDatePicker ném lỗi khi ngày đầu nằm ngoài khoảng.
    var first = DateTime(now.year - 1);
    var last = DateTime(now.year + 3, 12, 31);
    if (initial.isBefore(first)) first = DateTime(initial.year - 1);
    if (initial.isAfter(last)) last = DateTime(initial.year + 1, 12, 31);

    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = _day(DateTime.now());
    final quick = [
      ('Hôm nay', today),
      ('Ngày mai', today.add(const Duration(days: 1))),
      ('Tuần sau', today.add(const Duration(days: 7))),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const OmniSheetHandle(gap: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Thời gian',
                    style: OmniType.section.copyWith(color: scheme.onSurface),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(TaskTimeChoice(start: _start, due: _due)),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    foregroundColor: scheme.primary,
                    textStyle: OmniType.bodyStrong,
                  ),
                  child: const Text('Lưu'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    key: const ValueKey('time-start'),
                    label: 'Ngày bắt đầu',
                    value: _start,
                    onTap: () async {
                      final d = await _pick(_start);
                      if (d != null && mounted) setState(() => _start = d);
                    },
                    onClear: () => setState(() => _start = null),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DateField(
                    key: const ValueKey('time-due'),
                    label: 'Hạn',
                    value: _due,
                    onTap: () async {
                      final d = await _pick(_due);
                      if (d != null && mounted) setState(() => _due = d);
                    },
                    onClear: () => setState(() => _due = null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (var i = 0; i < quick.length; i++)
                  _QuickChip(
                    label: quick[i].$1,
                    on: _due != null && _day(_due!) == quick[i].$2,
                    onTap: () => setState(() => _due = quick[i].$2),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// `.in`: ô cao 48, viền `#E3E8EF` (có giá trị thì viền primary), bo 8.
class _DateField extends StatelessWidget {
  const _DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final v = value;

    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: v == null ? scheme.outlineVariant : scheme.primary,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  v == null
                      ? label
                      : '${label == 'Hạn' ? 'Hạn ' : ''}'
                            '${Formatters.dayMonth(v)}/${v.year}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OmniType.bodySm.copyWith(
                    color: v == null
                        ? scheme.onSurfaceVariant
                        : scheme.onSurface,
                  ),
                ),
              ),
              if (v != null)
                IconButton(
                  tooltip: label == 'Hạn' ? 'Xoá hạn' : 'Xoá ngày bắt đầu',
                  onPressed: onClear,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    padding: EdgeInsets.zero,
                  ),
                  icon: Icon(
                    Icons.close_rounded,
                    size: OmniIconSize.sm,
                    color: scheme.onSurfaceVariant,
                  ),
                )
              else
                const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// `.qc`: chip 36 cao (vùng chạm 44), bật nền `#E6F3F2` chữ `#075E59`.
class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.on,
    required this.onTap,
  });

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tone = OmniTaskTones.of(context).today;

    return Semantics(
      button: true,
      selected: on,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? tone.background : scheme.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: on ? scheme.primary : scheme.outlineVariant,
              ),
            ),
            child: Text(
              label,
              style: OmniType.caption.copyWith(
                fontWeight: FontWeight.w500,
                color: on
                    ? tone.foreground
                    : OmniTaskTones.of(context).upcoming.foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
