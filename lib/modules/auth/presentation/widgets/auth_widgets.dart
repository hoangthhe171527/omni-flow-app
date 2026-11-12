import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/app_config.dart';
import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';

/// Lưu tạm email vừa đăng nhập để màn chọn tổ chức hiển thị ngay cả trước khi
/// `/auth/context` tải xong hồ sơ người dùng.
final authSignedInEmailProvider = StateProvider<String?>((ref) => null);

/// Nền chung của phân hệ xác thực: màu nền hệ thống sạch kèm quầng sáng xanh
/// V-Orbit rất dịu ở đỉnh màn hình.
class AuthBackdrop extends StatelessWidget {
  const AuthBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: DecoratedBox(
        key: const Key('auth-backdrop'),
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.85),
            radius: 1.05,
            colors: [
              OmniColors.primary.withValues(alpha: 0.08),
              OmniColors.primary.withValues(alpha: 0),
            ],
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Khung cuộn chuẩn của các màn xác thực: `SafeArea` + `ConstrainedBox(420)`
/// căn giữa, tự đẩy mượt khi bàn phím bật lên.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 24, 20, 24),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AuthBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: padding,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Thanh đầu màn con (Đăng ký, Quên mật khẩu): nút quay lại kính tròn
/// `OmniGlassCircle` (`‹`) đồng nhất toàn hệ thống.
class AuthSubBar extends StatelessWidget {
  const AuthSubBar({
    super.key,
    required this.onBack,
    this.title,
    this.trailing,
  });

  final VoidCallback onBack;
  final String? title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          OmniGlassCircle(
            child: IconButton(
              tooltip: 'Quay lại',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              onPressed: () {
                HapticFeedback.selectionClick();
                onBack();
              },
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: OmniIconSize.md,
                color: scheme.onSurface,
              ),
            ),
          ),
          Expanded(
            child: title == null
                ? const SizedBox.shrink()
                : Text(
                    title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: OmniType.section.copyWith(color: scheme.onSurface),
                  ),
          ),
          if (trailing != null)
            trailing!
          else if (title != null)
            const SizedBox(width: 44),
        ],
      ),
    );
  }
}

/// Cụm nhận diện thương hiệu đầu màn xác thực: squircle V-Orbit 64×64 (tuỳ chọn
/// neo `BrandAnchor` cho hiệu ứng bay từ Intro), `OmniWordmark`, tiêu đề và dòng
/// phụ tinh gọn.
class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.anchorBrand = false,
    this.showWordmark = true,
    this.brandSemanticLabel,
    this.headerSemantics = false,
  });

  final String title;
  final String? subtitle;
  final bool anchorBrand;
  final bool showWordmark;
  final String? brandSemanticLabel;
  final bool headerSemantics;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mark = OmniBrandMark(size: 64, semanticLabel: brandSemanticLabel);
    final anchoredMark = anchorBrand ? BrandAnchor(child: mark) : mark;

    final titleWidget = Text(
      title,
      textAlign: TextAlign.center,
      style: OmniType.largeTitle.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            boxShadow: OmniShadows.raised,
          ),
          child: anchoredMark,
        ),
        if (showWordmark) ...[
          const SizedBox(height: 10),
          const OmniWordmark(),
        ],
        const SizedBox(height: 14),
        if (headerSemantics)
          Semantics(header: true, child: titleWidget)
        else
          titleWidget,
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: OmniType.bodySm.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

/// Thẻ nhóm ô nhập chuẩn iOS / Liquid Glass: bo 18, nền `card`, viền mảnh 1px
/// và vạch ngăn mảnh thụt lề giữa các ô xếp chồng.
class AuthFieldGroup extends StatelessWidget {
  const AuthFieldGroup({
    super.key,
    required this.children,
    this.title,
    this.trailingTitle,
    this.dividerIndent = 46,
  });

  final List<Widget> children;
  final String? title;
  final Widget? trailingTitle;
  final double dividerIndent;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null || trailingTitle != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
            child: Row(
              children: [
                if (title != null)
                  Expanded(
                    child: Text(
                      title!,
                      style: OmniType.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  const Spacer(),
                ?trailingTitle,
              ],
            ),
          ),
        Material(
          color: scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    indent: dividerIndent,
                    color: scheme.outlineVariant.withValues(alpha: 0.75),
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Một dòng ô nhập bên trong [AuthFieldGroup]: icon 1 tông gọn gàng, nhãn phụ
/// xếp chồng, rung báo lỗi 400ms và hiện lỗi từng trường bên dưới không vỡ khung.
class AuthGroupField extends StatefulWidget {
  const AuthGroupField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.shake,
    required this.validator,
    this.serverError,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.suffix,
    this.autofillHints,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final Animation<double> shake;
  final String? Function(String?) validator;
  final String? serverError;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;
  final Iterable<String>? autofillHints;

  @override
  State<AuthGroupField> createState() => _AuthGroupFieldState();
}

class _AuthGroupFieldState extends State<AuthGroupField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return FormField<String>(
      validator: (_) => widget.validator(widget.controller.text),
      builder: (field) {
        final error = field.errorText ?? widget.serverError;
        final focused = _focus.hasFocus;
        final dangerFg = OmniColors.dangerTextOf(context);

        final rowFill = error != null
            ? (dark
                  ? OmniColors.dangerTextDark.withValues(alpha: 0.08)
                  : OmniColors.dangerSoft.withValues(alpha: 0.55))
            : focused
            ? scheme.primaryContainer.withValues(alpha: dark ? 0.35 : 0.45)
            : Colors.transparent;

        final accentFg = error != null
            ? dangerFg
            : focused
            ? scheme.primary
            : scheme.onSurfaceVariant;

        return AnimatedBuilder(
          animation: widget.shake,
          builder: (_, child) {
            final t = widget.shake.value;
            final dx = error == null
                ? 0.0
                : math.sin(t * math.pi * 6) * 6 * (1 - t);
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: ColoredBox(
            color: rowFill,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                14,
                9,
                widget.suffix != null ? 4 : 14,
                9,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        excludeFromSemantics: true,
                        behavior: HitTestBehavior.opaque,
                        onTap: _focus.requestFocus,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Icon(
                            widget.icon,
                            size: OmniIconSize.lg,
                            color: accentFg,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              excludeFromSemantics: true,
                              behavior: HitTestBehavior.opaque,
                              onTap: _focus.requestFocus,
                              child: ExcludeSemantics(
                                child: Text(
                                  widget.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: OmniType.micro.copyWith(
                                    color: accentFg,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Semantics(
                              label: widget.label,
                              textField: true,
                              child: TextField(
                                autofillHints: widget.autofillHints,
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
                                style: OmniType.input.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: scheme.onSurface,
                                ),
                                decoration: InputDecoration(
                                  hintText: widget.hint,
                                  hintStyle: OmniType.body.copyWith(
                                    color: scheme.onSurfaceVariant.withValues(
                                      alpha: 0.72,
                                    ),
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                  filled: false,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ?widget.suffix,
                    ],
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 5, left: 32, right: 8),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          error,
                          style: OmniType.micro.copyWith(
                            color: dangerFg,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
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
      icon: Icon(
        obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
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

/// Biểu tượng Google Vector 4 màu chuẩn chính thức (viewBox 0 0 24 24).
class AuthGoogleGlyph extends StatelessWidget {
  const AuthGoogleGlyph({super.key, this.size = 19});

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

/// Hộp báo lỗi: nền đỏ nhạt, chữ đỏ đậm, đọc được bởi trình đọc màn hình ngay
/// khi hiện ra (`role="alert"` trong thiết kế).
class AuthErrorBox extends StatelessWidget {
  const AuthErrorBox({super.key, required this.message});

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
          borderRadius: BorderRadius.circular(14),
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
                style: OmniType.bodySm.copyWith(color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nút chính của các màn xác thực: nút kính viên thuốc cao 50; hiện vòng quay
/// thay chữ khi [busy]. [onPressed] null thì nút bị khoá.
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        shape: const StadiumBorder(),
        textStyle: OmniType.input.copyWith(fontWeight: FontWeight.w600),
      ),
      child: busy
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator.adaptive(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
              ),
            )
          : Text(label),
    );
  }
}

/// Nút Google kính cao 50dp kèm biểu tượng vector 4 màu chuẩn.
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
    return OutlinedButton.icon(
      key: const ValueKey('google-sign-in'),
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        shape: const StadiumBorder(),
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

/// Liên kết "Chính sách bảo mật" ở chân màn đăng nhập/đăng ký — cửa hàng ứng
/// dụng đòi chính sách luôn mở được từ màn đầu tiên người dùng thấy.
class AuthPrivacyLink extends StatelessWidget {
  const AuthPrivacyLink({super.key});

  Future<void> _open(BuildContext context) async {
    final opened = await launchUrl(
      AppConfig.privacyPolicyUrl,
      mode: LaunchMode.externalApplication,
    );
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Không mở được liên kết. Vui lòng thử lại.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InkWell(
        key: const ValueKey('privacy-link'),
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Text(
            'Chính sách bảo mật',
            style: OmniType.micro.copyWith(
              fontWeight: FontWeight.w400,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
