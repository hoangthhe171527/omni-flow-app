import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../design/components/components.dart';
import '../../../../design/platform/omni_motion_scope.dart';
import '../../../../design/tokens/tokens.dart';
import '../../application/task_controller.dart';
import '../../domain/task.dart';
import 'due_chip.dart';

/// Một việc con (`TaskDetail.dc.html` `.sub`): ô tích 22 bo 6, tên w500 (gạch
/// khi xong), hàng nhỏ gồm người làm (avatar 28 hoặc nút nét đứt "Người làm")
/// và hạn (`DueChip`), cùng ⋮ "Tuỳ chọn việc con".
///
/// Người dùng đứng ở bàn làm việc với tay bẩn, trong phòng ồn. Hệ quả:
///
///  * Ô tích, nút người làm và ⋮ mỗi cái là một vùng chạm ≥ 44 riêng — tick
///    nhầm một công đoạn là cây đàn bị đánh dấu xong sai.
///  * Tick rung nhẹ: trong xưởng không nghe được tiếng và có thể đang không
///    nhìn màn hình.
///  * Đổi tên / xoá nằm sau ⋮: một nút xoá nằm ngay trên dòng là một cái bẫy.
///
/// Nhóm 2: ghi chú 13 phụ (có thì vẽ), chip "Từ dd/MM", nút nét đứt "Hạn"
/// ([onSetDue]) và tay kéo ([dragHandle]) — hai cái sau chỉ có khi phiên
/// khai khả năng tương ứng.
class SubtaskRow extends StatelessWidget {
  const SubtaskRow({
    super.key,
    required this.subtask,
    required this.pending,
    required this.enabled,
    required this.onToggle,
    required this.onRetry,
    required this.onDiscard,
    this.onMenu,
    this.onAssign,
    this.assigneeName,
    this.assigneeAvatar,
    this.first = false,
    this.onSetDue,
    this.dragHandle,
  });

  /// Vùng chạm tối thiểu của mỗi nút trong dòng.
  static const double tapSize = 44;

  final Subtask subtask;
  final PendingTick? pending;

  /// Được tick (`taskAccess.canComplete`). False = chỉ xem.
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final VoidCallback onRetry;
  final VoidCallback onDiscard;

  /// ⋮ "Tuỳ chọn việc con" (Đổi tên, Giao, Xoá). null = không có nút.
  final VoidCallback? onMenu;

  /// Mở bảng "Ai làm việc này". Null = nút người làm chỉ hiển thị.
  final VoidCallback? onAssign;

  /// Tên / ảnh người đang làm. Tên null mà [Subtask.assigneeId] có = server
  /// không tra ra tên; vẫn là avatar (chữ tắt "?"), không phải nút trống.
  final String? assigneeName;
  final String? assigneeAvatar;

  /// Dòng đầu không có vạch trên.
  final bool first;

  /// Đặt / đổi hạn việc con (Nhóm 2, `tasks.subtask_fields`). null = không
  /// có nút "Hạn" và chip hạn chỉ để xem.
  final VoidCallback? onSetDue;

  /// Tay kéo 24×44 bên trái (Nhóm 2, `tasks.checklist_move`). null = không.
  final Widget? dragHandle;

  bool get _failed => pending?.failed ?? false;

  bool get _inFlight => pending != null && !_failed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final secondary = OmniColors.byBrightness(
      context,
      OmniColors.mutedForeground,
      scheme.onSurfaceVariant,
    );
    final hasAssignee = subtask.assigneeId != null;
    final displayName = assigneeName ?? subtask.assigneeName;

    final Widget? who = hasAssignee
        ? Semantics(
            button: onAssign != null,
            onTap: onAssign,
            label: 'Đổi người làm: ${displayName ?? 'người khác'}',
            excludeSemantics: true,
            child: InkWell(
              onTap: onAssign,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: tapSize,
                height: tapSize,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: OmniAvatar(
                    name: displayName ?? '?',
                    imageUrl: assigneeAvatar ?? subtask.assigneeAvatar,
                    size: 28,
                  ),
                ),
              ),
            ),
          )
        : onAssign == null
        ? null
        : _MiniButton(
            semanticsLabel: 'Giao việc con',
            icon: Icons.add_rounded,
            label: 'Người làm',
            onTap: onAssign!,
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: first
            ? null
            : Border(top: BorderSide(color: OmniColors.trackOf(context))),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 4, 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (dragHandle case final handle?)
              Padding(padding: const EdgeInsets.only(top: 6), child: handle),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _TickButton(
                title: subtask.title,
                done: subtask.done,
                inFlight: _inFlight,
                failed: _failed,
                onTap: enabled
                    ? () {
                        // Rung trước, để người dùng cảm thấy ngay lúc chạm chứ
                        // không phải sau khi mạng quyết định.
                        HapticFeedback.selectionClick();
                        onToggle(!subtask.done);
                      }
                    : null,
              ),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 17),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subtask.title,
                      style: OmniType.body.copyWith(
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                        decoration: subtask.done
                            ? TextDecoration.lineThrough
                            : null,
                        color: subtask.done ? secondary : scheme.onSurface,
                      ),
                    ),
                    if (subtask.description case final note?)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          note,
                          key: const ValueKey('subtask-note'),
                          style: OmniType.caption.copyWith(color: secondary),
                        ),
                      ),
                    if (who != null ||
                        subtask.dueDate != null ||
                        subtask.startDate != null ||
                        onSetDue != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Wrap(
                          spacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            ?who,
                            if (subtask.startDate case final start?)
                              OmniTaskChip.none(
                                'Từ ${Formatters.dayMonth(start)}',
                              ),
                            if (subtask.dueDate != null)
                              _dueChip()
                            else if (onSetDue != null)
                              _MiniButton(
                                semanticsLabel: 'Đặt hạn việc con',
                                icon: Icons.calendar_today_outlined,
                                label: 'Hạn',
                                onTap: onSetDue!,
                              ),
                          ],
                        ),
                      )
                    else
                      const SizedBox(height: 12),
                    if (_failed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: OmniSpacing.sm),
                        child: _FailureNotice(
                          reason: pending!.error!,
                          onRetry: onRetry,
                          onDiscard: onDiscard,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (onMenu != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: IconButton(
                  tooltip: 'Tuỳ chọn việc con',
                  onPressed: onMenu,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(tapSize, tapSize),
                    maximumSize: const Size(tapSize, tapSize),
                    padding: EdgeInsets.zero,
                    foregroundColor: secondary,
                  ),
                  icon: const Icon(Icons.more_vert_rounded, size: 18),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

extension on SubtaskRow {
  /// Chip hạn; đổi được ([onSetDue]) thì chạm vào là đổi / xoá, vùng chạm 44.
  Widget _dueChip() {
    final chip = DueChip.date(due: subtask.dueDate, done: subtask.done);
    final onTap = onSetDue;
    if (onTap == null) return chip;

    return Semantics(
      button: true,
      label: 'Đổi hạn việc con',
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: SubtaskRow.tapSize,
          child: Align(widthFactor: 1, child: chip),
        ),
      ),
    );
  }
}

/// `.mini`: nút nét đứt `#9AA5B8` bo 6, vẽ cao 32 trong vùng chạm 44, chữ
/// 12 w500 màu phụ, biểu tượng 14.
class _MiniButton extends StatelessWidget {
  const _MiniButton({
    required this.semanticsLabel,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final String semanticsLabel;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final secondary = OmniColors.byBrightness(
      context,
      OmniColors.mutedForeground,
      scheme.onSurfaceVariant,
    );

    return Semantics(
      button: true,
      label: semanticsLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: SubtaskRow.tapSize,
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: 1,
            child: CustomPaint(
              key: const ValueKey('subtask-mini-dashed'),
              foregroundPainter: _DashedRRect(OmniTaskTones.of(context).faint),
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: secondary),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: OmniType.micro.copyWith(color: secondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Viền nét đứt 1px bo 6.
class _DashedRRect extends CustomPainter {
  const _DashedRRect(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(6),
        ).deflate(0.5),
      );
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 3), paint);
        d += 6;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRect old) => old.color != color;
}

/// Ô tích vuông 22 bo 6 trong vùng chạm 44. Chưa xong: nền surface, viền 1.5
/// `#9AA5B8`; xong: nền primary + ✓ 14 trắng. Đổi trạng thái thì nảy `tick`
/// 1 → 1.25 → 1 trong 350ms (tắt khi giảm chuyển động).
class _TickButton extends StatefulWidget {
  const _TickButton({
    required this.done,
    required this.inFlight,
    required this.failed,
    required this.title,
    required this.onTap,
  });

  final bool done;
  final bool inFlight;
  final bool failed;
  final String title;
  final VoidCallback? onTap;

  @override
  State<_TickButton> createState() => _TickButtonState();
}

class _TickButtonState extends State<_TickButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );

  static final _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 1.25,
      ).chain(CurveTween(curve: OmniCurves.standard)),
      weight: 40,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.25,
        end: 1.0,
      ).chain(CurveTween(curve: OmniCurves.standard)),
      weight: 60,
    ),
  ]);

  @override
  void didUpdateWidget(_TickButton old) {
    super.didUpdateWidget(old);
    if (widget.done != old.done && OmniMotion.enabled(context)) {
      _pop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final Widget box;
    if (widget.inFlight) {
      // Ô đã hiện trạng thái mới; vòng xoay chỉ nói là còn đang trên đường đi,
      // để người dùng khỏi chạm hai lần.
      box = const SizedBox.square(
        dimension: 22,
        child: Padding(
          padding: EdgeInsets.all(3),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    } else {
      final filled = widget.done && !widget.failed;
      final border = widget.failed
          ? OmniColors.destructive
          : OmniTaskTones.of(context).faint;
      box = Container(
        key: const ValueKey('subtask-tick-box'),
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: filled ? scheme.primary : scheme.surface,
          borderRadius: BorderRadius.circular(6),
          border: filled ? null : Border.all(color: border, width: 1.5),
        ),
        child: widget.done
            ? Icon(
                Icons.check_rounded,
                size: 14,
                color: widget.failed
                    ? OmniColors.destructive
                    : scheme.onPrimary,
              )
            : null,
      );
    }

    return Semantics(
      label: widget.done
          ? 'Bỏ đánh dấu xong việc con'
          : 'Đánh dấu xong việc con',
      value: widget.title,
      onTap: widget.onTap,
      checked: widget.done,
      button: true,
      excludeSemantics: true,
      // GestureDetector chứ không phải InkWell: gợn sóng là một hoạt ảnh nữa
      // chạy sau mỗi lần chạm; ở đây phản hồi là cú rung + ô nảy.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: SizedBox.square(
          dimension: SubtaskRow.tapSize,
          child: Center(
            child: ScaleTransition(scale: _scale.animate(_pop), child: box),
          ),
        ),
      ),
    );
  }
}

/// Một lượt tick không lưu được, và cách xử lý.
///
/// Nói bằng lời với hai lựa chọn rõ ràng. Một công đoạn lặng lẽ bỏ tick là cách
/// một cây đàn bị bỏ sót, nên dòng này ở lại màn hình tới khi người thợ quyết.
class _FailureNotice extends StatelessWidget {
  const _FailureNotice({
    required this.reason,
    required this.onRetry,
    required this.onDiscard,
  });

  final String reason;
  final VoidCallback onRetry;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: OmniIconSize.xs,
              color: OmniColors.dangerTextOf(context),
            ),
            const SizedBox(width: OmniSpacing.xs),
            Expanded(
              child: Text(
                'Chưa lưu được: $reason',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: OmniColors.dangerTextOf(context),
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            TextButton(onPressed: onRetry, child: const Text('Thử lại')),
            const SizedBox(width: OmniSpacing.sm),
            TextButton(onPressed: onDiscard, child: const Text('Bỏ')),
          ],
        ),
      ],
    );
  }
}
