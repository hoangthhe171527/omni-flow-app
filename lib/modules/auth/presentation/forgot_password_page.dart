import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/error/app_exception.dart';
import '../../../design/platform/omni_motion_scope.dart';
import '../../../design/tokens/tokens.dart';
import '../application/password_strength.dart';
import '../auth_module.dart';
import '../data/auth_onboarding_api.dart';
import 'widgets/auth_widgets.dart';

/// Màn quên mật khẩu (artifact "Màn xác thực" duyệt 26/11), hai bước:
/// 1. một ô email (điền sẵn email vừa gõ ở màn đăng nhập, bàn phím bật sẵn) +
///    "Gửi liên kết đặt lại";
/// 2. "Kiểm tra email": một nút chính "Mở ứng dụng email" ở đáy; gửi lại (đếm
///    ngược m:ss) và đổi email là nút chữ.
///
/// API trả 204 dù email có tồn tại hay không, nên màn này luôn báo trạng thái
/// đã gửi như nhau để không lộ địa chỉ nào có tài khoản.
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key, this.initialEmail});

  /// Email đã gõ ở màn đăng nhập (nếu có).
  final String? initialEmail;

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage>
    with SingleTickerProviderStateMixin {
  static const _resendSeconds = 30;

  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail ?? '');

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
    return AuthScaffold(
      top: 4,
      footer: _sent ? _sentActions() : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthSubBar(onBack: _back),
          const SizedBox(height: 4),
          AnimatedSwitcher(
            duration: OmniMotion.of(context).base,
            child: _sent ? _sentBody() : _form(),
          ),
        ],
      ),
    );
  }

  Widget _form() {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('forgot-form'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text('Quên mật khẩu', style: authTitleStyle(context)),
          ),
          const SizedBox(height: 18),
          AuthField(
            controller: _email,
            label: 'Email',
            hint: 'ten@congty.vn',
            shake: _shake,
            autofocus: true,
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
          if (_error != null) ...[
            const SizedBox(height: 12),
            AuthErrorBox(message: _error!),
          ],
          const SizedBox(height: 20),
          AuthPrimaryButton(
            label: 'Gửi liên kết đặt lại',
            busy: _busy,
            onPressed: _busy ? null : _submit,
          ),
        ],
      ),
    );
  }

  Widget _sentBody() {
    final scheme = Theme.of(context).colorScheme;
    final meta = OmniType.body.copyWith(color: scheme.onSurfaceVariant);
    return Column(
      key: const ValueKey('forgot-sent'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(LucideIcons.mailCheck, size: 30, color: scheme.primary),
        ),
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: Text('Kiểm tra email', style: authTitleStyle(context)),
        ),
        const SizedBox(height: 6),
        Semantics(
          liveRegion: true,
          child: Text.rich(
            TextSpan(
              text: 'Liên kết đặt lại đã gửi tới\n',
              children: [
                TextSpan(
                  text: _sentTo,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            style: meta,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Hết hạn sau 30 phút',
          style: OmniType.bodySm.copyWith(color: scheme.onSurfaceVariant),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: AuthErrorBox(message: _error!),
          ),
        ],
      ],
    );
  }

  Widget _sentActions() {
    final scheme = Theme.of(context).colorScheme;
    final textStyle = OmniType.input.copyWith(fontWeight: FontWeight.w600);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AuthPrimaryButton(label: 'Mở ứng dụng email', onPressed: _openMail),
        const SizedBox(height: 8),
        ValueListenableBuilder<int>(
          valueListenable: _left,
          builder: (context, left, _) => TextButton(
            onPressed: left <= 0 && !_busy ? () => _send(_sentTo) : null,
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              foregroundColor: scheme.primary,
              disabledForegroundColor: scheme.onSurfaceVariant,
              textStyle: textStyle.copyWith(fontFeatures: OmniType.tabular),
            ),
            child: _busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                  )
                : Text(
                    left > 0 ? 'Gửi lại sau ${_clock(left)}' : 'Gửi lại email',
                  ),
          ),
        ),
        TextButton(
          onPressed: _busy ? null : _changeEmail,
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
            foregroundColor: scheme.primary,
            textStyle: textStyle,
          ),
          child: const Text('Dùng email khác'),
        ),
      ],
    );
  }
}

/// 42 → "0:42", 75 → "1:15".
String _clock(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
