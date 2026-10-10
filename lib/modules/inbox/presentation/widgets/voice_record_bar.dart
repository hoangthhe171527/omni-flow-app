import 'package:flutter/material.dart';

import '../../../../design/platform/omni_motion_scope.dart';
import '../../../../design/tokens/tokens.dart';

/// Thời lượng tối đa một bản ghi; tới mốc này composer tự dừng.
const kVoiceMaxDuration = Duration(minutes: 5);

/// Bản ghi ngắn hơn thì bỏ ("Ghi âm quá ngắn.").
const kVoiceMinDuration = Duration(seconds: 1);

/// `mm:ss`, phút không giới hạn hai chữ số (5 phút là trần).
String formatVoiceElapsed(Duration d) {
  final minutes = d.inMinutes.toString().padLeft(2, '0');
  final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// Thanh đang ghi âm, thay hàng nhập của composer: Huỷ · chấm đỏ + mm:ss ·
/// nút Gửi. Đang ghi thì các nút khác của composer không có mặt.
class VoiceRecordBar extends StatelessWidget {
  const VoiceRecordBar({
    super.key,
    required this.elapsed,
    required this.stopped,
    required this.onCancel,
    required this.sendButton,
  });

  final Duration elapsed;

  /// Đã tự dừng ở [kVoiceMaxDuration]: giữ thanh, chờ người dùng Gửi/Huỷ.
  final bool stopped;
  final VoidCallback? onCancel;
  final Widget sendButton;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = OmniColors.byBrightness(
      context,
      OmniColors.muted,
      scheme.surfaceContainerHighest,
    );
    final time = formatVoiceElapsed(elapsed);
    final status = stopped ? 'Đã đủ tối đa 5 phút' : 'Đang ghi âm…';

    return Row(
      children: [
        IconButton(
          onPressed: onCancel,
          tooltip: 'Huỷ ghi âm',
          padding: EdgeInsets.zero,
          style: IconButton.styleFrom(
            fixedSize: const Size(44, 44),
            minimumSize: const Size(44, 44),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: Icon(
            Icons.delete_outline_rounded,
            size: OmniIconSize.xl,
            color: onCancel == null
                ? Theme.of(context).disabledColor
                : scheme.error,
          ),
        ),
        Expanded(
          child: Semantics(
            label: '$status, $time',
            excludeSemantics: true,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: fill,
                borderRadius: const BorderRadius.all(Radius.circular(18)),
              ),
              child: Row(
                children: [
                  _RecordDot(color: scheme.error, blinking: !stopped),
                  const SizedBox(width: 8),
                  Text(
                    time,
                    style: OmniType.body.copyWith(
                      color: scheme.onSurface,
                      fontFeatures: OmniType.tabular,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: OmniType.caption.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 2),
        sendButton,
      ],
    );
  }
}

/// Chấm đỏ nhấp nháy chu kỳ 1s; tắt chuyển động (hoặc đã dừng) thì đứng yên.
class _RecordDot extends StatefulWidget {
  const _RecordDot({required this.color, required this.blinking});

  final Color color;
  final bool blinking;

  @override
  State<_RecordDot> createState() => _RecordDotState();
}

class _RecordDotState extends State<_RecordDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_RecordDot old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final run = widget.blinking && OmniMotion.enabled(context);
    if (run && !_blink.isAnimating) {
      _blink.repeat(reverse: true);
    } else if (!run && _blink.isAnimating) {
      _blink
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = SizedBox.square(
      dimension: 10,
      child: DecoratedBox(
        key: const ValueKey('voice-record-dot'),
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
    if (!widget.blinking || !OmniMotion.enabled(context)) return dot;
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.25).animate(_blink),
      child: dot,
    );
  }
}
