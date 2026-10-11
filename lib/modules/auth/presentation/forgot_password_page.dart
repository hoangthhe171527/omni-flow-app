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
import 'widgets/auth_field.dart';
import 'widgets/auth_widgets.dart';

/// Màn quên mật khẩu (khung `AuthForgot`): nhập email → "Kiểm tra email".
///
/// API trả 204 dù email có tồn tại hay không, nên màn này cũng LUÔN báo "đã
/// gửi" khi lời gọi thành công — không để lộ địa chỉ nào có tài khoản.
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
  int _left = 0;
  String? _error;
  String? _fieldError;

  @override
  void dispose() {
    _timer?.cancel();
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
    setState(() => _left = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 0) timer.cancel();
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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: 'Quay lại',
                      onPressed: _back,
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_sent) _buildSent(scheme) else _buildForm(scheme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(ColorScheme scheme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Quên mật khẩu?',
            style: OmniType.largeTitle.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            'Nhận liên kết đặt lại qua email.',
            style: OmniType.body.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          AuthField(
            controller: _email,
            hint: 'Email làm việc',
            icon: Icons.mail_outline_rounded,
            shake: _shake,
            serverError: _fieldError,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            onSubmitted: (_) => _submit(),
            style: OmniType.input.copyWith(
              fontWeight: FontWeight.w500,
              color: scheme.onSurface,
            ),
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
            label: 'Gửi liên kết',
            busy: _busy,
            onPressed: _busy ? null : _submit,
          ),
        ],
      ),
    );
  }

  Widget _buildSent(ColorScheme scheme) {
    final canResend = _left <= 0 && !_busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Kiểm tra email',
          style: OmniType.largeTitle.copyWith(color: scheme.onSurface),
        ),
        const SizedBox(height: 8),
        Semantics(
          liveRegion: true,
          child: Text(
            'Đã gửi tới $_sentTo',
            style: OmniType.body.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          AuthErrorBox(message: _error!),
        ],
        const SizedBox(height: 24),
        AuthPrimaryButton(label: 'Mở ứng dụng email', onPressed: _openMail),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: canResend ? () => _send(_sentTo) : null,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: _busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_left > 0 ? 'Gửi lại sau $_left giây' : 'Gửi lại email'),
        ),
      ],
    );
  }
}
