import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Vòng tiến độ nhỏ: cung [color] chạy từ đỉnh theo [percent], số % ở giữa.
class OmniProgressRing extends StatelessWidget {
  const OmniProgressRing({
    super.key,
    required this.percent,
    required this.color,
    this.size = 36,
  });

  final int percent;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shown = percent.clamp(0, 100);
    return Semantics(
      label: 'Tiến độ $shown%',
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(
            track: scheme.outlineVariant,
            arc: color,
            fraction: shown / 100,
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$shown%',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.track,
    required this.arc,
    required this.fraction,
  });

  final Color track;
  final Color arc;
  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 3.0;
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(r, 0, math.pi * 2, false, paint);
    if (fraction > 0) {
      paint
        ..color = arc
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(r, -math.pi / 2, math.pi * 2 * fraction, false, paint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter o) =>
      o.track != track || o.arc != arc || o.fraction != fraction;
}
