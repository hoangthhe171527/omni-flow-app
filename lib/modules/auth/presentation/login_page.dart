import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/platform/omni_motion_scope.dart';
import '../../../design/tokens/tokens.dart';
import '../application/login_controller.dart';
import '../auth_module.dart';
import 'widgets/auth_widgets.dart';

/// Màn đăng nhập (artifact "Màn xác thực" duyệt 26/11): logo trần 56 neo cho
/// màn mở app bay về, tiêu đề "Đăng nhập Viomni", Google lên đầu, rồi hai ô
/// rời có nhãn ("Quên?" cùng hàng nhãn mật khẩu), nút chính xanh đặc; chân màn
/// là "Chưa có tài khoản? Đăng ký" và Chính sách bảo mật.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _submitKey = GlobalKey();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  Timer? _revealTimer;
  bool _obscure = true;

  /// Cú rung 400ms của ô lỗi.
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(_revealSubmit);
    _passwordFocus.addListener(_revealSubmit);
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    _emailFocus.removeListener(_revealSubmit);
    _passwordFocus.removeListener(_revealSubmit);
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _shake.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _typing => _emailFocus.hasFocus || _passwordFocus.hasFocus;

  /// Đang gõ email hay mật khẩu thì nút Đăng nhập phải nằm ngay trên bàn phím,
  /// không bị che: đợi bàn phím bật xong rồi cuộn tới nút (hai ô + nút vừa
  /// khung nhìn còn lại).
  void _revealSubmit() {
    _revealTimer?.cancel();
    if (!_typing) return;
    final duration = OmniMotion.enabled(context)
        ? OmniDuration.base
        : Duration.zero;
    _revealTimer = Timer(OmniDuration.slow, () {
      final target = _submitKey.currentContext;
      if (!mounted || target == null || !_typing) return;
      Scrollable.ensureVisible(
        target,
        alignment: 1,
        duration: duration,
        curve: OmniCurves.standard,
      );
    });
  }

  void _shakeIfAllowed() {
    HapticFeedback.heavyImpact();
    if (!OmniMotion.enabled(context)) return;
    _shake.forward(from: 0);
  }

  Future<void> _submit() async {
    if (ref.read(loginControllerProvider).submitting) return;
    if (!_formKey.currentState!.validate()) {
      _shakeIfAllowed();
      return;
    }
    FocusScope.of(context).unfocus();
    final email = _email.text.trim();
    final ok = await ref
        .read(loginControllerProvider.notifier)
        .submit(email: email, password: _password.text);
    // Báo hệ điều hành lưu thông tin đăng nhập vào trình quản lý mật khẩu.
    if (ok) {
      if (mounted) {
        ref.read(authSignedInEmailProvider.notifier).state = email;
      }
      TextInput.finishAutofillContext();
    }
  }

  Future<void> _submitGoogle() async {
    FocusScope.of(context).unfocus();
    if (ref.read(loginControllerProvider).submitting) return;
    await ref.read(loginControllerProvider.notifier).submitWithGoogle();
  }

  /// Sang Quên mật khẩu mang theo email vừa gõ, khỏi gõ lại.
  void _openForgot() {
    final email = _email.text.trim();
    context.pushNamed(AuthModule.forgot, extra: email.isEmpty ? null : email);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(loginControllerProvider.select((s) => s.error), (prev, next) {
      if (next != null && next != prev) _shakeIfAllowed();
    });
    final state = ref.watch(loginControllerProvider);
    // Lỗi chỉ hiện MỘT chỗ: dưới ô khi server chỉ ra ô, không thì hộp chung.
    final generalError = state.fieldErrors.isEmpty ? state.error : null;

    return AuthScaffold(
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AuthSwitchLink(
            prompt: 'Chưa có tài khoản?',
            action: 'Đăng ký',
            onTap: () => context.pushNamed(AuthModule.register),
          ),
          const AuthPrivacyLink(),
        ],
      ),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthBrandHeader(
                anchorBrand: true,
                title: 'Đăng nhập Viomni',
              ),
              const SizedBox(height: 28),
              AuthGoogleButton(
                label: 'Tiếp tục với Google',
                onPressed: state.submitting ? null : _submitGoogle,
                busy: state.submittingMethod == LoginMethod.google,
              ),
              const AuthDivider(),
              AuthField(
                controller: _email,
                focusNode: _emailFocus,
                label: 'Email',
                hint: 'ten@congty.vn',
                shake: _shake,
                serverError: state.errorFor('email'),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [
                  AutofillHints.username,
                  AutofillHints.email,
                ],
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'Vui lòng nhập email';
                  if (!text.contains('@')) return 'Email chưa hợp lệ';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              AuthField(
                controller: _password,
                focusNode: _passwordFocus,
                label: 'Mật khẩu',
                hint: 'Nhập mật khẩu',
                shake: _shake,
                serverError: state.errorFor('password'),
                obscure: _obscure,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _submit(),
                validator: (value) =>
                    (value ?? '').isEmpty ? 'Vui lòng nhập mật khẩu' : null,
                labelTrailing: AuthLabelLink(
                  label: 'Quên?',
                  semanticLabel: 'Quên mật khẩu',
                  onTap: _openForgot,
                ),
                suffix: AuthPasswordToggle(
                  obscure: _obscure,
                  onToggle: () => setState(() => _obscure = !_obscure),
                ),
              ),
              const SizedBox(height: 20),
              if (generalError != null) ...[
                AuthErrorBox(
                  message: generalError,
                  actionLabel: state.wrongCredentials
                      ? 'Đặt lại mật khẩu'
                      : null,
                  onAction: _openForgot,
                ),
                const SizedBox(height: 14),
              ],
              AuthPrimaryButton(
                key: _submitKey,
                label: 'Đăng nhập',
                onPressed: state.submitting ? null : _submit,
                busy: state.submittingMethod == LoginMethod.password,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
