import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../design/platform/omni_motion_scope.dart';
import '../../../../design/tokens/tokens.dart';

/// Nhóm ô nhập kiểu Cài đặt iOS (hướng "Quỹ đạo", duyệt 26/11/2026): nền thẻ,
/// bo 16, các dòng cao 56 xếp liền nhau, vạch ngăn mảnh thụt lề sau icon.
/// [footer] nằm cuối nhóm, không có vạch ngăn (thanh độ mạnh mật khẩu).
class AuthFieldGroup extends StatelessWidget {
  const AuthFieldGroup({super.key, required this.fields, this.footer});

  final List<Widget> fields;
  final Widget? footer;

  /// Vạch ngăn bắt đầu thẳng chữ trong ô: lề 14 + icon 20 + khoảng 12.
  static const double indent = 46;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OmniRadius.xl),
        // Tương phản cao: nền trang và thẻ gần nhau, ranh giới là viền.
        side: MediaQuery.highContrastOf(context)
            ? BorderSide(color: scheme.outline)
            : BorderSide.none,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < fields.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.only(left: indent),
                child: SizedBox(
                  height: 0.5,
                  child: ColoredBox(color: scheme.outlineVariant),
                ),
              ),
            fields[i],
          ],
          ?footer,
        ],
      ),
    );
  }
}

/// Nhãn chữ HOA của một nhóm ô ("BẠN", "CÔNG TY", "BẢO MẬT"): 12/700 xám.
class AuthGroupLabel extends StatelessWidget {
  const AuthGroupLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
    child: Semantics(
      header: true,
      child: Text(
        text.toUpperCase(),
        style: OmniType.micro.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.72,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ),
  );
}

/// Một dòng của [AuthFieldGroup]: icon trái, ô chữ không viền, nút phụ bên
/// phải (mắt hiện mật khẩu). Nhãn không hiện trên màn mà đọc cho trình đọc
/// màn hình ([label]); chữ gợi ý là [hint]. Lỗi: icon đỏ, chữ lỗi đỏ ngay dưới
/// dòng (vẫn trong nhóm) và dòng rung 400ms. Đang gõ thì dòng sáng nhẹ.
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
    this.focusNode,
    this.autofocus = false,
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
  final FocusNode? focusNode;
  final bool autofocus;

  /// Chiều cao một dòng.
  static const double rowHeight = 56;

  @override
  State<AuthGroupField> createState() => _AuthGroupFieldState();
}

class _AuthGroupFieldState extends State<AuthGroupField> {
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(AuthGroupField oldWidget) {
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
    final text = OmniType.input.copyWith(color: scheme.onSurface);

    return FormField<String>(
      validator: (_) => widget.validator(widget.controller.text),
      builder: (field) {
        final error = field.errorText ?? widget.serverError;
        final danger = OmniColors.dangerTextOf(context);

        final row = SizedBox(
          height: AuthGroupField.rowHeight,
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(
                widget.icon,
                size: OmniIconSize.lg,
                color: error != null ? danger : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
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
                    style: text,
                    cursorColor: scheme.primary,
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      hintStyle: text.copyWith(color: scheme.onSurfaceVariant),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      filled: false,
                      isCollapsed: true,
                      // Lề đã nằm ở hàng bọc ngoài, chữ không thụt thêm.
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
              widget.suffix ?? const SizedBox(width: 14),
            ],
          ),
        );

        return AnimatedContainer(
          duration: OmniMotion.of(context).fast,
          // Đang gõ: dòng sáng nhẹ (như `:focus-within` của bản duyệt).
          color: _focus.hasFocus
              ? scheme.onSurface.withValues(alpha: 0.04)
              : Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedBuilder(
                animation: widget.shake,
                builder: (_, child) {
                  final t = widget.shake.value;
                  final dx = error == null
                      ? 0.0
                      : math.sin(t * math.pi * 6) * 6 * (1 - t);
                  return Transform.translate(
                    offset: Offset(dx, 0),
                    child: child,
                  );
                },
                child: row,
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AuthFieldGroup.indent,
                    0,
                    14,
                    12,
                  ),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      error,
                      style: OmniType.caption.copyWith(color: danger),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
