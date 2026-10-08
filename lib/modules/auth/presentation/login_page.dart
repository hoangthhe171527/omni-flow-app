import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../application/login_controller.dart';

/// Màn đăng nhập theo `MLogin.dc.html`: khối mực phía trên mang logo và lời
/// chào, biểu mẫu trắng phía dưới, liên kết phụ ở đáy.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref
        .read(loginControllerProvider.notifier)
        .submit(email: _email.text.trim(), password: _password.text);
    // Navigation is the router's job: a successful login flips the session
    // status and the redirect takes the user to their first visible tab.
  }

  Future<void> _openLink(Uri url) async {
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (opened || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Không mở được liên kết. Vui lòng thử lại.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginControllerProvider);
    final scheme = Theme.of(context).colorScheme;
    final inputText = OmniType.input.copyWith(
      fontWeight: FontWeight.w500,
      color: scheme.onSurface,
    );

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _LoginHero(),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    OmniSpacing.xxl,
                    28,
                    OmniSpacing.xxl,
                    0,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OmniField(
                          label: 'Email làm việc',
                          error: state.errorFor('email'),
                          child: TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            textInputAction: TextInputAction.next,
                            style: inputText,
                            decoration: const InputDecoration(
                              hintText: 'ten@congty.vn',
                              prefixIcon: Icon(
                                Icons.mail_outline_rounded,
                                size: OmniIconSize.md,
                              ),
                            ),
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.isEmpty) return 'Vui lòng nhập email';
                              if (!text.contains('@')) {
                                return 'Email chưa hợp lệ';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 18),
                        OmniField(
                          label: 'Mật khẩu',
                          error: state.errorFor('password'),
                          child: TextFormField(
                            controller: _password,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            style: inputText,
                            decoration: InputDecoration(
                              // Not "••••••••": a dotted hint reads as an
                              // already-filled field, and users tap "Đăng nhập"
                              // on an empty form.
                              hintText: 'Nhập mật khẩu',
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                                size: OmniIconSize.md,
                              ),
                              suffixIcon: IconButton(
                                // Nhãn nói cả TRẠNG THÁI: nếu không, người dùng
                                // screen reader không có cách nào biết mật khẩu
                                // của mình đang hiện trên màn hình hay không.
                                tooltip: _obscure
                                    ? 'Hiện mật khẩu'
                                    : 'Ẩn mật khẩu',
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: OmniIconSize.lg,
                                ),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (value) => (value ?? '').isEmpty
                                ? 'Vui lòng nhập mật khẩu'
                                : null,
                          ),
                        ),

                        if (state.error != null) ...[
                          const SizedBox(height: 18),
                          _LoginError(message: state.error!),
                        ],

                        const SizedBox(height: 22),
                        FilledButton(
                          onPressed: state.submitting ? null : _submit,
                          style: FilledButton.styleFrom(
                            textStyle: OmniType.input.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: state.submitting
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: scheme.onPrimary,
                                  ),
                                )
                              : const Text('Đăng nhập'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: OmniSpacing.section),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  OmniSpacing.xxl,
                  0,
                  OmniSpacing.xxl,
                  OmniSpacing.xl,
                ),
                child: Column(
                  children: [
                    Text(
                      AppConfig.appName,
                      style: OmniType.micro.copyWith(
                        fontWeight: FontWeight.w400,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: OmniSpacing.xs),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: OmniSpacing.xs,
                      children: [
                        _FooterLink(
                          label: 'Quên mật khẩu',
                          onTap: () => _openLink(AppConfig.forgotPasswordUrl),
                        ),
                        _FooterLink(
                          label: 'Quyền riêng tư',
                          onTap: () => _openLink(AppConfig.privacyPolicyUrl),
                        ),
                        _FooterLink(
                          label: 'Hỗ trợ',
                          onTap: () => _openLink(AppConfig.supportUrl),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Khối mực phía trên: hai vòng quỹ đạo và chấm vàng trang trí ở góc phải,
/// logo, lời chào.
class _LoginHero extends StatelessWidget {
  const _LoginHero();

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;

    return Container(
      // 300dp trong khung thiết kế, đã gồm thanh trạng thái 47dp.
      constraints: BoxConstraints(minHeight: 253 + top),
      color: OmniColors.ink,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(right: -90, top: -60, child: _ring(300)),
          Positioned(right: -30, top: 0, child: _ring(180)),
          const Positioned(
            right: 104,
            top: 46,
            child: SizedBox.square(
              dimension: 10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: OmniColors.sun,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              OmniSpacing.xxl,
              top + 59,
              OmniSpacing.xxl,
              28,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 512),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const OmniBrandMark(
                      size: 56,
                      onInk: true,
                      semanticLabel: 'Viomni',
                    ),
                    const SizedBox(height: OmniSpacing.xl),
                    Text(
                      'Chào mừng trở lại',
                      style: OmniType.displayLg.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: OmniSpacing.sm),
                    Text(
                      'Nhập thông tin để tiếp tục xử lý công việc và hỗ trợ '
                      'khách hàng.',
                      style: OmniType.bodyStrong.copyWith(
                        fontWeight: FontWeight.w400,
                        height: 22 / 15,
                        color: OmniColors.inkMutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _ring(double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: OmniColors.inkLine, width: 1.5),
    ),
  );
}

/// Hộp báo lỗi: nền đỏ nhạt, chữ đỏ đậm, đọc được bởi trình đọc màn hình ngay
/// khi hiện ra (`role="alert"` trong thiết kế).
class _LoginError extends StatelessWidget {
  const _LoginError({required this.message});

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

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        textStyle: OmniType.caption.copyWith(fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    );
  }
}
