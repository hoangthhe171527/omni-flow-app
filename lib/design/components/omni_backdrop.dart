import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

/// Nền cả app phía sau một màn "không gian" (chat, bảng dự án).
///
/// `name == null` hoặc tên lạ → trả thẳng [child]: màn giữ nền phẳng như
/// khi chưa có tính năng này. Có tên → gradient theo chế độ sáng/tối của
/// theme hiện tại, phủ hoạ tiết mờ ([OmniBackdrops.patternAlpha]) bằng màu
/// chữ của chế độ. Không chuyển động — nền là nền.
class OmniBackdrop extends StatelessWidget {
  const OmniBackdrop({super.key, required this.name, required this.child});

  final String? name;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spec = OmniBackdrops.specOf(name, theme.brightness);
    if (spec == null) return child;

    final inner = spec.pattern == OmniBackdropPattern.none
        ? child
        : CustomPaint(
            painter: _PatternPainter(
              spec.pattern,
              theme.colorScheme.onSurface.withValues(
                alpha: OmniBackdrops.patternAlpha,
              ),
            ),
            child: child,
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [spec.top, spec.bottom],
        ),
      ),
      child: inner,
    );
  }
}

class _PatternPainter extends CustomPainter {
  const _PatternPainter(this.pattern, this.color);

  final OmniBackdropPattern pattern;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    switch (pattern) {
      case OmniBackdropPattern.none:
        return;
      case OmniBackdropPattern.dots:
        final dot = Paint()..color = color;
        for (var y = 12.0; y < size.height; y += 24) {
          for (var x = 12.0; x < size.width; x += 24) {
            canvas.drawCircle(Offset(x, y), 1, dot);
          }
        }
      case OmniBackdropPattern.diagonal:
        // Vạch 45°, cách nhau 28dp, phủ cả góc trên-phải và dưới-trái.
        final span = size.width + size.height;
        for (var d = 0.0; d < span; d += 28) {
          canvas.drawLine(Offset(d, 0), Offset(0, d), stroke);
        }
      case OmniBackdropPattern.grain:
        // Vân gỗ: đường ngang hơi lượn, cách 18dp.
        for (var y = 9.0; y < size.height; y += 18) {
          final path = Path()..moveTo(0, y);
          for (var x = 0.0; x < size.width; x += 64) {
            path.quadraticBezierTo(x + 16, y - 3, x + 32, y);
            path.quadraticBezierTo(x + 48, y + 3, x + 64, y);
          }
          canvas.drawPath(path, stroke);
        }
    }
  }

  @override
  bool shouldRepaint(_PatternPainter old) =>
      old.pattern != pattern || old.color != color;
}
