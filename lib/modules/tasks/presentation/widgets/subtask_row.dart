import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../design/components/components.dart';
import '../../../../design/platform/omni_motion_scope.dart';
import '../../../../design/tokens/tokens.dart';
import '../../application/task_controller.dart';
import '../../domain/task.dart';

/// Một việc con: ô tick, tên, và nút người làm.
///
/// Người dùng đứng ở bàn làm việc với tay bẩn, trong phòng ồn. Hệ quả:
///
///  * Ô tick và nút người làm mỗi cái là một vùng chạm 44×44 riêng — tick nhầm
///    một công đoạn là cây đàn bị đánh dấu xong sai.
///  * Tick rung nhẹ: trong xưởng không nghe được tiếng và có thể đang không
///    nhìn màn hình.
///  * Tên là chỗ chạm để đổi tên / xoá (người giao việc); người làm là nút
///    riêng — vòng nét đứt có + khi chưa ai nhận, avatar khi đã có người.
class SubtaskRow extends StatelessWidget {
  const SubtaskRow({
    super.key,
    required this.subtask,
    required this.pending,
    required this.enabled,
    required this.onToggle,
    required this.onRetry,
    required this.onDiscard,
    this.onEdit,
    this.onAssign,
    this.assigneeName,
    this.assigneeAvatar,
    this.first = false,
  });

  /// Vùng chạm tối thiểu của mỗi nút trong dòng.
  static const double tapSize = 44;

  final Subtask subtask;
  final PendingTick? pending;

  /// Được tick / giao người (`taskAccess.canComplete`). False = chỉ xem.
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final VoidCallback onRetry;
  final VoidCallback onDiscard;

  /// Chạm (hoặc giữ) TÊN để đổi tên / xoá. Null = chỉ đọc.
  final VoidCallback? onEdit;

  /// Mở bảng "Ai làm việc này". Null = nút người làm chỉ hiển thị.
  final VoidCallback? onAssign;

  /// Tên / ảnh người đang làm. Tên null mà [Subtask.assigneeId] có = server
  /// không tra ra tên; nút vẫn là avatar (chữ tắt "?"), không phải vòng trống.
  final String? assigneeName;
  final String? assigneeAvatar;

  /// Dòng đầu không có vạch trên.
  final bool first;

  bool get _failed => pending?.failed ?? false;

  bool get _inFlight => pending != null && !_failed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasAssignee = subtask.assigneeId != null;
    final displayName = assigneeName ?? subtask.assigneeName;
    final title = Text(
      subtask.title,
      style: OmniType.body.copyWith(
        decoration: subtask.done ? TextDecoration.lineThrough : null,
        color: subtask.done ? scheme.onSurfaceVariant : scheme.onSurface,
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: first
            ? null
            : Border(top: BorderSide(color: OmniColors.trackOf(context))),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: tapSize),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TickButton(
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: onEdit,
                    onLongPress: onEdit,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: tapSize),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: title,
                      ),
                    ),
                  ),
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
            Semantics(
              button: onAssign != null,
              label: hasAssignee
                  ? 'Đổi người làm: ${displayName ?? 'người khác'}'
                  : 'Giao việc con',
              excludeSemantics: true,
              child: InkWell(
                onTap: onAssign,
                customBorder: const CircleBorder(),
                child: SizedBox.square(
                  dimension: tapSize,
                  child: Center(
                    child: hasAssignee
                        ? OmniAvatar(
                            name: displayName ?? '?',
                            imageUrl: assigneeAvatar ?? subtask.assigneeAvatar,
                            size: 22,
                          )
                        : const OmniDashedCircle(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ô tick tròn 20 trong vùng chạm 44. "Xong": nền primary + dấu ✓ trắng, nảy
/// 0.6 → 1.15 → 1 trong 350ms (tắt khi giảm chuyển động).
class _TickButton extends StatefulWidget {
  const _TickButton({
    required this.done,
    required this.inFlight,
    required this.failed,
    required this.onTap,
  });

  final bool done;
  final bool inFlight;
  final bool failed;
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
    TweenSequenceItem(tween: Tween(begin: 0.6, end: 1.15), weight: 60),
    TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 40),
  ]);

  @override
  void didUpdateWidget(_TickButton old) {
    super.didUpdateWidget(old);
    if (widget.done && !old.done && OmniMotion.enabled(context)) {
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
        dimension: 20,
        child: Padding(
          padding: EdgeInsets.all(2),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    } else {
      // "Xong" mang MÀU CHÍNH, cái phân biệt với "chưa" là dấu ✓ đặc trên nền
      // đặc chứ không phải sắc màu.
      final filled = widget.done && !widget.failed;
      final border = widget.failed
          ? OmniColors.destructive
          : (widget.done
                ? scheme.primary
                : OmniColors.controlBorderOf(context));
      box = Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: filled ? scheme.primary : Colors.transparent,
          border: Border.all(color: border, width: 1.5),
          shape: BoxShape.circle,
        ),
        child: widget.done
            ? Icon(
                Icons.check_rounded,
                size: 14,
                color: widget.failed ? OmniColors.destructive : Colors.white,
              )
            : null,
      );
    }

    return Semantics(
      label: 'Xong',
      checked: widget.done,
      button: true,
      excludeSemantics: true,
      // GestureDetector chứ không phải InkWell: gợn sóng là một hoạt ảnh nữa
      // chạy sau mỗi lần chạm; ở đây phản hồi là cú rung + ô đổi trạng thái.
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
