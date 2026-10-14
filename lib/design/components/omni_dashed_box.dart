import 'package:flutter/material.dart';

/// Ô viền đứt bo góc: chỗ trống chờ một thẻ được thả vào.
///
/// Nét [strokeWidth] vẽ TRONG khung (không tràn ra ngoài), nền [fill] lấp kín
/// khung bo [radius]. Màu mặc định là `colorScheme.primary`, nền là chính màu
/// đó với alpha .06 — đúng ô chỗ trống của bảng kéo thả.
class OmniDashedBox extends StatelessWidget {
  const OmniDashedBox({
    super.key,
    this.height,
    this.radius = 8,
    this.strokeWidth = 2,
    this.color,
    this.fill,
    this.child,
  });

  final double? height;
  final double radius;
  final double strokeWidth;

  /// Màu nét; null = `colorScheme.primary`.
  final Color? color;

  /// Nền; null = [color] alpha .06.
  final Color? fill;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? Theme.of(context).colorScheme.primary;

    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _DashedBoxPainter(
          color: color,
          fill: fill ?? color.withValues(alpha: .06),
          radius: radius,
          strokeWidth: strokeWidth,
        ),
        child: child,
      ),
    );
  }
}

class _DashedBoxPainter extends CustomPainter {
  _DashedBoxPainter({
    required this.color,
    required this.fill,
    required this.radius,
    required this.strokeWidth,
  });

  final Color color;
  final Color fill;
  final double radius;
  final double strokeWidth;

  static const _dash = 6.0;
  static const _gap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(strokeWidth / 2),
      Radius.circular(radius),
    );
    canvas.drawRRect(rrect, Paint()..color = fill);

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += _dash + _gap) {
        canvas.drawPath(metric.extractPath(d, d + _dash), stroke);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBoxPainter old) =>
      old.color != color ||
      old.fill != fill ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth;
}
