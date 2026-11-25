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

/// Vòng tỉ lệ nhiều phần, không chữ (Chuẩn Mobile UI — TotalCard, lớp
/// premium): đặt cạnh số chính của khối tổng. Mỗi phần một màu — dùng ĐÚNG
/// màu nền-chữ của nhãn trạng thái tương ứng để khỏi cần chú thích.
/// [semanticsLabel] đọc đủ số ("Thu một phần 389.500.000đ, chưa thu …").
class OmniSplitRing extends StatelessWidget {
  const OmniSplitRing({
    super.key,
    required this.parts,
    required this.semanticsLabel,
    this.size = 44,
    this.stroke = 6,
  });

  /// (giá trị, màu) theo thứ tự vẽ từ đỉnh, chiều kim đồng hồ.
  final List<(double, Color)> parts;
  final String semanticsLabel;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    final track = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _SplitPainter(parts: parts, track: track, stroke: stroke),
        ),
      ),
    );
  }
}

class _SplitPainter extends CustomPainter {
  _SplitPainter({
    required this.parts,
    required this.track,
    required this.stroke,
  });

  final List<(double, Color)> parts;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(arcRect, 0, 6.283185307179586, false, base);
    final total = parts.fold<double>(0, (s, p) => s + (p.$1 > 0 ? p.$1 : 0));
    if (total <= 0) return;
    var start = -1.5707963267948966;
    const gap = 0.06;
    final n = parts.where((p) => p.$1 > 0).length;
    for (final (v, c) in parts) {
      if (v <= 0) continue;
      final sweep = v / total * 6.283185307179586;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt
        ..color = c;
      canvas.drawArc(
        arcRect,
        start + (n > 1 ? gap / 2 : 0),
        sweep - (n > 1 ? gap : 0),
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_SplitPainter old) =>
      old.parts != parts || old.track != track || old.stroke != stroke;
}
