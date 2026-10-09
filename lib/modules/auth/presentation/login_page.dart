import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/components/components.dart';
import '../../../design/platform/omni_motion_scope.dart';
import '../../../design/tokens/tokens.dart';
import '../application/login_controller.dart';
import '../auth_module.dart';

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
    if (!_formKey.currentState!.validate()) {
      _shakeIfAllowed();
      return;
    }
    FocusScope.of(context).unfocus();
    await ref
        .read(loginControllerProvider.notifier)
        .submit(email: _email.text.trim(), password: _password.text);
    // Navigation is the router's job: a successful login flips the session
    // status and the redirect takes the user to their first visible tab.
  }

  Future<void> _submitGoogle() async {
    FocusScope.of(context).unfocus();
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
                    _LoginField(
                      controller: _email,
                      hint: 'Email làm việc',
                      icon: Icons.mail_outline_rounded,
                      shake: _shake,
                      serverError: state.errorFor('email'),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      style: inputText,
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return 'Vui lòng nhập email';
                        if (!text.contains('@')) return 'Email chưa hợp lệ';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _LoginField(
                      controller: _password,
                      hint: 'Mật khẩu',
                      icon: Icons.lock_outline_rounded,
                      shake: _shake,
                      serverError: state.errorFor('password'),
                      obscure: _obscure,
                      textInputAction: TextInputAction.done,
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
                      _LoginError(message: state.error!),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 8),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.25),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: FilledButton(
                        onPressed: state.submitting ? null : _submit,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: OmniType.input.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: state.submittingMethod == LoginMethod.password
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: scheme.onPrimary,
                                ),
                              )
                            : const Text('Đăng nhập'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const _LoginDivider(),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      key: const ValueKey('google-sign-in'),
                      onPressed: state.submitting ? null : _submitGoogle,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: state.submittingMethod == LoginMethod.google
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const _GoogleGlyph(),
                      label: const Text('Tiếp tục với Google'),
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
    );
  }
}

/// Ô nhập một dòng: cao 50, bo 10, viền thường / viền `primary` + vầng 3px khi
/// focus / viền đỏ + rung + chữ lỗi dưới ô.
class _LoginField extends StatefulWidget {
  const _LoginField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.shake,
    required this.validator,
    required this.style,
    this.serverError,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.suffix,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final Animation<double> shake;
  final String? Function(String?) validator;
  final TextStyle style;
  final String? serverError;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;

  @override
  State<_LoginField> createState() => _LoginFieldState();
}

class _LoginFieldState extends State<_LoginField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;

    return FormField<String>(
      validator: (_) => widget.validator(widget.controller.text),
      builder: (field) {
        final error = field.errorText ?? widget.serverError;
        final focused = _focus.hasFocus;
        final border = error != null
            ? OmniColors.destructive
            : focused
            ? scheme.primary
            : OmniColors.byBrightness(
                context,
                const Color(0xFFE3E8EF),
                OmniColors.darkBorder,
              );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedBuilder(
              animation: widget.shake,
              builder: (_, child) {
                final t = widget.shake.value;
                final dx = error == null
                    ? 0.0
                    : math.sin(t * math.pi * 6) * 6 * (1 - t);
                return Transform.translate(offset: Offset(dx, 0), child: child);
              },
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: border),
                  boxShadow: focused && error == null
                      ? [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.14),
                            spreadRadius: 3,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    Icon(widget.icon, size: OmniIconSize.md, color: muted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: widget.controller,
                        focusNode: _focus,
                        obscureText: widget.obscure,
                        keyboardType: widget.keyboardType,
                        textInputAction: widget.textInputAction,
                        autocorrect: false,
                        enableSuggestions: !widget.obscure,
                        onSubmitted: widget.onSubmitted,
                        onChanged: (_) {
                          if (field.hasError) field.reset();
                        },
                        style: widget.style,
                        decoration: InputDecoration(
                          hintText: widget.hint,
                          hintStyle: widget.style.copyWith(color: muted),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    widget.suffix ?? const SizedBox(width: 14),
                  ],
                ),
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    error,
                    style: OmniType.caption.copyWith(
                      color: OmniColors.dangerTextOf(context),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _LoginDivider extends StatelessWidget {
  const _LoginDivider();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outlineVariant;
    return Row(
      children: [
        Expanded(child: Divider(color: color)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: OmniSpacing.md),
          child: Text(
            'hoặc',
            style: OmniType.caption.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: Divider(color: color)),
      ],
    );
  }
}

class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      excludeSemantics: true,
      child: Text(
        'G',
        style: OmniType.title.copyWith(
          color: const Color(0xFF4285F4),
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    );
  }
}

/// Hộp báo lỗi: nền đỏ nhạt, chữ đỏ đậm, đọc được bởi trình đọc màn hình ngay
/// khi hiện ra (`role="alert"` trong thiết kế).
class _LoginError extends StatelessWidget {
  const _LoginError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = OmniColors.dangerTextOf(context);

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: OmniSpacing.md,
        ),
        decoration: BoxDecoration(
          color: dark
              ? OmniColors.dangerTextDark.withValues(alpha: 0.12)
              : OmniColors.dangerSoft,
          borderRadius: OmniRadius.mdAll,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                Icons.error_outline_rounded,
                size: OmniIconSize.md,
                color: fg,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: OmniType.body.copyWith(height: 20 / 14, color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
