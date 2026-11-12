import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../platform/omni_performance.dart';

/// Nút + tròn kính lỏng nổi ở góc dưới phải (viec-quick-create-uiux.html,
/// duyệt 2026-11-08).
///
/// Gần trong suốt: nhoè nhẹ + tăng bão hoà nội dung phía sau, vệt sáng cong ở
/// nửa trên, ánh màu chính "khúc xạ" ở đáy, viền sáng mảnh. Bấm thì nhún như
/// giọt nước; [open] xoay dấu + thành ✕. Tương phản cao: nền đặc viền màu
/// chính. Giảm chuyển động: không nhún, không xoay động.
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

    final glass = Stack(
      fit: StackFit.expand,
      children: [
        // Thân kính: sáng ở góc trên-trái, gần trong suốt ở dưới.
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: solid ? scheme.surface : null,
            gradient: solid
                ? null
                : RadialGradient(
                    center: const Alignment(-0.4, -0.7),
                    radius: 1.1,
                    stops: const [0, 0.55, 1],
                    colors: dark
                        ? [
                            Colors.white.withValues(alpha: 0.22),
                            Colors.white.withValues(alpha: 0.05),
                            Colors.white.withValues(alpha: 0.02),
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.6),
                            Colors.white.withValues(alpha: 0.14),
                            Colors.white.withValues(alpha: 0.06),
                          ],
                  ),
          ),
        ),
        if (!solid) ...[
          // Vệt sáng cong nửa trên.
          Positioned(
            top: 3,
            left: 9,
            right: 9,
            height: size * 0.42,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.elliptical(40, 26),
                  bottom: Radius.elliptical(40, 10),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: dark ? 0.32 : 0.75),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          // Ánh "khúc xạ" màu chính ở đáy.
          Positioned(
            left: 10,
            right: 10,
            bottom: 3,
            height: size * 0.3,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size),
                gradient: RadialGradient(
                  center: Alignment.bottomCenter,
                  radius: 0.9,
                  colors: [
                    scheme.primary.withValues(alpha: dark ? 0.35 : 0.22),
                    scheme.primary.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ],
        // Viền mảnh: sáng (kính) hoặc màu chính (tương phản cao).
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: solid
                  ? scheme.primary
                  : Colors.white.withValues(alpha: dark ? 0.16 : 0.7),
              width: solid ? 1.5 : 1,
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
            child: Icon(widget.icon, size: 28, color: scheme.primary),
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
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.42 : 0.14),
              // Bóng gọn (18/6, trước 24/10): bóng dài loang xuống thanh tab
              // làm nút trông như dính vào menu.
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipOval(
          // Viên 54 σ8: chỉ làm mờ ở bậc hiệu năng đầy đủ.
          child: solid || OmniPerformance.tierOf(context) != OmniPerfTier.full
              ? glass
              : BackdropFilter(
                  filter: ImageFilter.compose(
                    outer: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    inner: const ColorFilter.matrix(_saturate220),
                  ),
                  child: glass,
                ),
        ),
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

/// Bão hoà 2.2× (như `saturate(220%)` của kính CSS trong thiết kế).
const List<double> _saturate220 = <double>[
  1.9448, -0.8582, -0.0870, 0, 0, //
  -0.2552, 1.3418, -0.0870, 0, 0, //
  -0.2552, -0.8582, 2.1130, 0, 0, //
  0, 0, 0, 1, 0,
];
