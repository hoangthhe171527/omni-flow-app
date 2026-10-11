import 'package:flutter/widgets.dart';

import '../platform/omni_motion_scope.dart';
import '../tokens/omni_motion.dart';

/// `rise` của bản mẫu Việc mới: mờ → rõ và trượt lên 8px trong 350ms
/// cubic(.2,.8,.2,1), chạy MỘT lần khi khối vào cây. [delay] để các khối kế
/// nhau lệch 50ms.
///
/// Giảm chuyển động: hiện ngay ở trạng thái cuối, không có khung chờ nào.
class OmniRise extends StatefulWidget {
  const OmniRise({super.key, this.delay = Duration.zero, required this.child});

  static const duration = Duration(milliseconds: 350);
  static const step = Duration(milliseconds: 50);

  final Duration delay;
  final Widget child;

  @override
  State<OmniRise> createState() => _OmniRiseState();
}

class _OmniRiseState extends State<OmniRise>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _t;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    final total = OmniRise.duration + widget.delay;
    _controller = AnimationController(vsync: this, duration: total);
    final start = widget.delay.inMicroseconds / total.inMicroseconds;
    _t = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, 1, curve: OmniCurves.standard),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (OmniMotion.enabled(context)) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _t,
    child: widget.child,
    builder: (context, child) => Opacity(
      opacity: _t.value.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, 8 * (1 - _t.value)),
        child: child,
      ),
    ),
  );
}

/// Nhấn xuống thì co còn 97% (`button:active{transform:scale(.97)}`), thả ra
/// thì về, 200ms cubic(.2,.8,.2,1). Không chặn chạm của con.
///
/// Giảm chuyển động: không co.
class OmniPressScale extends StatefulWidget {
  const OmniPressScale({super.key, required this.child});

  final Widget child;

  @override
  State<OmniPressScale> createState() => _OmniPressScaleState();
}

class _OmniPressScaleState extends State<OmniPressScale> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final motion = OmniMotion.enabled(context);

    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: motion && _down ? .97 : 1,
        duration: motion ? OmniDuration.base : Duration.zero,
        curve: OmniCurves.standard,
        child: widget.child,
      ),
    );
  }
}
