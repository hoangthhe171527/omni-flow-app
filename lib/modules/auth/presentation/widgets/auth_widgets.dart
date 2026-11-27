import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/app_config.dart';
import '../../../../design/components/components.dart';
import '../../../../design/platform/omni_motion_scope.dart';
import '../../../../design/tokens/tokens.dart';

export 'auth_field.dart';

/// Lưu tạm email vừa đăng nhập để màn chọn tổ chức hiển thị ngay cả trước khi
/// `/auth/context` tải xong hồ sơ người dùng.
final authSignedInEmailProvider = StateProvider<String?>((ref) => null);

/// Tiêu đề lớn của các màn xác thực (hướng "Quỹ đạo", duyệt 26/11/2026):
/// 32/800, chữ khít −0,02em, căn trái.
TextStyle authTitleStyle(BuildContext context) => OmniOrbitType.heroTitle
    .copyWith(color: Theme.of(context).colorScheme.onSurface);

/// Khung chuẩn của các màn xác thực: nền trơn của app, `SafeArea`, nội dung
/// rộng tối đa 420 căn giữa, cuộn được khi bàn phím bật.
///
/// [footer] được đẩy xuống đáy màn (vùng ngón cái) khi nội dung ngắn, và đi
/// theo nội dung khi nội dung dài hơn màn. [backdrop] là lớp trang trí nằm
/// sau nội dung, phủ cả màn (quỹ đạo nhỏ góc trên phải ở màn Đăng ký).
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.child,
    this.footer,
    this.top = 8,
    this.scrollController,
    this.backdrop,
  });

  final Widget child;
  final Widget? footer;
  final Widget? backdrop;

  /// Khoảng trên cùng, dưới vùng an toàn.
  final double top;

  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    // Đọc bàn phím TRƯỚC Scaffold: Scaffold gỡ viewInsets khỏi MediaQuery của
    // thân màn, bên trong không còn biết bàn phím đang bật.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final decoration = backdrop;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _AuthKeyboard(
        open: keyboard,
        child: decoration == null
            ? _body()
            : Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ExcludeSemantics(child: decoration),
                    ),
                  ),
                  _body(),
                ],
              ),
      ),
    );
  }

  Widget _body() {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Lề 20, rộng hơn 420 + 40 thì căn giữa cột 420 (máy tính bảng).
          final side = math.max(20.0, (constraints.maxWidth - 420) / 2);
          return CustomScrollView(
            controller: scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(side, top, side, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      child,
                      if (footer != null) ...[
                        const Spacer(),
                        const SizedBox(height: 16),
                        footer!,
                      ],
                    ],
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

/// Bàn phím có đang bật không, đọc ở [AuthScaffold] (trên Scaffold).
class _AuthKeyboard extends InheritedWidget {
  const _AuthKeyboard({required this.open, required super.child});

  final bool open;

  /// Ngoài [AuthScaffold] thì đọc thẳng MediaQuery.
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_AuthKeyboard>()?.open ??
      MediaQuery.viewInsetsOf(context).bottom > 0;

  @override
  bool updateShouldNotify(_AuthKeyboard old) => old.open != open;
}

/// Thanh đầu màn con (Đăng ký, Quên mật khẩu): `‹` xanh trơn 44×44, không vòng
/// kính, không tiêu đề (tiêu đề lớn nằm ngay dưới).
class AuthSubBar extends StatelessWidget {
  const AuthSubBar({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Transform.translate(
        // Đưa nét ‹ thẳng mép chữ tiêu đề bên dưới, vùng chạm vẫn đủ 44.
        offset: const Offset(-12, 0),
        child: IconButton(
          tooltip: 'Quay lại',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          onPressed: () {
            HapticFeedback.selectionClick();
            onBack();
          },
          icon: Icon(
            LucideIcons.chevronLeft,
            size: 28,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

/// Đầu màn đăng nhập (hướng "Quỹ đạo", duyệt 26/11/2026): quỹ đạo tỉ lệ .78
/// có các hành tinh kênh chạy quanh chữ V. Logo giữa là đích bay của màn mở
/// app ([BrandAnchor]) — vòng của màn mở app thu về đúng chỗ này. Thu gọn khi
/// bàn phím bật để ô nhập và nút chính lên vùng nhìn thấy.
class AuthOrbitHeader extends StatelessWidget {
  const AuthOrbitHeader({super.key, this.anchorBrand = false});

  final bool anchorBrand;

  /// Tỉ lệ quỹ đạo so với màn mở app.
  static const double scale = 0.78;

  /// Chiều cao khối quỹ đạo.
  static const double height = 180;

  @override
  Widget build(BuildContext context) {
    final keyboard = _AuthKeyboard.of(context);
    return AnimatedSize(
      duration: OmniMotion.enabled(context) ? OmniDuration.base : Duration.zero,
      curve: OmniCurves.standard,
      alignment: Alignment.topCenter,
      child: keyboard
          ? const SizedBox(width: double.infinity)
          : SizedBox(
              height: height,
              child: Center(
                child: OmniOrbit(
                  scale: scale,
                  planets: true,
                  anchorLogo: anchorBrand,
                ),
              ),
            ),
    );
  }
}

/// Tiêu đề lớn 32/800 + dòng phụ 15 xám. [emphasis] nối vào cuối dòng phụ,
/// chữ đậm màu chữ chính (vd email vừa gửi). [center] cho màn Quên mật khẩu.
class AuthHeroTitle extends StatelessWidget {
  const AuthHeroTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.emphasis,
    this.center = false,
  });

  final String title;
  final String? subtitle;
  final String? emphasis;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final align = center ? TextAlign.center : TextAlign.start;
    final meta = OmniType.body.copyWith(color: scheme.onSurfaceVariant);
    final sub = subtitle;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(title, textAlign: align, style: authTitleStyle(context)),
        ),
        if (sub != null) ...[
          const SizedBox(height: 8),
          if (emphasis == null)
            Text(sub, textAlign: align, style: meta)
          else
            Semantics(
              liveRegion: true,
              child: Text.rich(
                TextSpan(
                  text: sub,
                  children: [
                    TextSpan(
                      text: emphasis,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                textAlign: align,
                style: meta,
              ),
            ),
        ],
      ],
    );
  }
}

/// Liên kết chữ xanh 15/500 ("Quên mật khẩu?" căn phải dưới nhóm ô), vùng
/// chạm tối thiểu 44 × 40.
class AuthLabelLink extends StatelessWidget {
  const AuthLabelLink({
    super.key,
    required this.label,
    required this.onTap,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    // Nút ngữ nghĩa riêng: không để trình đọc màn hình gộp "Quên mật khẩu"
    // vào nhãn của ô mật khẩu ngay bên dưới.
    return Semantics(
      container: true,
      button: true,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: OmniRadius.smAll,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: OmniType.body.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Nút mắt hiện/ẩn mật khẩu giữ đúng nhãn trạng thái cho trình đọc màn hình.
class AuthPasswordToggle extends StatelessWidget {
  const AuthPasswordToggle({
    super.key,
    required this.obscure,
    required this.onToggle,
  });

  final bool obscure;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
      onPressed: onToggle,
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      icon: Icon(
        obscure ? LucideIcons.eye : LucideIcons.eyeOff,
        size: OmniIconSize.lg,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Divider(thickness: 0.5, color: scheme.outlineVariant),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'hoặc',
              style: OmniType.caption.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Divider(thickness: 0.5, color: scheme.outlineVariant),
          ),
        ],
      ),
    );
  }
}

/// Biểu tượng Google Vector 4 màu chuẩn chính thức (viewBox 0 0 24 24).
class AuthGoogleGlyph extends StatelessWidget {
  const AuthGoogleGlyph({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: const _GoogleMarkPainter(),
      ),
    );
  }
}

class _GoogleMarkPainter extends CustomPainter {
  const _GoogleMarkPainter();

  // 4 màu thương hiệu chính thức của biểu tượng Google 'G'.
  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  static final Path _bluePath = Path()
    ..moveTo(22.56, 12.25)
    ..relativeCubicTo(0, -0.78, -0.07, -1.53, -0.2, -2.25)
    ..lineTo(12, 10)
    ..relativeLineTo(0, 4.26)
    ..relativeLineTo(5.92, 0)
    ..relativeCubicTo(-0.26, 1.37, -1.04, 2.53, -2.21, 3.31)
    ..relativeLineTo(0, 2.77)
    ..relativeLineTo(3.57, 0)
    ..relativeCubicTo(2.08, -1.92, 3.28, -4.74, 3.28, -8.09)
    ..close();

  static final Path _greenPath = Path()
    ..moveTo(12, 23)
    ..relativeCubicTo(2.97, 0, 5.46, -0.98, 7.28, -2.66)
    ..relativeLineTo(-3.57, -2.77)
    ..relativeCubicTo(-0.98, 0.66, -2.23, 1.06, -3.71, 1.06)
    ..relativeCubicTo(-2.86, 0, -5.29, -1.93, -6.16, -4.53)
    ..lineTo(2.18, 14.1)
    ..relativeLineTo(0, 2.84)
    ..cubicTo(3.99, 20.53, 7.7, 23, 12, 23)
    ..close();

  static final Path _yellowPath = Path()
    ..moveTo(5.84, 14.09)
    ..relativeCubicTo(-0.22, -0.66, -0.35, -1.36, -0.35, -2.09)
    ..relativeCubicTo(0, -0.73, 0.13, -1.43, 0.35, -2.09)
    ..lineTo(5.84, 7.07)
    ..lineTo(2.18, 7.07)
    ..cubicTo(1.43, 8.55, 1, 10.22, 1, 12)
    ..relativeCubicTo(0, 1.78, 0.43, 3.45, 1.18, 4.93)
    ..relativeLineTo(2.85, -2.22)
    ..relativeLineTo(0.81, -0.62)
    ..close();

  static final Path _redPath = Path()
    ..moveTo(12, 5.38)
    ..relativeCubicTo(1.62, 0, 3.06, 0.56, 4.21, 1.64)
    ..relativeLineTo(3.15, -3.15)
    ..cubicTo(17.45, 2.09, 14.97, 1, 12, 1)
    ..cubicTo(7.7, 1, 3.99, 3.47, 2.18, 7.07)
    ..relativeLineTo(3.66, 2.84)
    ..relativeCubicTo(0.87, -2.6, 3.3, -4.53, 6.16, -4.53)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = _blue;
    canvas.drawPath(_bluePath, paint);

    paint.color = _green;
    canvas.drawPath(_greenPath, paint);

    paint.color = _yellow;
    canvas.drawPath(_yellowPath, paint);

    paint.color = _red;
    canvas.drawPath(_redPath, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GoogleMarkPainter oldDelegate) => false;
}

/// Hộp báo lỗi chung: nền đỏ nhạt, chữ đỏ đậm, đọc ngay bởi trình đọc màn
/// hình. [actionLabel] là lối sửa đi kèm (vd "Đặt lại mật khẩu").
class AuthErrorBox extends StatelessWidget {
  const AuthErrorBox({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = OmniColors.dangerTextOf(context);

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: dark
              ? OmniColors.dangerTextDark.withValues(alpha: 0.12)
              : OmniColors.dangerSoft,
          // Hộp báo nhỏ cỡ ô nhập → bo 10 (thang 6/10/16/32).
          borderRadius: OmniRadius.mdAll,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                LucideIcons.circleAlert,
                size: OmniIconSize.lg,
                color: fg,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message, style: OmniType.body.copyWith(color: fg)),
                  if (actionLabel != null && onAction != null)
                    InkWell(
                      onTap: onAction,
                      borderRadius: OmniRadius.smAll,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          actionLabel!,
                          style: OmniType.body.copyWith(
                            color: fg,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            decorationColor: fg,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nút chính của các màn xác thực (hướng "Quỹ đạo", duyệt 26/11/2026): cao 54,
/// tròn hẳn, nền [OmniColors.primaryFillOf] chữ trắng 17/600, một vệt sáng
/// lướt qua chậm (mỗi 3,2 giây). Đang gửi ([busy]): nút co thành tròn 54 với
/// vòng xoay. Giảm chuyển động: không vệt sáng, co ngay không chuyển.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  static const double height = 54;

  /// Co lại: `cubic-bezier(.2,.9,.3,1)` trong 350ms.
  static const Curve _shrink = Cubic(0.2, 0.9, 0.3, 1);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motion = OmniMotion.of(context);
    final enabled = onPressed != null;
    // Chiều cao cố định bọc ngoài: khung màn xác thực đo chiều cao nội tại
    // (SliverFillRemaining), mà LayoutBuilder không trả lời được phép đo đó.
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, box) {
          final full = box.maxWidth.isFinite ? box.maxWidth : 320.0;
          return Center(
            child: AnimatedContainer(
              duration: motion.enabled
                  ? const Duration(milliseconds: 350)
                  : Duration.zero,
              curve: _shrink,
              width: busy ? height : full,
              height: height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FilledButton(
                    onPressed: busy ? () {} : onPressed,
                    style: FilledButton.styleFrom(
                      backgroundColor: OmniColors.primaryFillOf(context),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: scheme.surfaceContainerHighest,
                      disabledForegroundColor: scheme.onSurfaceVariant,
                      minimumSize: const Size(height, height),
                      padding: busy
                          ? EdgeInsets.zero
                          : const EdgeInsets.symmetric(horizontal: 16),
                      shape: const StadiumBorder(),
                      textStyle: OmniOrbitType.button,
                    ),
                    child: busy
                        ? const SizedBox.square(
                            dimension: 26,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                              backgroundColor: Color(0x40FFFFFF),
                            ),
                          )
                        : Text(label, maxLines: 1, softWrap: false),
                  ),
                  if (enabled && !busy && motion.enabled)
                    const IgnorePointer(
                      child: ClipRRect(
                        borderRadius: BorderRadius.all(
                          Radius.circular(height / 2),
                        ),
                        child: _ShineSweep(),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Vệt sáng 60dp lướt chéo qua nút MỘT lần khi vào màn: chờ 1,2 giây rồi lướt
/// trong 35% đầu chu kỳ 3,2 giây. Không lặp — chuyển động lặp vô cớ làm phân
/// tâm (tiêu chí 9).
class _ShineSweep extends StatefulWidget {
  const _ShineSweep();

  @override
  State<_ShineSweep> createState() => _ShineSweepState();
}

class _ShineSweepState extends State<_ShineSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
    // Bắt đầu ở 62,5%: còn 1,2 giây nữa mới tới lượt lướt đầu.
    value: 0.625,
  );

  @override
  void initState() {
    super.initState();
    // `then` chỉ chạy khi chạy XONG (huỷ lúc dispose thì không) → một lượt.
    _c.forward().then((_) {
      if (mounted) _c.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _ShinePainter(_c), size: Size.infinite);
}

class _ShinePainter extends CustomPainter {
  _ShinePainter(this.phase) : super(repaint: phase);

  final Animation<double> phase;

  @override
  void paint(Canvas canvas, Size size) {
    final p = phase.value;
    if (p >= 0.35) return;
    const band = 60.0;
    final x = -80 + (size.width * 1.1 + 80) * (p / 0.35);
    final rect = Rect.fromLTWH(x, 0, band, size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x00FFFFFF), Color(0x59FFFFFF), Color(0x00FFFFFF)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_ShinePainter old) => old.phase != phase;
}

/// Nút "Tiếp tục với Google": thứ yếu, cao 54 tròn hẳn, nền thẻ viền mảnh,
/// biểu tượng 4 màu, chữ 16/600 — nằm dưới nút chính, sau "hoặc".
class AuthGoogleButton extends StatelessWidget {
  const AuthGoogleButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      key: const ValueKey('google-sign-in'),
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(AuthPrimaryButton.height),
        shape: const StadiumBorder(),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.outlineVariant, width: 0.5),
        textStyle: OmniType.input.copyWith(fontWeight: FontWeight.w600),
      ),
      icon: busy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator.adaptive(strokeWidth: 2),
            )
          : const AuthGoogleGlyph(),
      label: Text(label),
    );
  }
}

/// Dòng "Chưa có tài khoản? Đăng ký" ở chân màn: chữ phụ + liên kết xanh.
class AuthSwitchLink extends StatelessWidget {
  const AuthSwitchLink({
    super.key,
    required this.prompt,
    required this.action,
    required this.onTap,
  });

  final String prompt;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '$prompt ',
          style: OmniType.body.copyWith(color: scheme.onSurfaceVariant),
        ),
        InkWell(
          onTap: onTap,
          borderRadius: OmniRadius.smAll,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            child: Text(
              action,
              style: OmniType.body.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Dòng pháp lý chữ nhỏ: [prefix] (nếu có) + liên kết "Chính sách bảo mật".
/// Cửa hàng ứng dụng đòi chính sách luôn mở được từ màn đầu tiên người dùng
/// thấy. Web chưa có trang Điều khoản nên chưa có liên kết đó.
class AuthPrivacyLink extends StatelessWidget {
  const AuthPrivacyLink({super.key, this.prefix});

  final String? prefix;

  Future<void> _open(BuildContext context) async {
    final opened = await launchUrl(
      AppConfig.privacyPolicyUrl,
      mode: LaunchMode.externalApplication,
    );
    if (opened || !context.mounted) return;
    showOmniToast(context, 'Không mở được liên kết. Vui lòng thử lại.');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = OmniType.micro.copyWith(
      fontWeight: FontWeight.w400,
      color: scheme.onSurfaceVariant,
    );
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (prefix != null) Text('$prefix ', style: style),
        InkWell(
          key: const ValueKey('privacy-link'),
          onTap: () => _open(context),
          borderRadius: OmniRadius.smAll,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
            child: Text(
              'Chính sách bảo mật',
              style: style.copyWith(
                color: scheme.onSurface,
                decoration: TextDecoration.underline,
                decorationColor: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
