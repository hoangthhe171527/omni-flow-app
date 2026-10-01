import 'dart:async';

import 'package:flutter/material.dart';

import '../platform/omni_motion_scope.dart';
import '../platform/omni_platform.dart';
import '../tokens/tokens.dart';

/// Debounced search field. Debouncing lives here rather than in each screen so
/// no list ever fires a request per keystroke.
class OmniSearchField extends StatefulWidget {
  const OmniSearchField({
    super.key,
    required this.onChanged,
    this.hint = 'Tìm kiếm...',
    this.initialValue,
    this.debounce = const Duration(milliseconds: 350),
    this.trailing,
    this.outlined = false,
  });

  final ValueChanged<String> onChanged;

  /// Bộ Orbit có hai kiểu ô tìm: khối xám không viền (mặc định — hộp thư,
  /// khách hàng, gán người) và ô trắng viền mảnh đặt trên nền xám (danh bạ
  /// "Tất cả").
  final bool outlined;
  final String hint;
  final String? initialValue;
  final Duration debounce;
  final Widget? trailing;

  @override
  State<OmniSearchField> createState() => _OmniSearchFieldState();
}

class _OmniSearchFieldState extends State<OmniSearchField> {
  OutlineInputBorder _border(ColorScheme scheme) => widget.outlined
      ? OutlineInputBorder(
          borderRadius: OmniRadius.lgAll,
          borderSide: BorderSide(color: scheme.outlineVariant),
        )
      : const OutlineInputBorder(
          borderRadius: OmniRadius.mdAll,
          borderSide: BorderSide.none,
        );

  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _timer?.cancel();
    _timer = Timer(widget.debounce, () => widget.onChanged(value.trim()));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return TextField(
      controller: _controller,
      onChanged: _onChanged,
      textInputAction: TextInputAction.search,
      style: OmniType.body.copyWith(color: scheme.onSurface),
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: Icon(
          Icons.search_rounded,
          color: scheme.onSurfaceVariant,
          size: OmniIconSize.lg,
        ),
        suffixIcon: _controller.text.isEmpty
            ? widget.trailing
            : IconButton(
                tooltip: 'Xoá nội dung tìm',
                icon: Icon(
                  Icons.close_rounded,
                  size: OmniIconSize.md,
                  color: scheme.onSurfaceVariant,
                ),
                onPressed: () {
                  _controller.clear();
                  _onChanged('');
                },
              ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        filled: true,
        fillColor: widget.outlined
            ? scheme.surface
            : scheme.surfaceContainerHighest,
        border: _border(scheme),
        enabledBorder: _border(scheme),
        focusedBorder: widget.outlined
            ? OutlineInputBorder(
                borderRadius: OmniRadius.lgAll,
                borderSide: BorderSide(color: scheme.primary, width: 1.5),
              )
            : _border(scheme),
      ),
    );
  }
}

/// Labelled form field wrapper — one place for the label, hint, error and
/// required marker so no two forms disagree.
class OmniField extends StatelessWidget {
  const OmniField({
    super.key,
    required this.label,
    required this.child,
    this.required = false,
    this.error,
    this.hint,
  });

  final String label;
  final Widget child;
  final bool required;
  final String? error;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              // 14/600 màu chữ chính — nhãn của mọi biểu mẫu trong bộ Orbit.
              style: OmniType.body.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (required)
              Text(' *', style: OmniType.caption.copyWith(color: scheme.error)),
          ],
        ),
        const SizedBox(height: OmniSpacing.sm),
        OmniFocusGlow(child: child),
        if (error != null) ...[
          const SizedBox(height: 5),
          Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: OmniIconSize.xs,
                color: scheme.error,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  error!,
                  style: OmniType.micro.copyWith(color: scheme.error),
                ),
              ),
            ],
          ),
        ] else if (hint != null) ...[
          const SizedBox(height: 5),
          Text(
            hint!,
            style: OmniType.micro.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

/// Sticky bottom action bar for forms and detail screens.
class OmniActionBar extends StatelessWidget {
  const OmniActionBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.fromLTRB(
        OmniSpacing.lg,
        OmniSpacing.md,
        OmniSpacing.lg,
        OmniSpacing.md + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      // Bộ Orbit: nút phụ ôm lấy chữ của nó ("Huỷ", "Đánh dấu thắng"), nút
      // chính cuối hàng chiếm phần còn lại. Chia đều bề ngang làm chữ nút phụ
      // gãy thành ba dòng trên màn 390dp.
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            if (i == children.length - 1)
              Expanded(child: children[i])
            else
              OutlinedButtonTheme(
                data: OutlinedButtonThemeData(
                  style: Theme.of(context).outlinedButtonTheme.style?.copyWith(
                    minimumSize: const WidgetStatePropertyAll(Size(0, 52)),
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 18),
                    ),
                  ),
                ),
                child: children[i],
              ),
          ],
        ],
      ),
    );
  }
}

/// Consistent modal sheet — used for assign, labels, filters, stage change.
///
/// Nơi DUY NHẤT trong app gọi `showModalBottomSheet`. Module gọi hàm này và
/// nhận hình thức đúng nền tảng mà không phải biết nền tảng là gì.
Future<T?> showOmniSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext context) builder,
  bool expand = false,
}) {
  final apple = isApple(context);

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // iOS bo góc rõ hơn Material và luôn có thanh kéo — đó là dấu hiệu người
    // dùng iPhone đọc để biết sheet này kéo xuống đóng được. Trên Android thì
    // nút back của hệ thống đã nói điều đó rồi.
    showDragHandle: apple,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(apple ? 14 : OmniRadius.xxl),
      ),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: expand
          ? FractionallySizedBox(heightFactor: 0.9, child: builder(context))
          : builder(context),
    ),
  );
}

/// Vầng sáng 4dp quanh ô nhập đang focus (`MLogin.dc.html`: viền màu chính
/// 1.5 và `box-shadow: 0 0 0 4px #E3F8F6`).
///
/// InputDecoration không vẽ được bóng, nên vầng sáng nằm ở widget bọc ngoài và
/// nghe focus của cả cây con — không cần FocusNode riêng cho từng ô. Chỉ thêm
/// một lớp nhận diện "đang gõ ở đây", không thay viền: viền focus vẫn do theme
/// vẽ, nên ô nào không bọc cũng không mất gì.
class OmniFocusGlow extends StatefulWidget {
  const OmniFocusGlow({
    super.key,
    required this.child,
    this.borderRadius = OmniRadius.mdAll,
  });

  final Widget child;
  final BorderRadius borderRadius;

  @override
  State<OmniFocusGlow> createState() => _OmniFocusGlowState();
}

class _OmniFocusGlowState extends State<OmniFocusGlow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final glow = dark
        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.18)
        : OmniColors.accentSoft;

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: AnimatedContainer(
        duration: OmniMotion.of(context).fast,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          boxShadow: _focused
              ? [BoxShadow(color: glow, spreadRadius: 4)]
              : const [],
        ),
        child: widget.child,
      ),
    );
  }
}
