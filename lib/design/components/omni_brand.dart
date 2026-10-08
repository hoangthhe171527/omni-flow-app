import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

/// Logo Viomni: hành tinh‑bong bóng chat trên quỹ đạo, chấm vàng là "tin mới".
///
/// Vẽ bằng [CustomPainter] theo đúng SVG của artifact giao diện
/// (`Main.dc.html`, viewBox 0 0 100 100) chứ không nạp một tệp ảnh: app chưa
/// có `flutter_svg`, và thêm một phụ thuộc chỉ để vẽ năm hình là không đáng.
/// Vẽ bằng tay còn cho phép màn mở app VẼ DẦN từng nét (xem [OmniBrandFrame]).
class OmniBrandMark extends StatelessWidget {
  const OmniBrandMark({
    super.key,
    this.size = 36,
    this.onInk = false,
    this.frame = OmniBrandFrame.complete,
    this.semanticLabel,
  });

  /// Cạnh của ô vuông, dp.
  final double size;

  /// Logo nằm trên một mặt [OmniColors.ink] (màn đăng nhập, màn mở app): ô
  /// logo dùng [OmniColors.inkRaised] để còn tách được khỏi nền.
  final bool onInk;

  /// Từng nét đã vẽ tới đâu. Mặc định là logo hoàn chỉnh.
  final OmniBrandFrame frame;

  /// Null = logo trang trí, bị bỏ qua bởi trình đọc màn hình (như
  /// `aria-hidden` trong thiết kế): cạnh nó luôn có chữ nói cùng một điều.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final mark = CustomPaint(
      size: Size.square(size),
      painter: OmniBrandMarkPainter(
        tile: onInk ? OmniColors.inkRaised : OmniColors.ink,
        // Ở cỡ nhỏ thiết kế làm nét dày hơn một chút để logo không mảnh đi.
        strokeWidth: size <= 40 ? 6 : 5.5,
        dotRadius: size <= 40 ? 7 : 6.5,
        frame: frame,
      ),
    );

    if (semanticLabel == null) return ExcludeSemantics(child: mark);

    return Semantics(label: semanticLabel, image: true, child: mark);
  }
}

/// Chữ "Vi" + "omni" đặt cạnh logo.
class OmniWordmark extends StatelessWidget {
  const OmniWordmark({super.key, this.fontSize = 22, this.onInk = false});

  final double fontSize;

  /// Trên nền mực: "Vi" trắng, "omni" quỹ đạo sáng. Trên nền sáng: "Vi"
  /// mực, "omni" màu chính.
  final bool onInk;

  @override
  Widget build(BuildContext context) {
    final dark = onInk || Theme.of(context).brightness == Brightness.dark;
    final base = OmniType.wordmark.copyWith(
      fontSize: fontSize,
      letterSpacing: -0.02 * fontSize,
      color: dark ? Colors.white : OmniColors.ink,
    );

    return Text.rich(
      TextSpan(
        text: 'Vi',
        children: [
          TextSpan(
            text: 'omni',
            style: TextStyle(
              color: dark ? OmniColors.orbit : OmniColors.primary,
            ),
          ),
        ],
      ),
      style: base,
    );
  }
}

/// Một khung hình của logo khi đang được vẽ ra.
///
/// Bốn nét dùng đúng quy tắc của CSS `stroke-dasharray: 170` trong
/// `Splash.dc.html`: ở tiến độ p, mỗi nét hiện `170 × p` đơn vị chiều dài
/// (tối đa là cả nét). Vì thế nét ngắn (đuôi) xong sớm, vòng tròn xong muộn —
/// giống hệt bản thiết kế, không phải cả bốn cùng về đích.
@immutable
class OmniBrandFrame {
  const OmniBrandFrame({
    this.ring = 1,
    this.tail = 1,
    this.backArc = 1,
    this.frontArc = 1,
    this.dotTurn = 0,
    this.dotScale = 1,
    this.dotOpacity = 1,
  });

  static const complete = OmniBrandFrame();

  final double ring;
  final double tail;
  final double backArc;
  final double frontArc;

  /// Góc (độ) chấm vàng đang lệch khỏi chỗ nghỉ, quay quanh tâm (50, 44).
  final double dotTurn;
  final double dotScale;
  final double dotOpacity;

  @override
  bool operator ==(Object other) =>
      other is OmniBrandFrame &&
      other.ring == ring &&
      other.tail == tail &&
      other.backArc == backArc &&
      other.frontArc == frontArc &&
      other.dotTurn == dotTurn &&
      other.dotScale == dotScale &&
      other.dotOpacity == dotOpacity;

  @override
  int get hashCode =>
      Object.hash(ring, tail, backArc, frontArc, dotTurn, dotScale, dotOpacity);
}

class OmniBrandMarkPainter extends CustomPainter {
  OmniBrandMarkPainter({
    required this.tile,
    required this.strokeWidth,
    required this.dotRadius,
    this.frame = OmniBrandFrame.complete,
  });

  final Color tile;
  final double strokeWidth;
  final double dotRadius;
  final OmniBrandFrame frame;

  /// Chiều dài nét của `stroke-dasharray` trong thiết kế.
  static const double _dash = 170;

  static final Path _backArc = Path()
    ..moveTo(12.5, 58.2)
    ..arcToPoint(
      const Offset(87.5, 29.8),
      radius: const Radius.elliptical(40, 11),
      rotation: -20,
    );

  static final Path _frontArc = Path()
    ..moveTo(12.5, 58.2)
    ..arcToPoint(
      const Offset(87.5, 29.8),
      radius: const Radius.elliptical(40, 11),
      rotation: -20,
      clockwise: false,
    );

  // SVG vẽ vòng tròn bắt đầu từ điểm 3 giờ, theo chiều kim đồng hồ.
  static final Path _ring = Path()
    ..addArc(
      Rect.fromCircle(center: const Offset(49, 45), radius: 21),
      0,
      2 * math.pi,
    );

  static final Path _tail = Path()
    ..moveTo(37, 62)
    ..lineTo(33.5, 75)
    ..lineTo(46, 66.5);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 100, 100),
        const Radius.circular(24),
      ),
      Paint()..color = tile,
    );

    final stroke = Paint()
      ..color = OmniColors.orbit
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    _drawPartial(canvas, _backArc, frame.backArc, stroke);

    // Mặt hành tinh luôn đặc — nó che nửa sau của quỹ đạo ngay từ đầu, kể cả
    // khi viền của nó còn chưa vẽ xong.
    canvas.drawCircle(const Offset(49, 45), 21, Paint()..color = tile);
    _drawPartial(canvas, _ring, frame.ring, stroke..strokeCap = StrokeCap.butt);
    stroke.strokeCap = StrokeCap.round;
    _drawPartial(canvas, _tail, frame.tail, stroke);
    _drawPartial(canvas, _frontArc, frame.frontArc, stroke);

    if (frame.dotOpacity > 0 && frame.dotScale > 0) {
      canvas.save();
      canvas.translate(50, 44);
      canvas.rotate(frame.dotTurn * math.pi / 180);
      canvas.translate(-50, -44);
      canvas.translate(73, 26);
      canvas.scale(frame.dotScale);
      final alpha = frame.dotOpacity.clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset.zero,
        dotRadius,
        Paint()..color = OmniColors.sun.withValues(alpha: alpha),
      );
      canvas.drawCircle(
        Offset.zero,
        dotRadius,
        Paint()
          ..color = tile.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      canvas.restore();
    }

    canvas.restore();
  }

  void _drawPartial(Canvas canvas, Path path, double progress, Paint paint) {
    if (progress <= 0) return;
    if (progress >= 1) {
      canvas.drawPath(path, paint);
      return;
    }
    final visible = _dash * progress;
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(
        metric.extractPath(0, math.min(visible, metric.length)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(OmniBrandMarkPainter oldDelegate) =>
      oldDelegate.tile != tile ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.dotRadius != dotRadius ||
      oldDelegate.frame != frame;
}
