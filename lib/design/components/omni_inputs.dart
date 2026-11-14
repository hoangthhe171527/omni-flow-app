import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../platform/omni_motion_scope.dart';
import '../platform/omni_performance.dart';
import '../platform/omni_platform.dart';
import '../tokens/tokens.dart';
import 'omni_tinted_buttons.dart';
import 'omni_glass.dart';

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
    this.flat = false,
    this.dense = false,
    this.autofocus = false,
    this.onSubmitted,
  });

  final ValueChanged<String> onChanged;

  /// Kiểu có đường biên dùng trong biểu mẫu khi ranh giới nhập liệu phải rõ.
  /// Thanh tìm của màn danh sách dùng [flat] thay vì kiểu này.
  final bool outlined;

  /// Ô tìm nằm ngay trên cùng một mặt phẳng với nội dung: không nền, không
  /// viền. Chỉ dùng cho thanh tìm của màn danh sách; ô nhập trong form vẫn cần
  /// khung để nhận biết ranh giới dữ liệu.
  final bool flat;

  /// Gọn mắt nhưng vẫn cao 44 (vùng chạm): đệm dọc nhỏ, icon 36.
  final bool dense;
  final String hint;
  final String? initialValue;
  final Duration debounce;
  final Widget? trailing;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

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

    // Center: nơi gọi hay ép ô cao đúng 44 (hàng `stretch`, viên kính). Bị ép
    // thì ô nhập dồn nội dung lên mép trên — với phông thật (dòng cao hơn
    // phông thử) kính lúp và chữ lệch lên ~3px trong viên kính. Center để ô
    // giữ chiều cao tự nhiên và nằm đúng giữa khung.
    return Center(
      child: TextField(
        controller: _controller,
        autofocus: widget.autofocus,
        onChanged: _onChanged,
        onSubmitted: widget.onSubmitted == null
            ? null
            : (value) {
                _timer?.cancel();
                widget.onSubmitted!(value.trim());
              },
        textInputAction: TextInputAction.search,
        style: OmniType.search.copyWith(
          color: scheme.onSurface,
          fontStyle: FontStyle.normal,
        ),
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: OmniType.searchHint.copyWith(
            color: scheme.onSurfaceVariant,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: scheme.onSurfaceVariant,
            size: OmniIconSize.lg,
          ),
          prefixIconConstraints: widget.dense
              ? const BoxConstraints(minWidth: 36, minHeight: 36)
              : null,
          suffixIconConstraints: widget.dense
              ? const BoxConstraints(minWidth: 36, minHeight: 36)
              : null,
          suffixIcon: _controller.text.isEmpty
              ? widget.trailing
              : IconButton(
                  padding: widget.dense ? EdgeInsets.zero : null,
                  constraints: widget.dense
                      ? const BoxConstraints(minWidth: 36, minHeight: 36)
                      : null,
                  tooltip: 'Xoá nội dung tìm',
                  icon: Icon(
                    Icons.close_rounded,
                    size: OmniIconSize.md,
                    color: scheme.onSurfaceVariant,
                  ),
                  onPressed: () {
                    _timer?.cancel();
                    _controller.clear();
                    widget.onChanged('');
                    setState(() {});
                  },
                ),
          isDense: true,
          // Đệm 12 cho cả bản dense: 12 + dòng 20 + 12 = đúng 44, khớp viên kính
          // / hàng ép vào. Đệm 10 thì nội dung chỉ cao 40, nằm sát mép trên khung
          // 44 → kính lúp và chữ lệch lên 2px (thấy rõ trên viên kính).
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          filled: !widget.flat,
          fillColor: widget.flat
              ? Colors.transparent
              : widget.outlined
              ? scheme.surface
              : scheme.surfaceContainerHighest,
          border: widget.flat ? InputBorder.none : _border(scheme),
          enabledBorder: widget.flat ? InputBorder.none : _border(scheme),
          focusedBorder: !widget.flat && widget.outlined
              ? OutlineInputBorder(
                  borderRadius: OmniRadius.lgAll,
                  borderSide: BorderSide(
                    color: scheme.primary.withValues(alpha: .55),
                    width: 1.5,
                  ),
                )
              : widget.flat
              ? InputBorder.none
              : _border(scheme),
        ),
      ),
    );
  }
}

/// Thanh tìm kiếm viên kính cao 44 dùng thống nhất làm `bottom` của [OmniAppBar].
class OmniSearchBottom extends StatelessWidget implements PreferredSizeWidget {
  const OmniSearchBottom({
    super.key,
    required this.hint,
    required this.onChanged,
    this.fieldKey,
    this.initialValue,
    this.debounce = const Duration(milliseconds: 350),
    this.autofocus = false,
    this.onSubmitted,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final Key? fieldKey;
  final String? initialValue;
  final Duration debounce;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  @override
  Size get preferredSize => const Size.fromHeight(44);

  @override
  Widget build(BuildContext context) => OmniGlass(
    radius: 22,
    child: SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: OmniSearchField(
          key: fieldKey,
          hint: hint,
          initialValue: initialValue,
          debounce: debounce,
          flat: true,
          dense: true,
          autofocus: autofocus,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
        ),
      ),
    ),
  );
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
            // Nhãn dài (sheet trong viên kính hẹp hơn 16) xuống dòng, không tràn.
            Flexible(
              child: Text(
                label,
                // 14/600 màu chữ chính — nhãn của mọi biểu mẫu trong bộ Orbit.
                style: OmniType.body.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
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

/// Thanh hành động đáy của form và màn chi tiết — viên kính nổi
/// (viomni-apple-uiux.html `.actbar.glass`): cách mép 12, bo 30, đệm 7.
///
/// Nút trong thanh là nút VIỀN (gu người dùng: không nút tô đặc): nút chính
/// (FilledButton) viền + chữ màu chủ đạo, nút phụ (OutlinedButton) viền nhạt
/// chữ phụ; cao 46, dạng viên thuốc. Nút phụ ôm chữ của nó, nút chính cuối
/// hàng chiếm phần còn lại — chia đều làm chữ nút phụ gãy dòng ở màn 390dp.
class OmniActionBar extends StatelessWidget {
  const OmniActionBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const height = 46.0;
    final label = OmniType.body.copyWith(fontWeight: FontWeight.w600);

    Color tone(Set<WidgetState> s, Color on) => s.contains(WidgetState.disabled)
        ? scheme.onSurface.withValues(alpha: .38)
        : on;

    final primary = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, height)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 18),
      ),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
      elevation: const WidgetStatePropertyAll(0),
      textStyle: WidgetStatePropertyAll(label),
      backgroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled)
            ? scheme.onSurface.withValues(alpha: .10)
            : scheme.primary,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (s) => tone(s, scheme.onPrimary),
      ),
      overlayColor: WidgetStatePropertyAll(
        scheme.onPrimary.withValues(alpha: .12),
      ),
    );
    final secondary = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, height)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 18),
      ),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
      elevation: const WidgetStatePropertyAll(0),
      textStyle: WidgetStatePropertyAll(label),
      backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
      foregroundColor: WidgetStateProperty.resolveWith(
        (s) => tone(s, scheme.onSurfaceVariant),
      ),
      overlayColor: WidgetStatePropertyAll(
        scheme.onSurface.withValues(alpha: .06),
      ),
      side: WidgetStatePropertyAll(
        BorderSide(width: 1, color: scheme.outlineVariant),
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        14 + MediaQuery.paddingOf(context).bottom,
      ),
      child: OmniGlass(
        radius: 30,
        padding: const EdgeInsets.all(7),
        child: FilledButtonTheme(
          data: FilledButtonThemeData(style: primary),
          child: OutlinedButtonTheme(
            data: OutlinedButtonThemeData(style: secondary),
            child: Row(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  if (i == children.length - 1)
                    Expanded(child: children[i])
                  else
                    children[i],
                ],
              ],
            ),
          ),
        ),
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
  Color? backgroundColor,
  Color? barrierColor,
  double? maxHeight,
  double? radius,
  bool? showDragHandle,
  AnimationStyle? animationStyle,
  // Mặc định mở ở navigator gốc: màn trong tab nằm ở navigator lồng, còn
  // thanh tab kính vẽ bên ngoài nó — sheet mở trong tab bị thanh tab đè lên
  // đáy. Chỉ truyền `false` khi sheet thật sự phải nằm dưới thanh tab.
  bool useRootNavigator = true,
}) {
  final apple = isApple(context);
  final fill = backgroundColor ?? Theme.of(context).colorScheme.surface;

  // Viên kính nổi (viomni-apple-uiux.html `.sheet.glass`): cách mép 8, bo 30,
  // nền thẻ ~86% + nhoè. Tấm Material của sheet để trong suốt; viên kính
  // [OmniGlassSheet] vẽ nền, bo và thanh kéo.
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: barrierColor,
    constraints: maxHeight == null
        ? null
        : BoxConstraints(maxHeight: maxHeight),
    // Giảm chuyển động: sheet hiện ngay, không trượt lên.
    sheetAnimationStyle: OmniMotion.enabled(context)
        ? animationStyle
        : AnimationStyle.noAnimation,
    showDragHandle: false,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: OmniGlassSheet(
        fill: fill,
        radius: radius ?? 30,
        // iOS luôn có thanh kéo — dấu hiệu người dùng iPhone đọc để biết sheet
        // kéo xuống đóng được. Trên Android nút back đã nói điều đó.
        handle: showDragHandle ?? apple,
        expand: expand,
        child: builder(context),
      ),
    ),
  );
}

/// Viên kính chứa nội dung của [showOmniSheet].
class OmniGlassSheet extends StatelessWidget {
  const OmniGlassSheet({
    super.key,
    required this.fill,
    required this.child,
    this.radius = 30,
    this.handle = false,
    this.expand = false,
  });

  final Color fill;
  final double radius;
  final bool handle;
  final bool expand;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final solid = MediaQuery.highContrastOf(context);
    // Bậc hiệu năng tối giản: không nhoè, nền gần đặc.
    final noBlur = OmniPerformance.solidGlass(context);
    final shape = BorderRadius.circular(radius);
    final body = Material(
      key: const Key('omni-glass-sheet'),
      color: solid
          ? fill
          : fill.withValues(alpha: noBlur ? .98 : (dark ? .92 : .95)),
      shape: RoundedRectangleBorder(
        borderRadius: shape,
        side: BorderSide(
          color: Colors.white.withValues(alpha: dark ? .10 : .70),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (handle)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: OmniSheetHandle(gap: 2),
            )
          else
            // Không thanh kéo (Android/web): chừa mép trên để tiêu đề không
            // nằm trong đường cong bo 30 của viên kính.
            const SizedBox(height: 12),
          // Sheet gần trắng: nút bên trong là kính nhuộm tông, không chìm.
          Flexible(
            fit: expand ? FlexFit.tight : FlexFit.loose,
            child: OmniTintedButtons(child: child),
          ),
        ],
      ),
    );

    final sheet = Padding(
      padding: EdgeInsets.fromLTRB(
        8,
        0,
        8,
        8 + MediaQuery.paddingOf(context).bottom,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: shape,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? .40 : .14),
              blurRadius: 36,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: solid || noBlur
            ? body
            : ClipRRect(
                borderRadius: shape,
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: OmniPerformance.glassSigma(context, full: 24),
                    sigmaY: OmniPerformance.glassSigma(context, full: 24),
                  ),
                  child: body,
                ),
              ),
      ),
    );

    return expand
        ? FractionallySizedBox(heightFactor: 0.9, child: sheet)
        : sheet;
  }
}

/// Sheet chia nhóm của màn Việc (`Board.dc.html` menu kế hoạch,
/// `TaskDetail.dc.html` nhãn): bo trên 12, lớp phủ mực .4, trượt 380ms
/// [OmniCurves.sheet], cao tối đa 740, thanh kéo vẽ trong nội dung
/// ([OmniSheetHandle]).
Future<T?> showOmniViecSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext context) builder,
  Color? backgroundColor,
}) => showOmniSheet<T>(
  context: context,
  builder: builder,
  backgroundColor: backgroundColor,
  barrierColor: OmniColors.ink.withValues(alpha: 0.28),
  maxHeight: 740,
  showDragHandle: false,
  animationStyle: const AnimationStyle(
    duration: OmniDuration.sheet,
    curve: OmniCurves.sheet,
    reverseDuration: OmniDuration.base,
  ),
);

/// Thanh kéo 36×4 của [showOmniViecSheet] (`#C9D2DE`), cách nội dung [gap].
class OmniSheetHandle extends StatelessWidget {
  const OmniSheetHandle({super.key, this.gap = 10});

  final double gap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: gap),
    child: Center(
      child: Container(
        key: const Key('sheet-handle'),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: OmniColors.controlBorderOf(context),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
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
