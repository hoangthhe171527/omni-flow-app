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
        // Nút tạo mới nổi: nền đặc màu chính để icon + luôn rõ nét trên
        // mọi danh sách có ảnh/chữ; giữ ánh sáng nhẹ nửa trên cho đồng bộ.
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: solid ? scheme.surface : scheme.primary,
          ),
        ),
        if (!solid)
          Positioned(
            top: 2,
            left: 8,
            right: 8,
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
                    Colors.white.withValues(alpha: dark ? 0.16 : 0.22),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
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
