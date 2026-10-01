import 'package:flutter/material.dart';

import '../../design/components/components.dart';
import '../../design/platform/omni_motion_scope.dart';

/// Hiệu ứng mở app, phủ lên TOÀN BỘ app một lần mỗi lần khởi động.
///
/// Vì sao là lớp phủ chứ không phải chính màn splash của router: màn splash
/// chỉ sống chừng nào phiên còn đang khôi phục, mà khôi phục thường xong trong
/// vài trăm ms — đặt hiệu ứng ở đó thì hoặc nó bị cắt ngang giữa chừng, hoặc
/// phải bắt router CHỜ nó. Ở đây hai việc chạy song song: router khôi phục
/// phiên và điều hướng ngay bên dưới, còn hiệu ứng chạy đủ ~1,7 giây rồi mờ đi,
/// để lộ ra màn đã sẵn sàng. Không có lượt điều hướng nào bị làm chậm; thứ duy
/// nhất người dùng "chờ" là chính hiệu ứng, và chỉ ở lần mở đầu tiên.
///
/// Nếu khôi phục phiên lâu hơn hiệu ứng (mạng chậm), bên dưới là [SplashPage]
/// vẽ đúng khung hình cuối của hiệu ứng, nên lúc mờ đi không có cú giật nào.
///
/// Bỏ qua hẳn khi máy bật "giảm chuyển động" — thiết kế ghi rõ "tắt hết".
class LaunchSplash extends StatefulWidget {
  const LaunchSplash({super.key, required this.child});

  final Widget child;

  /// Đã chạy trong tiến trình này chưa. Tĩnh chứ không nằm trong State: cây
  /// widget có thể dựng lại (đổi theme, đổi tenant dựng lại router) mà hiệu
  /// ứng không được chạy lần hai — "chỉ lần mở đầu, lần sau vào thẳng".
  static bool _playedThisLaunch = false;

  /// Cho bài kiểm dựng lại trạng thái "vừa mở app".
  @visibleForTesting
  static void resetForTest() => _playedThisLaunch = false;

  @override
  State<LaunchSplash> createState() => _LaunchSplashState();
}

class _LaunchSplashState extends State<LaunchSplash>
    with SingleTickerProviderStateMixin {
  static const _fade = Duration(milliseconds: 250);

  AnimationController? _controller;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _visible = !LaunchSplash._playedThisLaunch;
    LaunchSplash._playedThisLaunch = true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_visible || _controller != null) return;

    if (!OmniMotion.enabled(context)) {
      _visible = false;
      return;
    }

    _controller =
        AnimationController(vsync: this, duration: OmniSplash.timeline + _fade)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed && mounted) {
              setState(() => _visible = false);
            }
          })
          ..forward();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (!_visible || controller == null) return widget.child;

    final total = (OmniSplash.timeline + _fade).inMilliseconds;
    final splashEnd = OmniSplash.timeline.inMilliseconds / total;

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        // Chặn chạm trong lúc phủ: bên dưới là một màn người dùng chưa thấy.
        AbsorbPointer(
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final t = controller.value;
              final opacity = t <= splashEnd
                  ? 1.0
                  : 1 - (t - splashEnd) / (1 - splashEnd);
              return Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: OmniSplash(progress: (t / splashEnd).clamp(0.0, 1.0)),
              );
            },
          ),
        ),
      ],
    );
  }
}
