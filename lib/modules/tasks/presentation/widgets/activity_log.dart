import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../design/platform/omni_motion_scope.dart';
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
///
/// Giao diện (`TaskDetail.dc.html`): nút "NHẬT KÝ (n)" hoa 12 w600 + mũi tên
/// xoay 180° khi mở; thân là thẻ chữ 12 cao 1.9, mở/gập 400ms (bỏ hẳn khi giảm
/// chuyển động).
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

  void _toggle() => setState(() => _open = !_open);

  /// Mở/gập mượt khi được phép. Giảm chuyển động thì KHÔNG dùng AnimatedSize
  /// với thời lượng 0: nó vẫn khởi động một bộ điều khiển trong lúc bố cục (và
  /// báo lỗi), nên nhánh này bỏ hẳn nó.
  static Widget _sized({
    required bool motion,
    required Duration duration,
    required Widget child,
  }) => motion
      ? AnimatedSize(
          duration: duration,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: child,
        )
      : child;

  @override
  Widget build(BuildContext context) {
    final entries = widget.task.activity;
    if (entries.isEmpty) {
      // Không có dòng nào thì không có gì để gấp. Một khối "Nhật ký (0)" chỉ
      // dạy người dùng rằng bấm vào nó không ra gì.
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final muted = OmniColors.byBrightness(
      context,
      OmniColors.mutedForeground,
      scheme.onSurfaceVariant,
    );
    final motion = OmniMotion.enabled(context);
    final duration = motion ? const Duration(milliseconds: 400) : Duration.zero;
    // Mới nhất trước: câu hỏi luôn là "vừa có chuyện gì", không phải "hồi đầu
    // có chuyện gì". API trả về cũ nhất trước vì đó là thứ tự nó ghi.
    final newestFirst = entries.reversed.toList();
    final shown = newestFirst.take(_shown).toList();

    final head = Align(
      alignment: Alignment.centerLeft,
      widthFactor: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: OmniSpacing.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'NHẬT KÝ (${entries.length})',
              style: OmniType.micro.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: muted,
              ),
            ),
            const SizedBox(width: OmniSpacing.xs),
            AnimatedRotation(
              turns: _open ? 0.5 : 0,
              duration: duration,
              child: Icon(Icons.expand_more_rounded, size: 18, color: muted),
            ),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            expanded: _open,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              // Giảm chuyển động: không InkWell, vì gợn sóng và vệt sáng của nó
              // là hoạt ảnh mà cài đặt này đã xin bỏ.
              child: motion
                  ? InkWell(
                      onTap: _toggle,
                      borderRadius: OmniRadius.smAll,
                      child: head,
                    )
                  : GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _toggle,
                      child: head,
                    ),
            ),
          ),
          _sized(
            motion: motion,
            duration: duration,
            child: _open
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final entry in shown)
                          _Line(
                            entry: entry,
                            sections: widget.task.planSections,
                          ),
                        if (newestFirst.length > shown.length)
                          TextButton(
                            onPressed: () => setState(
                              () => _shown = (_shown + _pageSize).clamp(
                                0,
                                entries.length,
                              ),
                            ),
                            child: Text(
                              'Xem thêm ${newestFirst.length - shown.length} dòng',
                              style: OmniType.micro,
                            ),
                          ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
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
