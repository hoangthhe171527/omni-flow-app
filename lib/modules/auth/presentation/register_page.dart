import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../design/components/components.dart';
import '../../../design/platform/omni_motion_scope.dart';
import '../../../design/tokens/tokens.dart';
import '../application/login_controller.dart';
import '../application/password_strength.dart';
import '../application/register_controller.dart';
import '../auth_module.dart';
import 'widgets/auth_widgets.dart';

/// Màn đăng ký — hướng "Quỹ đạo" (duyệt 26/11/2026): `‹` xanh trơn, quỹ đạo
/// nhỏ mờ góc trên phải, tiêu đề lớn căn trái, ô nhập GỘP theo nhóm có nhãn
/// chữ HOA (BẠN · CÔNG TY · BẢO MẬT) như Cài đặt iOS, thanh 4 vạch độ mạnh
/// mật khẩu trong nhóm BẢO MẬT, nút chính LUÔN bấm được (thiếu gì báo ngay
/// dưới ô đó), Google thứ yếu bên dưới, một dòng pháp lý nhỏ thay ô tích.
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

  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  @override
  void initState() {
    super.initState();
    // Thanh độ mạnh đi theo từng ký tự gõ.
    _password.addListener(_refresh);
    // loginControllerProvider dùng chung với màn đăng nhập: lỗi Google còn sót
    // ở đó không được chào đón người dùng ở màn đăng ký.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.invalidate(loginControllerProvider);
    });
  }

  @override
  void dispose() {
    _password.removeListener(_refresh);
    _shake.dispose();
    _name.dispose();
    _email.dispose();
    _company.dispose();
    _password.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  void _shakeIfAllowed() {
    HapticFeedback.heavyImpact();
    if (!OmniMotion.enabled(context)) return;
    _shake.forward(from: 0);
  }

  Future<void> _submit() async {
    if (ref.read(registerControllerProvider).submitting) return;
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
    final busy = state.submitting || google.submitting;
    // Lỗi chung: hộp riêng chỉ khi không có chữ nào đã hiện dưới từng ô.
    final generalError = state.fieldErrors.isEmpty
        ? (state.error ?? google.error)
        : null;

    return AuthScaffold(
      top: 4,
      backdrop: const _CornerOrbit(),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthSubBar(onBack: _back),
              const SizedBox(height: 8),
              const AuthHeroTitle(
                title: 'Tạo tài khoản',
                subtitle: 'Một tài khoản cho cả công ty',
              ),
              const SizedBox(height: 22),
              const AuthGroupLabel('Bạn'),
              AuthFieldGroup(
                fields: [
                  AuthGroupField(
                    controller: _name,
                    label: 'Họ và tên',
                    hint: 'Họ và tên',
                    icon: LucideIcons.user,
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
                    hint: 'Email làm việc',
                    icon: LucideIcons.mail,
                    shake: _shake,
                    serverError: state.errorFor('email'),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    validator: (v) {
                      final text = v?.trim() ?? '';
                      if (text.isEmpty) return 'Vui lòng nhập email';
                      if (!looksLikeEmail(text)) return 'Email chưa hợp lệ';
                      return null;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const AuthGroupLabel('Công ty'),
              AuthFieldGroup(
                fields: [
                  AuthGroupField(
                    controller: _company,
                    label: 'Tên công ty',
                    hint: 'Cửa hàng hoặc doanh nghiệp',
                    icon: LucideIcons.building2,
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
              const SizedBox(height: 18),
              const AuthGroupLabel('Bảo mật'),
              AuthFieldGroup(
                fields: [
                  AuthGroupField(
                    controller: _password,
                    label: 'Mật khẩu',
                    hint: 'Ít nhất 8 ký tự',
                    icon: LucideIcons.lock,
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
                footer: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AuthFieldGroup.indent,
                    0,
                    14,
                    12,
                  ),
                  child: _StrengthMeter(score: passwordScore(_password.text)),
                ),
              ),
              if (generalError != null) ...[
                const SizedBox(height: 14),
                AuthErrorBox(message: generalError),
              ],
              const SizedBox(height: 22),
              AuthPrimaryButton(
                key: const ValueKey('register-submit'),
                label: 'Tạo tài khoản',
                busy: state.submitting,
                onPressed: busy ? null : _submit,
              ),
              const SizedBox(height: 12),
              AuthGoogleButton(
                label: 'Đăng ký với Google',
                onPressed: busy ? null : _submitGoogle,
                busy: google.submittingMethod == LoginMethod.google,
              ),
              const SizedBox(height: 4),
              const AuthPrivacyLink(prefix: 'Tạo tài khoản là đồng ý'),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quỹ đạo nhỏ mờ góc trên phải (tỉ lệ .42), nằm sau nội dung, chỉ để trang
/// trí — trình đọc màn hình bỏ qua.
class _CornerOrbit extends StatelessWidget {
  const _CornerOrbit();

  @override
  Widget build(BuildContext context) {
    const scale = 0.42;
    final top = MediaQuery.paddingOf(context).top;
    final w = OmniOrbit.extent.width * scale;
    final h = OmniOrbit.extent.height * scale;
    return Stack(
      children: [
        Positioned(
          // Tâm quỹ đạo cách mép phải 75, ngang thanh `‹`.
          top: top + 26 - h / 2,
          right: 75 - w / 2,
          child: const OmniOrbit(scale: scale, opacity: 0.9),
        ),
      ],
    );
  }
}

/// Bốn vạch độ mạnh: số vạch sáng = số điều kiện đạt, cùng một màu theo mức
/// — đỏ, cam, vàng, xanh lá. Không chữ trên màn; trình đọc màn hình đọc
/// "Độ mạnh mật khẩu: Yếu/Tạm/Khá/Mạnh".
class _StrengthMeter extends StatelessWidget {
  const _StrengthMeter({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final duration = OmniMotion.of(context).base;
    final color = switch (score) {
      <= 1 => OmniColors.attentionOf(context),
      2 => OmniColors.warning,
      3 => OmniColors.sun,
      _ => OmniColors.byBrightness(
        context,
        OmniColors.switchOn,
        OmniColors.darkSwitchOn,
      ),
    };

    return Semantics(
      label: score == 0
          ? 'Độ mạnh mật khẩu'
          : 'Độ mạnh mật khẩu: ${passwordLabel(score)}',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < 4; i++) ...[
            Expanded(
              child: AnimatedContainer(
                key: ValueKey('strength-bar-$i'),
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
        ],
      ),
    );
  }
}
