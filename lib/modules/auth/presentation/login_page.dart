import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/components/components.dart';
import '../../../design/platform/omni_motion_scope.dart';
import '../../../design/tokens/tokens.dart';
import '../application/login_controller.dart';
import '../auth_module.dart';
import 'widgets/auth_field.dart';
import 'widgets/auth_widgets.dart';

/// Màn đăng nhập (khung `Auth`): logo trên vòng tròn nhạt, lời chào, hai ô,
/// nút chính, rồi Google, liên kết đăng ký ở đáy.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  /// Cú rung 400ms của ô lỗi.
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  @override
  void dispose() {
    _shake.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _shakeIfAllowed() {
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
    final ok = await ref
        .read(loginControllerProvider.notifier)
        .submit(email: _email.text.trim(), password: _password.text);
    // Báo hệ điều hành lưu thông tin đăng nhập vào trình quản lý mật khẩu.
    if (ok) TextInput.finishAutofillContext();
    // Navigation is the router's job: a successful login flips the session
    // status and the redirect takes the user to their first visible tab.
  }

  Future<void> _submitGoogle() async {
    FocusScope.of(context).unfocus();
    if (ref.read(loginControllerProvider).submitting) return;
    await ref.read(loginControllerProvider.notifier).submitWithGoogle();
    // As with password login, SessionController drives the router after the
    // token is accepted and a workspace is selected (or needs selecting).
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(loginControllerProvider.select((s) => s.error), (prev, next) {
      if (next != null && next != prev) _shakeIfAllowed();
    });
    final state = ref.watch(loginControllerProvider);
    final scheme = Theme.of(context).colorScheme;
    final inputText = OmniType.input.copyWith(
      fontWeight: FontWeight.w500,
      color: scheme.onSurface,
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 96, 24, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 108,
                          height: 108,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: OmniColors.byBrightness(
                              context,
                              OmniColors.accent,
                              OmniColors.darkAccent,
                            ).withValues(alpha: 0.7),
                          ),
                          child: const BrandAnchor(
                            child: OmniBrandMark(size: 64),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Chào mừng trở lại',
                        textAlign: TextAlign.center,
                        style: OmniType.largeTitle.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 32),
                      AuthField(
                        controller: _email,
                        hint: 'Email làm việc',
                        icon: Icons.mail_outline_rounded,
                        shake: _shake,
                        serverError: state.errorFor('email'),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [
                          AutofillHints.username,
                          AutofillHints.email,
                        ],
                        style: inputText,
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) return 'Vui lòng nhập email';
                          if (!text.contains('@')) return 'Email chưa hợp lệ';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      AuthField(
                        controller: _password,
                        hint: 'Mật khẩu',
                        icon: Icons.lock_outline_rounded,
                        shake: _shake,
                        serverError: state.errorFor('password'),
                        obscure: _obscure,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) => _submit(),
                        style: inputText,
                        validator: (value) => (value ?? '').isEmpty
                            ? 'Vui lòng nhập mật khẩu'
                            : null,
                        suffix: IconButton(
                          // Nhãn nói cả TRẠNG THÁI: nếu không, người dùng
                          // screen reader không có cách nào biết mật khẩu
                          // của mình đang hiện trên màn hình hay không.
                          tooltip: _obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: OmniIconSize.lg,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => context.pushNamed(AuthModule.forgot),
                          style: TextButton.styleFrom(
                            textStyle: OmniType.caption.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: const Text('Quên mật khẩu?'),
                        ),
                      ),
                      if (state.error != null) ...[
                        const SizedBox(height: 4),
                        AuthErrorBox(message: state.error!),
                        const SizedBox(height: 12),
                      ],
                      const SizedBox(height: 8),
                      AuthPrimaryButton(
                        label: 'Đăng nhập',
                        onPressed: state.submitting ? null : _submit,
                        busy: state.submittingMethod == LoginMethod.password,
                      ),
                      const SizedBox(height: 20),
                      const AuthDivider(),
                      const SizedBox(height: 20),
                      AuthGoogleButton(
                        label: 'Tiếp tục với Google',
                        onPressed: state.submitting ? null : _submitGoogle,
                        busy: state.submittingMethod == LoginMethod.google,
                      ),
                      const SizedBox(height: 32),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Chưa có tài khoản? ',
                            style: OmniType.body.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          InkWell(
                            onTap: () => context.pushNamed(AuthModule.register),
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 12,
                              ),
                              child: Text(
                                'Đăng ký',
                                style: OmniType.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: scheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
