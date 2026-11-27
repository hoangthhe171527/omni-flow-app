import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/error/app_exception.dart';
import '../../../design/components/omni_feedback.dart';
import '../../../design/platform/omni_motion_scope.dart';
import '../../../design/tokens/tokens.dart';
import '../application/password_strength.dart';
import '../auth_module.dart';
import '../data/auth_onboarding_api.dart';
import 'widgets/auth_widgets.dart';

/// Màn quên mật khẩu — hướng "Quỹ đạo" (duyệt 26/11/2026). Giữa màn là ô
/// vuông xanh có phong bì, sóng tròn lan ra như đang phát tín hiệu, một chấm
/// sáng chạy vòng. Hai bước:
/// 1. "Quên mật khẩu?": một ô email (điền sẵn email vừa gõ ở màn đăng nhập,
///    bàn phím bật sẵn) + "Gửi liên kết";
/// 2. gửi xong: ô chuyển xanh lá, phong bì bay đi, dấu ✓ bật vào; "Đã gửi
///    liên kết", thẻ 3 bước (bước 1 chạm để mở ứng dụng email), nút "Gửi lại
///    sau N giây" đếm ngược 30 giây rồi bật lại; "Dùng email khác" là nút chữ.
/// Chân màn: "Nhớ ra rồi? Đăng nhập".
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
      showOmniToast(context, 'Không mở được ứng dụng email.');
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
      footer: AuthSwitchLink(
        prompt: 'Nhớ ra rồi?',
        action: 'Đăng nhập',
        onTap: _back,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthSubBar(onBack: _back),
          _MailHero(sent: _sent),
          const SizedBox(height: 8),
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
          const AuthHeroTitle(
            title: 'Quên mật khẩu?',
            subtitle: 'Nhập email, Viomni gửi liên kết đặt lại.',
            center: true,
          ),
          const SizedBox(height: 24),
          AuthFieldGroup(
            fields: [
              AuthGroupField(
                controller: _email,
                label: 'Email',
                hint: 'Email làm việc',
                icon: LucideIcons.mail,
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
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            AuthErrorBox(message: _error!),
          ],
          const SizedBox(height: 16),
          AuthPrimaryButton(
            label: 'Gửi liên kết',
            busy: _busy,
            onPressed: _busy ? null : _submit,
          ),
        ],
      ),
    );
  }

  Widget _sentBody() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      key: const ValueKey('forgot-sent'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthHeroTitle(
          title: 'Đã gửi liên kết',
          subtitle: 'Kiểm tra hộp thư ',
          emphasis: _sentTo,
          center: true,
        ),
        const SizedBox(height: 24),
        _StepsCard(onOpenMail: _openMail),
        if (_error != null) ...[
          const SizedBox(height: 12),
          AuthErrorBox(message: _error!),
        ],
        const SizedBox(height: 16),
        // Đếm ngược chỉ dựng lại nút này, không dựng lại cả trang mỗi giây.
        ValueListenableBuilder<int>(
          valueListenable: _left,
          builder: (context, left, _) => AuthPrimaryButton(
            label: left > 0 ? 'Gửi lại sau $left giây' : 'Gửi lại',
            busy: _busy,
            onPressed: left <= 0 && !_busy ? () => _send(_sentTo) : null,
          ),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: _busy ? null : _changeEmail,
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
            foregroundColor: scheme.primary,
            textStyle: OmniType.body.copyWith(fontWeight: FontWeight.w600),
          ),
          child: const Text('Dùng email khác'),
        ),
      ],
    );
  }
}

/// Thẻ 3 bước làm tiếp sau khi gửi. Bước 1 chạm được: mở ứng dụng email.
class _StepsCard extends StatelessWidget {
  const _StepsCard({required this.onOpenMail});

  final VoidCallback onOpenMail;

  static const _steps = [
    'Mở email từ Viomni',
    'Bấm "Đặt lại mật khẩu"',
    'Đăng nhập bằng mật khẩu mới',
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget row(int i) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${i + 1}',
              style: OmniType.micro.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _steps[i],
              style: OmniType.body.copyWith(color: scheme.onSurface),
            ),
          ),
          if (i == 0)
            Icon(
              LucideIcons.arrowUpRight,
              size: OmniIconSize.sm,
              color: scheme.primary,
            ),
        ],
      ),
    );

    return Material(
      color: scheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OmniRadius.xl),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              child: InkWell(
                key: const ValueKey('forgot-open-mail'),
                onTap: onOpenMail,
                child: row(0),
              ),
            ),
            row(1),
            row(2),
          ],
        ),
      ),
    );
  }
}

/// Phong bì đặc Phosphor Fill (U+E218, font đã khai trong pubspec).
const _envelopeFill = IconData(0xe218, fontFamily: 'PhosphorFill');

/// Ô vuông bo 30 cỡ 104 dải xanh có phong bì; ba sóng tròn lan ra (2,8 giây,
/// lệch 0,93 giây) và một chấm sáng chạy vòng (6 giây). [sent]: ô chuyển dải
/// xanh lá, phong bì bay đi, dấu ✓ bật vào. Giảm chuyển động: không sóng,
/// chấm đứng yên, đổi trạng thái tức thì.
class _MailHero extends StatefulWidget {
  const _MailHero({required this.sent});

  final bool sent;

  static const double height = 180;

  @override
  State<_MailHero> createState() => _MailHeroState();
}

class _MailHeroState extends State<_MailHero>
    with SingleTickerProviderStateMixin {
  /// 42 giây = 15 nhịp sóng × 7 vòng chấm: hết vòng không bị giật.
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 42),
  );

  static const _blue = [
    Color(0xFF4C8DFF),
    Color(0xFF1D4FD1),
    Color(0xFF13388F),
  ];
  static const _green = [
    Color(0xFF4BE07A),
    Color(0xFF1FA84A),
    Color(0xFF127A34),
  ];

  /// Nảy khi đổi trạng thái — `cubic-bezier(.2,.9,.3,1.3)`.
  static const Curve _pop = Cubic(0.2, 0.9, 0.3, 1.3);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (OmniMotion.enabled(context)) {
      if (!_loop.isAnimating) _loop.repeat();
    } else {
      _loop.stop();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final moving = OmniMotion.enabled(context);
    final sent = widget.sent;
    final duration = moving ? const Duration(milliseconds: 500) : Duration.zero;
    final tones = sent ? _green : _blue;
    final glow = sent ? const Color(0xFF1FA84A) : const Color(0xFF1D4FD1);

    return ExcludeSemantics(
      child: SizedBox(
        height: _MailHero.height,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _HeroPainter(
                    loop: _loop,
                    moving: moving,
                    wave: sent
                        ? const Color(0xFF30D158).withValues(alpha: 0.55)
                        : OmniColors.darkPrimary.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
            AnimatedScale(
              scale: sent ? 1.06 : 1,
              duration: duration,
              curve: _pop,
              child: AnimatedContainer(
                duration: duration,
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: LinearGradient(
                    // Dải 160° của bản duyệt.
                    begin: const Alignment(-0.34, -0.94),
                    end: const Alignment(0.34, 0.94),
                    colors: tones,
                    stops: const [0, 0.6, 1],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: glow.withValues(alpha: 0.5),
                      blurRadius: 50,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: sent ? 1 : 0),
                  duration: duration,
                  curve: _pop,
                  builder: (_, v, _) => Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        opacity: (1 - v).clamp(0.0, 1.0),
                        child: Transform.translate(
                          offset: Offset(40 * v, -40 * v),
                          child: Transform.rotate(
                            angle: 20 * math.pi / 180 * v,
                            child: Transform.scale(
                              scale: 1 - 0.6 * v,
                              child: const Icon(
                                _envelopeFill,
                                size: 48,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Opacity(
                        opacity: v.clamp(0.0, 1.0),
                        child: Transform.rotate(
                          angle: -30 * math.pi / 180 * (1 - v),
                          child: Transform.scale(
                            scale: 0.3 + 0.7 * v,
                            child: const Icon(
                              LucideIcons.check,
                              size: 52,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sóng tròn lan ra + chấm sáng chạy vòng quanh ô phong bì.
class _HeroPainter extends CustomPainter {
  _HeroPainter({required this.loop, required this.moving, required this.wave})
    : super(repaint: loop);

  final Animation<double> loop;
  final bool moving;
  final Color wave;

  static const Curve _spread = Cubic(0.2, 0.6, 0.3, 1);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final t = loop.value * 42;

    if (moving) {
      for (var k = 0; k < 3; k++) {
        final phase = ((t - 0.93 * k) / 2.8) % 1;
        final e = _spread.transform(phase);
        canvas.drawCircle(
          c,
          60 * (0.8 + 1.6 * e),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = wave.withValues(alpha: wave.a * 0.9 * (1 - e)),
        );
      }
    }

    // Chấm sáng trên vòng bán kính 92, bắt đầu ở đỉnh, 6 giây một vòng.
    final angle = -math.pi / 2 + (moving ? t / 6 * 2 * math.pi : 0);
    final dot = c + Offset(math.cos(angle), math.sin(angle)) * 92;
    canvas.drawCircle(
      dot,
      7,
      Paint()
        ..color = OmniColors.darkPrimary.withValues(alpha: 0.8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(dot, 4, Paint()..color = const Color(0xFFBFE6FF));
  }

  @override
  bool shouldRepaint(_HeroPainter old) =>
      old.loop != loop || old.moving != moving || old.wave != wave;
}
