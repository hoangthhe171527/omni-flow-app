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
import 'widgets/auth_widgets.dart';

/// Màn đăng ký (`#s-auth-register`): nút kính tròn `OmniGlassCircle`, 2 thẻ nhóm
/// bo 18, thanh độ mạnh mật khẩu 4 mức, dòng đồng ý vòng tròn Liquid 22×22 (bỏ
/// `Checkbox` Material) và đăng ký nhanh qua Google vector.
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
    // loginControllerProvider dùng chung với màn đăng nhập: lỗi Google còn sót
    // ở đó không được chào đón người dùng ở màn đăng ký.
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
    final email = _email.text.trim();
    final ok = await ref
        .read(registerControllerProvider.notifier)
        .submit(
          fullName: _name.text.trim(),
          email: email,
          companyName: _company.text.trim(),
          password: _password.text,
        );
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
    final busy = state.submitting || google.submitting;
    // Lỗi chung: hộp riêng chỉ khi không có chữ nào đã hiện dưới từng ô.
    final generalError = state.fieldErrors.isEmpty
        ? (state.error ?? google.error)
        : null;

    return AuthScaffold(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthSubBar(onBack: _back),
              const SizedBox(height: 10),
              Text(
                'Tạo tài khoản',
                style: OmniType.largeTitle.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Thiết lập hồ sơ quản trị và không gian công ty của bạn.',
                style: OmniType.bodySm.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 18),
              AuthFieldGroup(
                title: 'Tài khoản & Tổ chức',
                children: [
                  AuthGroupField(
                    controller: _name,
                    label: 'Họ và tên',
                    hint: 'Nguyễn Hoàng Nam',
                    icon: Icons.person_outline_rounded,
                    shake: _shake,
                    serverError: state.errorFor('full_name'),
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'Vui lòng nhập họ tên'
                        : null,
                  ),
                  AuthGroupField(
                    controller: _email,
                    label: 'Email làm việc',
                    hint: 'ten@congty.vn',
                    icon: Icons.mail_outline_rounded,
                    shake: _shake,
                    serverError: state.errorFor('email'),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    validator: (v) {
                      final text = v?.trim() ?? '';
                      if (text.isEmpty) return 'Vui lòng nhập email';
                      if (!looksLikeEmail(text)) {
                        return 'Email chưa hợp lệ';
                      }
                      return null;
                    },
                  ),
                  AuthGroupField(
                    controller: _company,
                    label: 'Tên công ty / tổ chức',
                    hint: 'Cửa hàng hoặc doanh nghiệp',
                    icon: Icons.business_outlined,
                    shake: _shake,
                    serverError: state.errorFor('company_name'),
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.organizationName],
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'Vui lòng nhập tên công ty'
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AuthFieldGroup(
                title: 'Bảo mật',
                trailingTitle: Text(
                  'Tối thiểu 8 ký tự',
                  style: OmniType.micro.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontFeatures: OmniType.tabular,
                  ),
                ),
                children: [
                  AuthGroupField(
                    controller: _password,
                    label: 'Mật khẩu',
                    hint: 'Nhập ít nhất 8 ký tự',
                    icon: Icons.lock_outline_rounded,
                    shake: _shake,
                    serverError: state.errorFor('password'),
                    obscure: _obscure,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    onSubmitted: (_) => _submit(),
                    validator: (v) => (v ?? '').length < 8
                        ? 'Mật khẩu cần ít nhất 8 ký tự'
                        : null,
                    suffix: AuthPasswordToggle(
                      obscure: _obscure,
                      onToggle: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _StrengthMeter(score: passwordScore(_password.text)),
              ),
              const SizedBox(height: 12),
              _TermsRow(
                agreed: _agreed,
                onChanged: (v) => setState(() => _agreed = v),
              ),
              if (generalError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: AuthErrorBox(message: generalError),
                ),
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
              const SizedBox(height: 16),
              const AuthDivider(),
              const SizedBox(height: 16),
              AuthGoogleButton(
                label: 'Đăng ký với Google',
                onPressed: busy ? null : _submitGoogle,
                busy: google.submittingMethod == LoginMethod.google,
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Đã có tài khoản? ',
                    style: OmniType.bodySm.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  InkWell(
                    onTap: _back,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 10,
                      ),
                      child: Text(
                        'Đăng nhập',
                        style: OmniType.bodySm.copyWith(
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
    final duration = OmniMotion.of(context).fast;
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
              child: AnimatedContainer(
                duration: duration,
                curve: Curves.easeOutCubic,
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

/// Dòng đồng ý điều khoản dùng vòng tick tròn 22×22 tự vẽ chuẩn Liquid (tuyệt
/// đối không dùng `Checkbox` / `Checkbox.adaptive` của Material).
class _TermsRow extends StatelessWidget {
  const _TermsRow({required this.agreed, required this.onChanged});

  final bool agreed;
  final ValueChanged<bool> onChanged;

  void _toggle() {
    HapticFeedback.selectionClick();
    onChanged(!agreed);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final duration = OmniMotion.of(context).fast;

    return Semantics(
      container: true,
      checked: agreed,
      label: 'Đồng ý Điều khoản sử dụng',
      excludeSemantics: true,
      onTap: _toggle,
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('terms-checkbox'),
          onTap: _toggle,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: agreed ? scheme.primary : Colors.transparent,
                      border: Border.all(
                        color: agreed ? scheme.primary : scheme.outline,
                        width: 1.5,
                      ),
                    ),
                    child: agreed
                        ? Icon(
                            Icons.check_rounded,
                            size: OmniIconSize.xs,
                            color: scheme.onPrimary,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Đồng ý Điều khoản sử dụng',
                      style: OmniType.bodySm.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
