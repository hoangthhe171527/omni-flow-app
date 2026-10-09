import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../design/tokens/tokens.dart';

/// Ô nhập một dòng: cao 50, bo 10, viền thường / viền `primary` + vầng 3px khi
/// focus / viền đỏ + rung + chữ lỗi dưới ô.
class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
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
    this.autofillHints,
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
  final Iterable<String>? autofillHints;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
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
                      child: Semantics(
                        label: widget.hint,
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
