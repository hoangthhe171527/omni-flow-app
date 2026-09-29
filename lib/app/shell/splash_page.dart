import 'package:flutter/material.dart';

import '../../design/components/components.dart';
import '../../design/tokens/tokens.dart';

/// Shown only while the session is being restored from storage — a fraction of
/// a second in practice. It exists so the router never has to guess where to
/// send a user whose auth state isn't known yet.
///
/// Vẽ đúng khung hình CUỐI của hiệu ứng mở app ([OmniSplash] tĩnh): lớp hiệu
/// ứng (`LaunchSplash`) mờ đi để lộ ra chính hình này nếu phiên còn đang khôi
/// phục, nên không có cú giật. Vạch tiến độ chỉ nói "đang làm", không nói bao
/// lâu — khôi phục khi mất mạng có thể thử lại nhiều lần.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: OmniColors.ink,
      body: OmniSplash(
        footer: SizedBox(
          width: 120,
          child: LinearProgressIndicator(
            minHeight: 3,
            color: OmniColors.orbit,
            backgroundColor: OmniColors.inkRaised,
            borderRadius: OmniRadius.pillAll,
          ),
        ),
      ),
    );
  }
}
