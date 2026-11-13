import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/error/app_exception.dart';
import '../../../design/platform/omni_motion_scope.dart';
import '../../../design/tokens/tokens.dart';
import '../application/password_strength.dart';
import '../auth_module.dart';
import '../data/auth_onboarding_api.dart';
import 'widgets/auth_widgets.dart';

/// Màn quên mật khẩu (`#s-auth-forgot`): nút quay lại `OmniGlassCircle`, quy
/// trình 2 bước rõ ràng trong thẻ nhóm bo 18 (nhập email → kiểm tra hộp thư kèm
/// thẻ email nhận + nút đổi email nhanh và bộ đếm lùi `tabularFigures`).
///
/// API trả 204 dù email có tồn tại hay không, nên màn này luôn báo trạng thái
/// đã gửi như nhau để không lộ địa chỉ nào có tài khoản.
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage>
    with SingleTickerProviderStateMixin {
  static const _resendSeconds = 30;

  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();

  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  Timer? _timer;
  bool _busy = false;
  bool _sent = false;
  String _sentTo = '';
  // Đếm ngược chỉ dựng lại nút Gửi lại, không dựng lại cả trang mỗi giây.
  final ValueNotifier<int> _left = ValueNotifier<int>(0);
  String? _error;
  String? _fieldError;

  @override
  void dispose() {
    _timer?.cancel();
    _left.dispose();
    _shake.dispose();
    _email.dispose();
    super.dispose();
  }

  void _shakeIfAllowed() {
    if (!OmniMotion.enabled(context)) return;
    _shake.forward(from: 0);
  }

  void _startCountdown() {
    _timer?.cancel();
    _left.value = _resendSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      _left.value--;
      if (_left.value <= 0) timer.cancel();
    });
  }

  Future<void> _send(String email) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _fieldError = null;
    });
    try {
      await ref.read(authOnboardingApiProvider).forgotPassword(email);
    } on ValidationException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _fieldError = error.firstFor('email');
        _error = _fieldError == null ? error.message : null;
      });
      _shakeIfAllowed();
      return;
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _sent = true;
      _sentTo = email;
    });
    _startCountdown();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!_formKey.currentState!.validate()) {
      _shakeIfAllowed();
      return;
    }
    FocusScope.of(context).unfocus();
    await _send(_email.text.trim());
  }

  void _changeEmail() {
    if (_busy) return;
    _timer?.cancel();
    _left.value = 0;
    setState(() {
      _sent = false;
      _error = null;
    });
  }

  Future<void> _openMail() async {
    var opened = false;
    try {
      opened = await launchUrl(Uri(scheme: 'mailto'));
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không mở được ứng dụng email.')),
      );
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(AuthModule.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AuthScaffold(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthSubBar(onBack: _back),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: OmniMotion.of(context).base,
            child: _sent ? _buildSent(scheme) : _buildForm(scheme),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(ColorScheme scheme) {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('forgot-form'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.lock_reset_rounded,
                size: OmniIconSize.xl,
                color: scheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Quên mật khẩu?',
            style: OmniType.largeTitle.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Nhập email làm việc để nhận liên kết khôi phục mật khẩu.',
            style: OmniType.bodySm.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 22),
          AuthFieldGroup(
            children: [
              AuthGroupField(
                controller: _email,
                label: 'Email làm việc',
                hint: 'ten@congty.vn',
                icon: Icons.mail_outline_rounded,
                shake: _shake,
                serverError: _fieldError,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.email],
                onSubmitted: (_) => _submit(),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'Vui lòng nhập email';
                  if (!looksLikeEmail(text)) return 'Email chưa hợp lệ';
                  return null;
                },
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            AuthErrorBox(message: _error!),
          ],
          const SizedBox(height: 22),
          AuthPrimaryButton(
            label: 'Gửi liên kết',
            busy: _busy,
            onPressed: _busy ? null : _submit,
          ),
        ],
      ),
    );
  }

  Widget _buildSent(ColorScheme scheme) {
    return Column(
      key: const ValueKey('forgot-sent'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.mark_email_read_outlined,
              size: OmniIconSize.xl,
              color: scheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Kiểm tra email',
          style: OmniType.largeTitle.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Semantics(
          liveRegion: true,
          child: Text(
            'Đã gửi tới $_sentTo',
            style: OmniType.bodySm.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 16),
        Material(
          color: scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.mail_outline_rounded,
                    size: OmniIconSize.md,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _sentTo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: OmniType.bodySm.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                      Text(
                        'Liên kết khôi phục có hiệu lực 30 phút',
                        style: OmniType.micro.copyWith(
                          fontWeight: FontWeight.w400,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : _changeEmail,
                  style: TextButton.styleFrom(
                    textStyle: OmniType.caption.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Đổi email'),
                ),
              ],
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          AuthErrorBox(message: _error!),
        ],
        const SizedBox(height: 22),
        AuthPrimaryButton(label: 'Mở ứng dụng email', onPressed: _openMail),
        const SizedBox(height: 12),
        ValueListenableBuilder<int>(
          valueListenable: _left,
          builder: (context, left, _) => OutlinedButton(
            onPressed: left <= 0 && !_busy ? () => _send(_sentTo) : null,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: const StadiumBorder(),
              textStyle: OmniType.bodyStrong.copyWith(
                fontFeatures: OmniType.tabular,
              ),
            ),
            child: _busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                  )
                : Text(left > 0 ? 'Gửi lại sau $left giây' : 'Gửi lại email'),
          ),
        ),
      ],
    );
  }
}
