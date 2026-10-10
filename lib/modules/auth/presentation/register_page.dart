import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/platform/omni_motion_scope.dart';
import '../../../design/tokens/tokens.dart';
import '../application/login_controller.dart';
import '../application/password_strength.dart';
import '../application/register_controller.dart';
import '../auth_module.dart';
import 'widgets/auth_field.dart';
import 'widgets/auth_widgets.dart';

/// Màn đăng ký (khung `AuthRegister`): bốn ô, thanh độ mạnh, điều khoản, rồi
/// nút "Tạo tài khoản" mờ cho tới khi đủ điều kiện.
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _company = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _agreed = false;

  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  late final Listenable _inputs = Listenable.merge([
    _name,
    _email,
    _company,
    _password,
  ]);

  @override
  void initState() {
    super.initState();
    _inputs.addListener(_refresh);
    // loginControllerProvider is shared with the login page: a Google error left
    // there must not greet the user here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.invalidate(loginControllerProvider);
    });
  }

  @override
  void dispose() {
    _inputs.removeListener(_refresh);
    _shake.dispose();
    _name.dispose();
    _email.dispose();
    _company.dispose();
    _password.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  bool get _ready =>
      _name.text.trim().isNotEmpty &&
      looksLikeEmail(_email.text) &&
      _company.text.trim().isNotEmpty &&
      _password.text.length >= 8 &&
      _agreed;

  void _shakeIfAllowed() {
    if (!OmniMotion.enabled(context)) return;
    _shake.forward(from: 0);
  }

  Future<void> _submit() async {
    if (!_ready || ref.read(registerControllerProvider).submitting) return;
    if (!_formKey.currentState!.validate()) {
      _shakeIfAllowed();
      return;
    }
    FocusScope.of(context).unfocus();
    final ok = await ref
        .read(registerControllerProvider.notifier)
        .submit(
          fullName: _name.text.trim(),
          email: _email.text.trim(),
          companyName: _company.text.trim(),
          password: _password.text,
        );
    if (ok) TextInput.finishAutofillContext();
    // Điều hướng là việc của router: phiên sẵn sàng thì redirect đưa vào app.
  }

  Future<void> _submitGoogle() async {
    FocusScope.of(context).unfocus();
    if (ref.read(loginControllerProvider).submitting) return;
    await ref.read(loginControllerProvider.notifier).submitWithGoogle();
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
    ref.listen(registerControllerProvider.select((s) => s.fieldErrors), (
      prev,
      next,
    ) {
      if (next.isNotEmpty && next != prev) _shakeIfAllowed();
    });
    final state = ref.watch(registerControllerProvider);
    final google = ref.watch(loginControllerProvider);
    final scheme = Theme.of(context).colorScheme;
    final inputText = OmniType.input.copyWith(
      fontWeight: FontWeight.w500,
      color: scheme.onSurface,
    );
    final busy = state.submitting || google.submitting;
    // Lỗi chung: hộp riêng chỉ khi không có chữ nào đã hiện dưới ô.
    final generalError = state.fieldErrors.isEmpty
        ? (state.error ?? google.error)
        : null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
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
                      Text(
                        'Tạo tài khoản',
                        style: OmniType.largeTitle.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 24),
                      AuthField(
                        controller: _name,
                        hint: 'Họ và tên',
                        icon: Icons.person_outline_rounded,
                        shake: _shake,
                        serverError: state.errorFor('full_name'),
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.name],
                        style: inputText,
                        validator: (v) => (v ?? '').trim().isEmpty
                            ? 'Vui lòng nhập họ tên'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      AuthField(
                        controller: _email,
                        hint: 'Email làm việc',
                        icon: Icons.mail_outline_rounded,
                        shake: _shake,
                        serverError: state.errorFor('email'),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        style: inputText,
                        validator: (v) {
                          final text = v?.trim() ?? '';
                          if (text.isEmpty) return 'Vui lòng nhập email';
                          if (!looksLikeEmail(text)) {
                            return 'Email chưa hợp lệ';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      AuthField(
                        controller: _company,
                        hint: 'Tên công ty',
                        icon: Icons.business_outlined,
                        shake: _shake,
                        serverError: state.errorFor('company_name'),
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.organizationName],
                        style: inputText,
                        validator: (v) => (v ?? '').trim().isEmpty
                            ? 'Vui lòng nhập tên công ty'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      AuthField(
                        controller: _password,
                        hint: 'Mật khẩu (8+ ký tự)',
                        icon: Icons.lock_outline_rounded,
                        shake: _shake,
                        serverError: state.errorFor('password'),
                        obscure: _obscure,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.newPassword],
                        onSubmitted: (_) => _submit(),
                        style: inputText,
                        validator: (v) => (v ?? '').length < 8
                            ? 'Mật khẩu cần ít nhất 8 ký tự'
                            : null,
                        suffix: IconButton(
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
                      const SizedBox(height: 10),
                      _StrengthMeter(score: passwordScore(_password.text)),
                      const SizedBox(height: 12),
                      _TermsRow(
                        agreed: _agreed,
                        onChanged: (v) => setState(() => _agreed = v),
                      ),
                      if (generalError != null) ...[
                        const SizedBox(height: 8),
                        AuthErrorBox(message: generalError),
                      ],
                      const SizedBox(height: 16),
                      AnimatedOpacity(
                        key: const ValueKey('register-opacity'),
                        duration: OmniMotion.enabled(context)
                            ? OmniDuration.fast
                            : Duration.zero,
                        opacity: _ready ? 1 : 0.45,
                        child: AuthPrimaryButton(
                          key: const ValueKey('register-submit'),
                          label: 'Tạo tài khoản',
                          busy: state.submitting,
                          onPressed: (_ready && !busy) ? _submit : null,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const AuthDivider(),
                      const SizedBox(height: 20),
                      AuthGoogleButton(
                        label: 'Đăng ký với Google',
                        onPressed: busy ? null : _submitGoogle,
                        busy: google.submittingMethod == LoginMethod.google,
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Đã có tài khoản? ',
                            style: OmniType.body.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          InkWell(
                            onTap: _back,
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 12,
                              ),
                              child: Text(
                                'Đăng nhập',
                                style: OmniType.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: scheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const AuthPrivacyLink(),
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

/// Bốn vạch + nhãn: Yếu đỏ, Tạm cam, Khá xanh dương, Mạnh `primary`.
class _StrengthMeter extends StatelessWidget {
  const _StrengthMeter({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (score) {
      <= 1 => OmniColors.destructive,
      2 => OmniColors.warning,
      3 => OmniColors.info,
      _ => scheme.primary,
    };
    final label = passwordLabel(score);

    return Semantics(
      label: score == 0 ? 'Độ mạnh mật khẩu' : 'Độ mạnh mật khẩu: $label',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < 4; i++) ...[
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: i < score ? color : scheme.outlineVariant,
                ),
              ),
            ),
            if (i < 3) const SizedBox(width: 6),
          ],
          SizedBox(
            width: 52,
            child: score == 0
                ? null
                : Text(
                    label,
                    textAlign: TextAlign.end,
                    style: OmniType.caption.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TermsRow extends StatelessWidget {
  const _TermsRow({required this.agreed, required this.onChanged});

  final bool agreed;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      checked: agreed,
      label: 'Đồng ý Điều khoản sử dụng',
      excludeSemantics: true,
      onTap: () => onChanged(!agreed),
      child: InkWell(
        key: const ValueKey('terms-checkbox'),
        onTap: () => onChanged(!agreed),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              IgnorePointer(
                child: Checkbox(value: agreed, onChanged: (_) {}),
              ),
              Expanded(
                child: Text(
                  'Đồng ý Điều khoản sử dụng',
                  style: OmniType.body.copyWith(color: scheme.onSurface),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
