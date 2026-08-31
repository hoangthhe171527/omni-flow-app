import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

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

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: OmniSpacing.xxl,
                vertical: OmniSpacing.section,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: OmniSpacing.section),
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
                      style: OmniType.displayLg.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: OmniSpacing.sm),
                    Text(
                      'Nhập thông tin để tiếp tục xử lý công việc và hỗ trợ khách hàng.',
                      style: OmniType.body.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: OmniSpacing.section),

                    OmniField(
                      label: 'Email làm việc',
                      error: state.errorFor('email'),
                      child: TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: 'ten@congty.vn',
                          prefixIcon: Icon(
                            Icons.mail_outline_rounded,
                            size: 20,
                          ),
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
                      error: state.errorFor('password'),
                      child: TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          // Not "••••••••": a dotted hint reads as an already-filled
                          // field, and users tap "Đăng nhập" on an empty form.
                          hintText: 'Nhập mật khẩu',
                          prefixIcon: const Icon(
                            Icons.lock_outline_rounded,
                            size: 20,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
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
                      const SizedBox(height: OmniSpacing.lg),
                      Container(
                        padding: const EdgeInsets.all(OmniSpacing.md),
                        decoration: BoxDecoration(
                          color: scheme.error.withValues(alpha: 0.08),
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
                                state.error!,
                                style: OmniType.caption.copyWith(
                                  color: scheme.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: OmniSpacing.xxl),
                    FilledButton(
                      onPressed: state.submitting ? null : _submit,
                      child: state.submitting
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
                    const SizedBox(height: OmniSpacing.xxl),
                    Center(
                      child: Column(
                        children: [
                          Text(
                            AppConfig.appName,
                            style: OmniType.micro.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: OmniSpacing.xs),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: OmniSpacing.xs,
                            children: [
                              TextButton(
                                onPressed: () =>
                                    _openLink(AppConfig.forgotPasswordUrl),
                                child: const Text('Quên mật khẩu'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    _openLink(AppConfig.privacyPolicyUrl),
                                child: const Text('Quyền riêng tư'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    _openLink(AppConfig.supportUrl),
                                child: const Text('Hỗ trợ'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
