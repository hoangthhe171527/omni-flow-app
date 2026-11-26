import 'package:flutter/material.dart';

import '../../design/components/components.dart';
import '../../design/platform/omni_motion_scope.dart';
import '../../design/tokens/tokens.dart';

/// Shown only while the session is being restored from storage — a fraction of
/// a second in practice. It exists so the router never has to guess where to
/// send a user whose auth state isn't known yet.
///
/// Logo trần ở đúng chỗ của màn mở app, giữa hai vòng hào quang; thay vòng quay
/// là hai vòng sáng lần lượt tỏa ra từ mép logo (mỗi giây một vòng), không phủ
/// lên logo. Không chữ: chỉ nói "đang làm", không nói bao lâu — khôi phục khi
/// mất mạng có thể thử lại nhiều lần. Giảm chuyển động thì đứng yên.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  /// Một chu kỳ tỏa; hai vòng lệch nhau nửa chu kỳ.
  static const pulsePeriod = Duration(milliseconds: 2000);

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: SplashPage.pulsePeriod,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (OmniMotion.enabled(context)) {
      if (!_pulse.isAnimating) _pulse.repeat();
    } else {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final moving = OmniMotion.enabled(context);
    return Scaffold(
      backgroundColor: dark ? OmniColors.ink : OmniColors.background,
      body: moving
          ? AnimatedBuilder(
              animation: _pulse,
              builder: (_, _) => OmniSplash(pulse: _pulse.value),
            )
          : const OmniSplash(),
    );
  }
}
