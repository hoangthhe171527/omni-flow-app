import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Vòng tròn nét đứt có dấu + ở giữa: chỗ "chưa có ai" — chạm vào để giao.
///
/// Cùng cỡ với avatar nhỏ (mặc định 22) nên dòng không nhảy khi có người nhận.
/// Màu lấy từ `colorScheme.outline` để chế độ tối tự đúng.
class OmniDashedCircle extends StatelessWidget {
  const OmniDashedCircle({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outline;

    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _DashedCirclePainter(color),
        child: Center(
          child: Icon(Icons.add_rounded, size: size * 0.55, color: color),
        ),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  _DashedCirclePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rect = (Offset.zero & size).deflate(0.75);
    const dashes = 12;
    const sweep = 2 * math.pi / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect, i * sweep, sweep * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter old) => old.color != color;
}
