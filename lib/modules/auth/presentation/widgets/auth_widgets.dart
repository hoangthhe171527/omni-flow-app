import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/app_config.dart';
import '../../../../design/tokens/tokens.dart';

class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outlineVariant;
    return Row(
      children: [
        Expanded(child: Divider(color: color)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: OmniSpacing.md),
          child: Text(
            'hoặc',
            style: OmniType.caption.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: Divider(color: color)),
      ],
    );
  }
}

class AuthGoogleGlyph extends StatelessWidget {
  const AuthGoogleGlyph({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      excludeSemantics: true,
      child: Text(
        'G',
        style: OmniType.title.copyWith(
          color: const Color(0xFF4285F4),
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    );
  }
}

/// Hộp báo lỗi: nền đỏ nhạt, chữ đỏ đậm, đọc được bởi trình đọc màn hình ngay
/// khi hiện ra (`role="alert"` trong thiết kế).
class AuthErrorBox extends StatelessWidget {
  const AuthErrorBox({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = OmniColors.dangerTextOf(context);

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: OmniSpacing.md,
        ),
        decoration: BoxDecoration(
          color: dark
              ? OmniColors.dangerTextDark.withValues(alpha: 0.12)
              : OmniColors.dangerSoft,
          borderRadius: OmniRadius.mdAll,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                Icons.error_outline_rounded,
                size: OmniIconSize.md,
                color: fg,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: OmniType.body.copyWith(height: 20 / 14, color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nút chính của các màn xác thực: nút viền xanh viên thuốc cao 50 (gu
/// người dùng: không tô đặc); hiện vòng quay thay chữ khi [busy]. [onPressed]
/// null thì nút bị khoá.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        shape: const StadiumBorder(),
        textStyle: OmniType.input.copyWith(fontWeight: FontWeight.w600),
      ),
      child: busy
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator.adaptive(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
              ),
            )
          : Text(label),
    );
  }
}

/// Nền của các màn xác thực (viomni-apple-uiux.html `.authbg`): hai quầng
/// màu mờ — màu chủ đạo góc trên trái, xanh trời góc dưới phải — trên nền
/// màn, để phần kính phía trên có thứ để "khúc xạ".
class AuthBackdrop extends StatelessWidget {
  const AuthBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    // Lấp đầy màn: thân Scaffold cho ràng buộc lỏng, nền phải phủ tới đáy.
    return SizedBox.expand(
      child: DecoratedBox(
        key: const Key('auth-backdrop'),
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.7, -0.8),
            radius: 0.9,
            colors: [
              primary.withValues(alpha: .22),
              primary.withValues(alpha: 0),
            ],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.8, 0.7),
              radius: 1.0,
              colors: [
                const Color(0xFF2DABFF).withValues(alpha: .20),
                const Color(0xFF2DABFF).withValues(alpha: 0),
              ],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Nút Google viền mảnh dùng chung cho đăng nhập / đăng ký.
class AuthGoogleButton extends StatelessWidget {
  const AuthGoogleButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: const ValueKey('google-sign-in'),
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        shape: const StadiumBorder(),
      ),
      icon: busy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator.adaptive(strokeWidth: 2),
            )
          : const AuthGoogleGlyph(),
      label: Text(label),
    );
  }
}

/// Liên kết "Chính sách bảo mật" ở chân màn đăng nhập/đăng ký — cửa hàng ứng
/// dụng đòi chính sách luôn mở được từ màn đầu tiên người dùng thấy.
class AuthPrivacyLink extends StatelessWidget {
  const AuthPrivacyLink({super.key});

  Future<void> _open(BuildContext context) async {
    final opened = await launchUrl(
      AppConfig.privacyPolicyUrl,
      mode: LaunchMode.externalApplication,
    );
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Không mở được liên kết. Vui lòng thử lại.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InkWell(
        key: const ValueKey('privacy-link'),
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Text(
            'Chính sách bảo mật',
            style: OmniType.micro.copyWith(
              fontWeight: FontWeight.w400,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
