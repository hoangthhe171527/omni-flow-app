import 'package:flutter/material.dart';

/// Nút + tròn nổi ở góc dưới phải, phía trên thanh tab.
///
/// Phong cách iOS 25/11/2026 (spec §3.3): tròn đặc màu chính, dấu + màu
/// onPrimary, bóng mảnh cùng tông màu chính — không vệt sáng, không nhoè nền
/// phía sau. Bấm thì nhún nhẹ; [open] xoay dấu + thành ✕. Tương phản cao: nền
/// đặc viền màu chính. Giảm chuyển động: không nhún, không xoay động.
class OmniLiquidFab extends StatefulWidget {
  const OmniLiquidFab({
    super.key,
    required this.onPressed,
    required this.tooltip,
    this.open = false,
    this.icon = Icons.add_rounded,
  });

  /// Nhận khung của nút (toạ độ màn) để neo menu bật ra từ chính nút.
  final ValueChanged<Rect> onPressed;
  final String tooltip;
  final bool open;
  final IconData icon;

  static const double size = 58;

  @override
  State<OmniLiquidFab> createState() => _OmniLiquidFabState();
}

class _OmniLiquidFabState extends State<OmniLiquidFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _squish = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  // Nhún: bẹt ngang → cao lên → lắng về tròn.
  static final _sx = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1, end: 1.14), weight: 25),
    TweenSequenceItem(tween: Tween(begin: 1.14, end: 0.94), weight: 25),
    TweenSequenceItem(tween: Tween(begin: 0.94, end: 1.03), weight: 25),
    TweenSequenceItem(tween: Tween(begin: 1.03, end: 1), weight: 25),
  ]);
  static final _sy = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1, end: 0.88), weight: 25),
    TweenSequenceItem(tween: Tween(begin: 0.88, end: 1.06), weight: 25),
    TweenSequenceItem(tween: Tween(begin: 1.06, end: 0.98), weight: 25),
    TweenSequenceItem(tween: Tween(begin: 0.98, end: 1), weight: 25),
  ]);

  @override
  void dispose() {
    _squish.dispose();
    super.dispose();
  }

  void _tap() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    if (!MediaQuery.disableAnimationsOf(context)) _squish.forward(from: 0);
    widget.onPressed(box.localToGlobal(Offset.zero) & box.size);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final solid = MediaQuery.highContrastOf(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    const size = OmniLiquidFab.size;

    final face = Stack(
      fit: StackFit.expand,
      children: [
        // Nền đặc màu chính: icon + luôn rõ trên mọi danh sách có ảnh/chữ.
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: solid ? scheme.surface : scheme.primary,
          ),
        ),
        if (solid)
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: scheme.primary, width: 1.5),
            ),
          ),
        Center(
          child: AnimatedRotation(
            key: const Key('liquid-fab-icon'),
            turns: widget.open ? 0.375 : 0,
            duration: reduce
                ? Duration.zero
                : const Duration(milliseconds: 420),
            curve: Curves.easeOutBack,
            child: Icon(
              widget.icon,
              size: 28,
              color: solid ? scheme.primary : scheme.onPrimary,
            ),
          ),
        ),
      ],
    );

    final body = SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            // Bóng mảnh cùng tông màu chính + một lớp mực rất nhẹ để tách nền.
            // Gọn (16/6): bóng dài loang xuống thanh tab làm nút như dính menu.
            BoxShadow(
              color: scheme.primary.withValues(alpha: dark ? 0.30 : 0.30),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.30 : 0.10),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: ClipOval(child: face),
      ),
    );

    return Semantics(
      button: true,
      expanded: widget.open,
      label: widget.tooltip,
      excludeSemantics: true,
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _tap,
          child: AnimatedBuilder(
            animation: _squish,
            builder: (context, child) => Transform.scale(
              scaleX: _sx.transform(_squish.value),
              scaleY: _sy.transform(_squish.value),
              child: child,
            ),
            child: body,
          ),
        ),
      ),
    );
  }
}
