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

/// Nút chính của các màn xác thực: cao 50, bo 10, đổ bóng `primary`; hiện
/// vòng quay thay chữ khi [busy]. [onPressed] null thì nút bị khoá.
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
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: OmniType.input.copyWith(fontWeight: FontWeight.w600),
        ),
        child: busy
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.onPrimary,
                ),
              )
            : Text(label),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: busy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
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
