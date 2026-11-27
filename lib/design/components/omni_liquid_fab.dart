import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons_500.dart';

/// Nút + tròn nổi ở góc dưới phải, phía trên thanh tab.
///
/// Hướng "iOS chuẩn" (duyệt 26/11/2026): tròn 52 đặc màu chính, dấu + nét đậm
/// màu onPrimary, bóng XÁM mảnh — bóng xanh loang rộng cũ làm nút nặng và
/// chói. Mọi màn dùng chung dấu +. Bấm thì nhún nhẹ; [open] xoay dấu + thành
/// ✕. Tương phản cao: nền đặc viền màu chính. Giảm chuyển động: không nhún,
/// không xoay động.
class OmniLiquidFab extends StatefulWidget {
  const OmniLiquidFab({
    super.key,
    required this.onPressed,
    required this.tooltip,
    this.open = false,
    this.icon = LucideIcons500.plus,
  });

  /// Nhận khung của nút (toạ độ màn) để neo menu bật ra từ chính nút.
  final ValueChanged<Rect> onPressed;
  final String tooltip;
  final bool open;
  final IconData icon;

  static const double size = 52;

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

    // Cobalt -> Indigo 3D + viền sáng specular rim (trên-trái) + bóng chiều
    // sâu: nổi rõ trên nền đen #000 nhưng vẫn mượt, không bị phẳng kiểu
    // Material cũ. Tương phản cao: nền đặc viền màu chính.
    final coreDecoration = solid
        ? BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.surface,
            border: Border.all(color: scheme.primary, width: 1.5),
          )
        : const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4B8BFF), Color(0xFF2563EB), Color(0xFF1D4ED8)],
              stops: [0.0, 0.52, 1.0],
            ),
          );

    final innerFace = Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(decoration: coreDecoration),
        if (!solid)
          // Vệt sáng specular nhẹ ở đỉnh nút tạo khối kính lồi 3D.
          Align(
            alignment: Alignment.topCenter,
            child: IgnorePointer(
              child: Container(
                margin: const EdgeInsets.only(top: 2, left: 8, right: 8),
                height: 14,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.30),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
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
              size: 24,
              color: solid ? scheme.primary : Colors.white,
            ),
          ),
        ),
      ],
    );

    final face = solid
        ? ClipOval(child: innerFace)
        : DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.55),
                  const Color(0xFF93C5FD).withValues(alpha: 0.22),
                  const Color(0xFF1E3A8A).withValues(alpha: 0.40),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(1.5),
              child: ClipOval(child: innerFace),
            ),
          );

    final body = SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(
                0xFF2563EB,
              ).withValues(alpha: dark ? 0.48 : 0.28),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: (dark ? Colors.black : const Color(0xFF0B1A33)).withValues(
                alpha: dark ? 0.55 : 0.14,
              ),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: face,
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
