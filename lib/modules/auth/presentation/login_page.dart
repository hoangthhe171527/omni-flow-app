import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../application/login_controller.dart';

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
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final form = _LoginForm(
            formKey: _formKey,
            email: _email,
            password: _password,
            obscure: _obscure,
            submitting: state.submitting,
            error: state.error,
            emailError: state.errorFor('email'),
            passwordError: state.errorFor('password'),
            onTogglePassword: () => setState(() => _obscure = !_obscure),
            onSubmit: _submit,
          );

          if (!wide) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                child: _MobileLoginForm(
                  formKey: _formKey,
                  email: _email,
                  password: _password,
                  obscure: _obscure,
                  submitting: state.submitting,
                  error: state.error,
                  emailError: state.errorFor('email'),
                  passwordError: state.errorFor('password'),
                  onTogglePassword: () => setState(() => _obscure = !_obscure),
                  onSubmit: _submit,
                ),
              ),
            );
          }

          return Row(
            children: [
              Expanded(flex: 5, child: _LoginBrandPanel(scheme: scheme)),
              Expanded(
                flex: 4,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(48),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: form,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The mobile login intentionally remains the compact, single-column screen
/// that was already tuned for thumb reach. Desktop gets the expanded brand
/// panel above; mobile does not inherit that marketing treatment.
class _MobileLoginForm extends StatelessWidget {
  const _MobileLoginForm({
    required this.formKey,
    required this.email,
    required this.password,
    required this.obscure,
    required this.submitting,
    required this.error,
    required this.emailError,
    required this.passwordError,
    required this.onTogglePassword,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController email;
  final TextEditingController password;
  final bool obscure;
  final bool submitting;
  final String? error;
  final String? emailError;
  final String? passwordError;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              gradient: OmniGradients.brand,
              borderRadius: OmniRadius.mdAll,
            ),
            child: const Icon(
              Icons.layers_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(height: OmniSpacing.xxl),
          Text(
            'Chào mừng trở lại',
            style: OmniType.displayLg.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: OmniSpacing.sm),
          Text(
            'Nhập thông tin để tiếp tục xử lý công việc và hỗ trợ khách hàng.',
            style: OmniType.body.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: OmniSpacing.section),
          OmniField(
            label: 'Email làm việc',
            error: emailError,
            child: TextFormField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: 'ten@congty.vn',
                prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return 'Vui lòng nhập email';
                if (!text.contains('@')) return 'Email chưa hợp lệ';
                return null;
              },
            ),
          ),
          const SizedBox(height: OmniSpacing.lg),
          OmniField(
            label: 'Mật khẩu',
            error: passwordError,
            child: TextFormField(
              controller: password,
              obscureText: obscure,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => onSubmit(),
              decoration: InputDecoration(
                hintText: 'Nhập mật khẩu',
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                  onPressed: onTogglePassword,
                ),
              ),
              validator: (value) =>
                  (value ?? '').isEmpty ? 'Vui lòng nhập mật khẩu' : null,
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: OmniSpacing.lg),
            Container(
              padding: const EdgeInsets.all(OmniSpacing.md),
              decoration: BoxDecoration(
                color: scheme.error.withValues(alpha: .08),
                borderRadius: OmniRadius.mdAll,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 18,
                    color: scheme.error,
                  ),
                  const SizedBox(width: OmniSpacing.sm),
                  Expanded(
                    child: Text(
                      error!,
                      style: OmniType.caption.copyWith(color: scheme.error),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: OmniSpacing.xxl),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: submitting ? null : onSubmit,
              child: submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Đăng nhập'),
            ),
          ),
          const SizedBox(height: OmniSpacing.xxl),
          Center(
            child: Text(
              '${AppConfig.appName} · ${Uri.parse(AppConfig.apiBaseUrl).host}',
              style: OmniType.micro.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginBrandPanel extends StatelessWidget {
  const _LoginBrandPanel({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: scheme.primary,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -110,
            top: -80,
            child: Container(
              width: 430,
              height: 430,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: .13),
                  width: 1.5,
                ),
              ),
            ),
          ),
          Positioned(
            right: 50,
            bottom: -170,
            child: Container(
              width: 520,
              height: 520,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: .09),
                  width: 1.5,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .14),
                    borderRadius: OmniRadius.mdAll,
                  ),
                  child: const Icon(Icons.layers_rounded, color: Colors.white),
                ),
                const Spacer(),
                Text(
                  'Một không gian rõ ràng\ncho mọi cuộc trò chuyện.',
                  style: OmniType.displayLg.copyWith(
                    color: Colors.white,
                    fontSize: 38,
                    height: 1.12,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Kết nối đội ngũ, khách hàng và công việc trong một nhịp vận hành thống nhất.',
                  style: OmniType.body.copyWith(
                    color: Colors.white.withValues(alpha: .74),
                    fontSize: 16,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 44),
                Row(
                  children: [
                    _BrandMetric(value: '01', label: 'không gian'),
                    const SizedBox(width: 28),
                    _BrandMetric(value: '∞', label: 'khả năng mở rộng'),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'OMNI CRM · Nền tảng vận hành đa kênh',
                  style: OmniType.micro.copyWith(
                    color: Colors.white.withValues(alpha: .56),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandMetric extends StatelessWidget {
  const _BrandMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text(
        value,
        style: OmniType.title.copyWith(color: Colors.white, fontSize: 22),
      ),
      const SizedBox(width: 7),
      Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text(
          label,
          style: OmniType.micro.copyWith(
            color: Colors.white.withValues(alpha: .62),
          ),
        ),
      ),
    ],
  );
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.formKey,
    required this.email,
    required this.password,
    required this.obscure,
    required this.submitting,
    required this.error,
    required this.emailError,
    required this.passwordError,
    required this.onTogglePassword,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController email;
  final TextEditingController password;
  final bool obscure;
  final bool submitting;
  final String? error;
  final String? emailError;
  final String? passwordError;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'OMNI CRM',
            style: OmniType.overline.copyWith(
              color: scheme.primary,
              letterSpacing: 2.2,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Chào mừng trở lại',
            style: OmniType.displayLg.copyWith(
              color: scheme.onSurface,
              fontSize: 32,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Đăng nhập để tiếp tục công việc của bạn.',
            style: OmniType.body.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 40),
          OmniField(
            label: 'Email làm việc',
            error: emailError,
            child: TextFormField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: 'ten@congty.vn',
                prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return 'Vui lòng nhập email';
                if (!text.contains('@')) return 'Email chưa hợp lệ';
                return null;
              },
            ),
          ),
          const SizedBox(height: 20),
          OmniField(
            label: 'Mật khẩu',
            error: passwordError,
            child: TextFormField(
              controller: password,
              obscureText: obscure,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => onSubmit(),
              decoration: InputDecoration(
                hintText: 'Nhập mật khẩu',
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                  onPressed: onTogglePassword,
                ),
              ),
              validator: (value) =>
                  (value ?? '').isEmpty ? 'Vui lòng nhập mật khẩu' : null,
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.error.withValues(alpha: .08),
                borderRadius: OmniRadius.mdAll,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 18,
                    color: scheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      error!,
                      style: OmniType.caption.copyWith(color: scheme.error),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: submitting ? null : onSubmit,
              child: submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Đăng nhập'),
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: Text(
              '${AppConfig.appName} · Bảo mật cho đội ngũ của bạn',
              style: OmniType.micro.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
