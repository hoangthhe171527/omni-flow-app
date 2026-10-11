import 'package:flutter/material.dart';

import '../../../../design/platform/omni_motion_scope.dart';
import '../../../../design/tokens/tokens.dart';

/// Tim lớn bay lên khi bấm đúp một tin để thả ❤️ (`Thread.dc.html` `burst
/// .8s`): hiện ra phóng to, nảy về cỡ thật, rồi mờ dần và bay lên 28px.
///
/// Chỉ để nhìn: không nhận chạm, không đọc cho trình đọc màn hình (viên ❤️
/// dưới tin mới là thông tin). Tắt chuyển động thì không dựng gì cả — người
/// gọi cũng không nên dựng, đây chỉ là lưới an toàn.
class HeartBurst extends StatefulWidget {
  const HeartBurst({super.key, this.onDone});

  static const duration = Duration(milliseconds: 800);
  static const size = 44.0;

  /// Gọi khi bay xong, để người gọi gỡ widget.
  final VoidCallback? onDone;

  @override
  State<HeartBurst> createState() => _HeartBurstState();
}

class _HeartBurstState extends State<HeartBurst>
    with SingleTickerProviderStateMixin {
  static const _curve = Cubic(.2, .8, .2, 1);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: HeartBurst.duration,
  );

  // Khung hình theo bản mẫu: 0% mờ ×.3 → 25% hiện ×1.25 → 45% ×.95 →
  // 70% hiện ×1 → 100% mờ ×.9, lên 28px.
  late final Animation<double> _opacity = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: _curve)),
      weight: 25,
    ),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 45),
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: _curve)),
      weight: 30,
    ),
  ]).animate(_controller);

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: .3, end: 1.25).chain(CurveTween(curve: _curve)),
      weight: 25,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.25, end: .95).chain(CurveTween(curve: _curve)),
      weight: 20,
    ),
    TweenSequenceItem(
      tween: Tween(begin: .95, end: 1.0).chain(CurveTween(curve: _curve)),
      weight: 25,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: .9).chain(CurveTween(curve: _curve)),
      weight: 30,
    ),
  ]).animate(_controller);

  late final Animation<double> _lift = TweenSequence<double>([
    TweenSequenceItem(tween: ConstantTween(0.0), weight: 70),
    TweenSequenceItem(
      tween: Tween(begin: 0.0, end: -28.0).chain(CurveTween(curve: _curve)),
      weight: 30,
    ),
  ]).animate(_controller);

  @override
  void initState() {
    super.initState();
    _controller.forward().whenComplete(() {
      if (mounted) widget.onDone?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!OmniMotion.enabled(context)) return const SizedBox.shrink();
    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, _lift.value),
            child: Transform.scale(
              scale: _scale.value,
              child: Opacity(opacity: _opacity.value, child: child),
            ),
          ),
          child: const Icon(
            Icons.favorite,
            size: HeartBurst.size,
            color: OmniColors.heart,
          ),
        ),
      ),
    );
  }
}
