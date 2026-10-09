import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/components/components.dart';
import '../../design/platform/omni_motion_scope.dart';

/// Hiệu ứng mở app, phủ lên TOÀN BỘ app một lần mỗi lần khởi động.
///
/// Vì sao là lớp phủ chứ không phải chính màn splash của router: màn splash
/// chỉ sống chừng nào phiên còn đang khôi phục, mà khôi phục thường xong trong
/// vài trăm ms — đặt hiệu ứng ở đó thì hoặc nó bị cắt ngang giữa chừng, hoặc
/// phải bắt router CHỜ nó. Ở đây hai việc chạy song song: router khôi phục
/// phiên và điều hướng ngay bên dưới, còn hiệu ứng dựng hình 1,8 giây rồi bay.
/// Không có lượt điều hướng nào bị làm chậm; thứ duy nhất người dùng "chờ" là
/// chính hiệu ứng, và chỉ ở lần mở đầu tiên.
///
/// Pha bay (1850ms → hết): nếu màn đích có logo neo bằng [BrandAnchor] (header
/// các tab gốc, màn đăng nhập), logo bay tới đúng chỗ đó, nền splash tan thành
/// trong suốt, khẩu hiệu và vòng sáng mờ đi — chữ "Viomni" bay theo nếu đích
/// có chữ, không thì mờ và trượt lên. Không có neo thì cả lớp phủ mờ dần.
///
/// Nếu khôi phục phiên lâu hơn hiệu ứng (mạng chậm), bên dưới là [SplashPage]
/// vẽ đúng khung hình cuối của hiệu ứng, nên lúc mờ đi không có cú giật nào.
///
/// Bỏ qua hẳn khi máy bật "giảm chuyển động" — thiết kế ghi rõ "tắt hết".
class LaunchSplash extends StatefulWidget {
  const LaunchSplash({super.key, required this.child});

  final Widget child;

  /// Tổng thời lượng lớp phủ: dựng hình 1800 + 650 (nghỉ 50, bay 600).
  static const total = Duration(milliseconds: 1800 + 650);

  /// Mốc bắt đầu bay — giữ khung hoàn chỉnh một nhịp 50ms sau phần dựng hình.
  static const _flyStartMs = 1850;

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
  AnimationController? _controller;
  bool _visible = false;

  /// Đích đã đọc lúc bắt đầu bay (đọc MỘT lần). Null trước mốc bay.
  _Targets? _targets;

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

    _controller = AnimationController(vsync: this, duration: LaunchSplash.total)
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

  /// Đọc rect của logo đang neo trên màn đích. Null nếu không có neo, neo chưa
  /// bố cục, hoặc app chạy không có `ProviderScope` (vài bài kiểm).
  Rect? _anchorRect() {
    final ProviderContainer container;
    try {
      container = ProviderScope.containerOf(context, listen: false);
    } on StateError {
      return null;
    }
    final box = container
        .read(brandAnchorProvider)
        ?.currentContext
        ?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    if (box.size.isEmpty) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  _Targets _readTargets() {
    final anchor = _anchorRect();
    if (anchor == null) return const _Targets(null, null);
    // Logo là ô vuông bên trái neo. Neo rộng hẳn hơn cao là header (logo 30 +
    // khoảng 8 + chữ): phần còn lại bên phải là chỗ của chữ.
    final side = anchor.height;
    final logo = Rect.fromLTWH(anchor.left, anchor.top, side, side);
    final hasWord = anchor.width > side * 1.5;
    final word = hasWord
        ? Rect.fromLTRB(
            anchor.left + side + 8 * side / 30,
            anchor.top,
            anchor.right,
            anchor.bottom,
          )
        : null;
    return _Targets(logo, word);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (!_visible || controller == null) return widget.child;

    final totalMs = LaunchSplash.total.inMilliseconds;
    final splashMs = OmniSplash.timeline.inMilliseconds;
    const flyStart = LaunchSplash._flyStartMs;

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        // Chặn chạm trong lúc phủ: bên dưới là một màn người dùng chưa thấy.
        AbsorbPointer(
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final ms = controller.value * totalMs;
              final progress = ms / splashMs;
              if (ms < flyStart) return OmniSplash(progress: progress);

              final targets = _targets ??= _readTargets();
              final linear = ((ms - flyStart) / (totalMs - flyStart)).clamp(
                0.0,
                1.0,
              );
              if (targets.logo == null) {
                // Không có logo để bay tới: mờ dần cả lớp phủ như cũ.
                return Opacity(
                  opacity: 1 - linear,
                  child: OmniSplash(progress: progress),
                );
              }
              return OmniSplash(
                progress: progress,
                flight: SplashFlight(
                  t: OmniSplash.flightCurve.transform(linear),
                  logoTarget: targets.logo,
                  wordTarget: targets.word,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Targets {
  const _Targets(this.logo, this.word);

  final Rect? logo;
  final Rect? word;
}
