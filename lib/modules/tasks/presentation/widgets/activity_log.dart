import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../design/components/components.dart';
import '../../../../design/platform/omni_motion_scope.dart';
import '../../../../design/tokens/tokens.dart';
import '../../domain/task.dart';
import '../../domain/task_activity.dart';
import 'task_detail/detail_card.dart';
import 'task_detail/task_viewers.dart';

/// Thẻ Nhật ký hoạt động (`TaskDetail.dc.html`): đầu thẻ có nút "Xem" (mở cả
/// nhật ký trong một sheet), thân là dòng "Đã xem việc này" cùng avatar 24
/// chồng ([TaskViewers]).
///
/// "Ai đã kéo cây này về lại Đang làm, và lúc nào": API gửi nhật ký kèm mỗi
/// lần mở việc. Một cây đàn đi hết vòng phục chế để lại hàng trăm dòng, nên
/// nó nằm sau nút "Xem" chứ không bày sẵn — là thứ tra khi có nghi vấn.
///
/// Không có dòng nhật ký và chưa ai xem thì cả thẻ ẩn.
class ActivityCard extends StatelessWidget {
  const ActivityCard({super.key, required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final entries = task.activity;
    final viewers = task.viewers;
    if (entries.isEmpty && viewers.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return DetailCard(
      flat: true,
      children: [
        DetailCardHeader(
          icon: Icons.schedule_rounded,
          title: 'Nhật ký hoạt động',
          actions: [
            if (entries.isNotEmpty)
              TextButton(
                onPressed: () => showActivityLogSheet(context, task),
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  // Giảm chuyển động: không gợn sóng (cũng là một hoạt ảnh).
                  splashFactory: OmniMotion.enabled(context)
                      ? null
                      : NoSplash.splashFactory,
                  foregroundColor: scheme.primary,
                  textStyle: OmniType.caption.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text('Xem', semanticsLabel: 'Xem nhật ký hoạt động'),
              ),
          ],
        ),
        if (viewers.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: TaskViewers(viewers: viewers),
          ),
      ],
    );
  }
}

/// Cả nhật ký, mới nhất trước, 20 dòng một lần ("Xem thêm n dòng").
Future<void> showActivityLogSheet(BuildContext context, Task task) =>
    showOmniViecSheet<void>(
      context: context,
      builder: (_) => ActivityLogSheet(task: task),
    );

class ActivityLogSheet extends StatefulWidget {
  const ActivityLogSheet({super.key, required this.task});

  final Task task;

  @override
  State<ActivityLogSheet> createState() => _ActivityLogSheetState();
}

class _ActivityLogSheetState extends State<ActivityLogSheet> {
  static const _pageSize = 20;
  int _shown = _pageSize;

  @override
  Widget build(BuildContext context) {
    // Mới nhất trước: câu hỏi luôn là "vừa có chuyện gì". API trả cũ nhất
    // trước vì đó là thứ tự nó ghi.
    final newestFirst = widget.task.activity.reversed.toList();
    final shown = newestFirst.take(_shown).toList();
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      label: 'Nhật ký hoạt động',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const OmniSheetHandle(),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Nhật ký hoạt động (${newestFirst.length})',
                style: OmniType.section.copyWith(color: scheme.onSurface),
              ),
            ),
            for (final entry in shown)
              _Line(entry: entry, sections: widget.task.planSections),
            if (newestFirst.length > shown.length)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(
                    () => _shown = (_shown + _pageSize).clamp(
                      0,
                      newestFirst.length,
                    ),
                  ),
                  style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                  child: Text(
                    'Xem thêm ${newestFirst.length - shown.length} dòng',
                  ),
                ),
              ),
          ],
        ),
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
    final muted = OmniColors.byBrightness(
      context,
      OmniColors.mutedForeground,
      scheme.onSurfaceVariant,
    );
    // 12 cao 1.9 (`TaskDetail.dc.html`): dòng thưa để đọc từng sự kiện.
    final style = OmniType.micro.copyWith(
      height: 1.9,
      fontWeight: FontWeight.w400,
      color: muted,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Icon(_icon, size: OmniIconSize.sm, color: muted),
        ),
        const SizedBox(width: OmniSpacing.sm),
        Expanded(
          child: Text(
            // Tên người đứng trước hành động khi biết được: "Hằng Ni đã chuyển
            // Nhập xưởng → Chờ QC" đọc như một câu, còn thiếu tên thì vẫn là
            // một câu — chỉ là câu không có chủ ngữ, và một UUID ở đó còn tệ
            // hơn.
            entry.userName == null
                ? entry.summary(sections)
                : '${entry.userName} ${entry.summary(sections)}',
            style: style,
          ),
        ),
        const SizedBox(width: OmniSpacing.sm),
        // NGÀY và giờ, không phải "2 giờ trước": một cây đàn nằm ở xưởng hàng
        // tuần, nên "3 ngày trước" không đối chiếu được với ca làm nào cả. Ngày
        // trên, giờ dưới — hai dòng hẹp thay vì một dòng dài ăn mất chỗ của
        // câu bên trái.
        if (entry.at != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Formatters.date(entry.at),
                style: style.copyWith(
                  height: 1.4,
                  fontFeatures: OmniType.tabular,
                ),
              ),
              Text(
                Formatters.time(entry.at),
                style: style.copyWith(
                  height: 1.4,
                  fontFeatures: OmniType.tabular,
                ),
              ),
            ],
          ),
      ],
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
