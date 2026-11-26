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

/// Lưu tạm email vừa đăng nhập để màn chọn tổ chức hiển thị ngay cả trước khi
/// `/auth/context` tải xong hồ sơ người dùng.
final authSignedInEmailProvider = StateProvider<String?>((ref) => null);

/// Tiêu đề lớn của các màn xác thực: 28/800, chữ khít −0,02em (như tên màn gốc
/// mỗi tab), giữ dòng cao 1.4 cho dấu tiếng Việt.
TextStyle authTitleStyle(BuildContext context) => OmniType.largeTitle.copyWith(
  fontSize: 28,
  fontWeight: FontWeight.w800,
  letterSpacing: -0.56,
  color: Theme.of(context).colorScheme.onSurface,
);

/// Khung chuẩn của các màn xác thực: nền trơn của app, `SafeArea`, nội dung
/// rộng tối đa 420 căn giữa, cuộn được khi bàn phím bật.
///
/// [footer] được đẩy xuống đáy màn (vùng ngón cái) khi nội dung ngắn, và đi
/// theo nội dung khi nội dung dài hơn màn.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.child,
    this.footer,
    this.top = 8,
    this.scrollController,
  });

  final Widget child;
  final Widget? footer;

  /// Khoảng trên cùng, dưới vùng an toàn.
  final double top;

  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    // Đọc bàn phím TRƯỚC Scaffold: Scaffold gỡ viewInsets khỏi MediaQuery của
    // thân màn, bên trong không còn biết bàn phím đang bật.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _AuthKeyboard(
        open: keyboard,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Lề 20, rộng hơn 420 + 40 thì căn giữa cột 420 (máy tính bảng).
              final side = math.max(20.0, (constraints.maxWidth - 420) / 2);
              return CustomScrollView(
                controller: scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
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
                            const SizedBox(height: OmniSpacing.xxl),
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
        ),
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

/// Logo trần 56 (không ô nền — khung chỉ dành cho icon app) và tiêu đề lớn căn
/// giữa. Logo là đích bay của màn mở app ([BrandAnchor]) và thu gọn khi bàn
/// phím bật để ô nhập và nút chính lên vùng nhìn thấy.
class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({
    super.key,
    required this.title,
    this.anchorBrand = false,
  });

  final String title;
  final bool anchorBrand;

  static const double logoSize = 56;

  @override
  Widget build(BuildContext context) {
    final keyboard = _AuthKeyboard.of(context);
    const mark = OmniBrandMark(size: logoSize, framed: false);
    final logo = anchorBrand ? const BrandAnchor(child: mark) : mark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSize(
          duration: OmniMotion.enabled(context)
              ? OmniDuration.base
              : Duration.zero,
          curve: OmniCurves.standard,
          alignment: Alignment.topCenter,
          child: keyboard
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 16),
                  child: Center(child: logo),
                ),
        ),
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: authTitleStyle(context),
          ),
        ),
      ],
    );
  }
}

/// Ô nhập của màn xác thực: nhãn luôn hiện phía trên (kèm liên kết phụ bên
/// phải nếu có, vd "Quên?"), ô cao 52 bo 10 nền thẻ, viền 3:1; đang gõ thì viền
/// xanh, lỗi thì viền đỏ + chữ lỗi bên dưới. Rung 400ms khi báo lỗi.
class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.shake,
    required this.validator,
    this.serverError,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.suffix,
    this.autofillHints,
    this.labelTrailing,
    this.focusNode,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final Animation<double> shake;
  final String? Function(String?) validator;
  final String? serverError;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;
  final Iterable<String>? autofillHints;

  /// Liên kết nhỏ cùng hàng nhãn, canh phải (vd "Quên?").
  final Widget? labelTrailing;

  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(AuthField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocus)?.removeListener(_onFocusChange);
      _focus.addListener(_onFocusChange);
    }
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _ownFocus?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FormField<String>(
      validator: (_) => widget.validator(widget.controller.text),
      builder: (field) {
        final error = field.errorText ?? widget.serverError;
        final focused = _focus.hasFocus;
        final dangerFg = OmniColors.dangerTextOf(context);
        final edge = error != null
            ? dangerFg
            : focused
            ? scheme.primary
            : scheme.outline;

        final box = DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: OmniRadius.mdAll,
            border: Border.all(color: edge),
            // Viền dày 2 khi đang gõ / lỗi vẽ bằng bóng đặc 1px phía ngoài —
            // không đổi kích thước ô, chữ không xê dịch.
            boxShadow: error != null || focused
                ? [BoxShadow(color: edge, spreadRadius: 1)]
                : null,
          ),
          child: SizedBox(
            height: 52,
            child: Row(
              children: [
                const SizedBox(width: 14),
                Expanded(
                  child: Semantics(
                    label: widget.label,
                    textField: true,
                    child: TextField(
                      autofillHints: widget.autofillHints,
                      controller: widget.controller,
                      focusNode: _focus,
                      autofocus: widget.autofocus,
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
                        fontSize: 17,
                        color: scheme.onSurface,
                      ),
                      cursorColor: scheme.primary,
                      decoration: InputDecoration(
                        hintText: widget.hint,
                        hintStyle: OmniType.input.copyWith(
                          fontSize: 17,
                          color: scheme.onSurfaceVariant,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        filled: false,
                        isCollapsed: true,
                        // Theme chung có contentPadding riêng — ở đây lề đã
                        // nằm ở hàng bọc ngoài (14), chữ không thụt thêm.
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
                if (widget.suffix != null)
                  widget.suffix!
                else
                  const SizedBox(width: 14),
              ],
            ),
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 36,
              child: Row(
                children: [
                  const SizedBox(width: 2),
                  Expanded(
                    child: ExcludeSemantics(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: OmniType.bodySm.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  ?widget.labelTrailing,
                ],
              ),
            ),
            AnimatedBuilder(
              animation: widget.shake,
              builder: (_, child) {
                final t = widget.shake.value;
                final dx = error == null
                    ? 0.0
                    : math.sin(t * math.pi * 6) * 6 * (1 - t);
                return Transform.translate(offset: Offset(dx, 0), child: child);
              },
              child: box,
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 6, 2, 0),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    error,
                    style: OmniType.caption.copyWith(color: dangerFg),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Liên kết chữ nhỏ cùng hàng nhãn ô nhập ("Quên?"): chữ xanh 14/600, vùng chạm
/// rộng tối thiểu 44.
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
          constraints: const BoxConstraints(minWidth: 44, minHeight: 36),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: OmniType.bodySm.copyWith(
                  fontWeight: FontWeight.w600,
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
      padding: const EdgeInsets.symmetric(vertical: OmniSpacing.lg),
      child: Row(
        children: [
          Expanded(child: Divider(color: scheme.outlineVariant)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: OmniSpacing.md),
            child: Text(
              'hoặc',
              style: OmniType.bodySm.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(child: Divider(color: scheme.outlineVariant)),
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

/// Nút chính của các màn xác thực: viên thuốc xanh đặc cao 52, chữ 17/700; hiện
/// vòng quay thay chữ khi [busy] mà không đổi kích thước nút.
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
      onPressed: busy ? () {} : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
        textStyle: OmniType.input.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: busy
          ? SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator.adaptive(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(scheme.onPrimary),
              ),
            )
          : Text(label),
    );
  }
}

/// Nút "Tiếp tục với Google": viên thuốc cao 52 nền thẻ viền mảnh, biểu tượng
/// 4 màu, chữ 17/600 — bậc phụ, nằm TRÊN ô nhập (người quay lại vào một chạm).
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
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.outlineVariant),
        textStyle: OmniType.input.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Không mở được liên kết. Vui lòng thử lại.'),
      ),
    );
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
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
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
