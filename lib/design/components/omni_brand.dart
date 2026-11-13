import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

/// Logo Viomni V-Orbit: chữ V dải ruy-băng 3D kết hợp vành đai quỹ đạo nghiêng.
///
/// Vẽ bằng [CustomPainter] theo đúng SVG của logo Viomni V-Orbit
/// (viewBox 0 0 100 100) chứ không nạp một tệp ảnh: app chưa có `flutter_svg`,
/// và vẽ bằng tay còn cho phép màn mở app VẼ DẦN từng nét (xem [OmniBrandFrame]).
class OmniBrandMark extends StatelessWidget {
  const OmniBrandMark({
    super.key,
    this.size = 36,
    this.onInk,
    this.framed = true,
    this.frame = OmniBrandFrame.complete,
    this.semanticLabel,
  });

  /// Cạnh của ô vuông, dp.
  final double size;

  /// null = theo độ sáng theme; true = ô mực [OmniColors.inkRaised] (logo trên
  /// mặt mực: đăng nhập, mở app); false = ô sáng.
  final bool? onInk;

  /// Có vẽ ô nền bo góc quanh biểu tượng hay không. Header dùng logo phẳng để
  /// không tạo thêm một "nút" giả; splash/login vẫn giữ mặt logo đầy đủ.
  final bool framed;

  /// Từng nét đã vẽ tới đâu. Mặc định là logo hoàn chỉnh.
  final OmniBrandFrame frame;

  /// Null = logo trang trí, bị bỏ qua bởi trình đọc màn hình (như
  /// `aria-hidden` trong thiết kế): cạnh nó luôn có chữ nói cùng một điều.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final dark = onInk ?? Theme.of(context).brightness == Brightness.dark;
    final mark = CustomPaint(
      size: Size.square(size),
      painter: OmniBrandMarkPainter(
        tile: dark
            ? (onInk == true ? OmniColors.inkRaised : OmniColors.ink)
            : Colors.white,
        tileBorder: framed && !dark ? const Color(0xFFE3E8EF) : null,
        drawTile: framed,
        stroke: dark ? OmniColors.orbit : OmniColors.primary,
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
/// (tối đa là cả nét). Vì thế nét ngắn xong sớm, nét dài xong muộn —
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

  /// Góc (độ) chấm sáng đang lệch khỏi chỗ nghỉ, quay quanh tâm (50, 44).
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
    required this.stroke,
    this.tileBorder,
    this.drawTile = true,
    required this.strokeWidth,
    required this.dotRadius,
    this.frame = OmniBrandFrame.complete,
  });

  final Color tile;
  final Color stroke;
  final Color? tileBorder;
  final bool drawTile;
  final double strokeWidth;
  final double dotRadius;
  final OmniBrandFrame frame;

  /// Cánh phải dải ruy-băng chữ V 3D (`viewBox 0 0 100 100`).
  static final Path _wingRight = Path()
    ..moveTo(47, 50)
    ..lineTo(60, 28)
    ..cubicTo(62.5, 23.8, 66.5, 22, 71.5, 22)
    ..lineTo(79, 22)
    ..lineTo(52.5, 68)
    ..cubicTo(49.5, 73, 45, 73, 42.5, 68)
    ..close();

  /// Nếp gấp phản sáng giữa hai cánh chữ V.
  static final Path _innerFold = Path()
    ..moveTo(47, 50)
    ..lineTo(54.5, 60.5)
    ..cubicTo(57.5, 58.5, 61, 55.5, 64, 51.5)
    ..lineTo(55, 36.5)
    ..close();

  /// Cánh trái dải ruy-băng chữ V 3D.
  static final Path _wingLeft = Path()
    ..moveTo(17, 22)
    ..lineTo(33, 22)
    ..cubicTo(38, 22, 42, 24.2, 44.5, 28.5)
    ..lineTo(57.5, 52)
    ..lineTo(51.5, 62.5)
    ..lineTo(35.5, 66.5)
    ..lineTo(17, 22)
    ..close();

  /// Đáy nhọn chữ V tạo chiều sâu khối dưới rãnh cắt quỹ đạo.
  static final Path _apexTip = Path()
    ..moveTo(39.5, 69.5)
    ..lineTo(57.5, 61.5)
    ..lineTo(51, 74)
    ..cubicTo(48.5, 78.5, 43.2, 78.5, 40.8, 74)
    ..close();

  /// Cánh cung quỹ đạo lưỡi liềm vát nhọn hai đầu (Orbit Swoosh).
  static final Path _orbitSwoosh = Path()
    ..moveTo(61, 19)
    ..cubicTo(78, 14.5, 89.5, 19.5, 87, 30.5)
    ..cubicTo(83.5, 44.5, 60.5, 61, 36.5, 68.5)
    ..cubicTo(19.5, 73.8, 11.5, 69.5, 15.5, 57.5)
    ..cubicTo(17.5, 51.8, 22, 46.2, 27.5, 41.5)
    ..cubicTo(23.2, 46.8, 20.8, 52, 21.8, 56.2)
    ..cubicTo(23.5, 63.2, 35.8, 63.5, 53, 56.5)
    ..cubicTo(69.5, 49.8, 81.2, 38.2, 79.8, 29.5)
    ..cubicTo(78.8, 23.2, 71.5, 19.8, 61, 19)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);

    final dark = stroke == OmniColors.orbit;

    if (drawTile) {
      const tileRect = Rect.fromLTWH(0, 0, 100, 100);
      final tileRRect = RRect.fromRectAndRadius(
        tileRect,
        const Radius.circular(24),
      );
      canvas.drawRRect(tileRRect, Paint()..color = tile);
      // Lớp phủ kính mờ nhẹ từ đỉnh xuống tạo chiều sâu bề mặt.
      canvas.drawRRect(
        tileRRect,
        Paint()
          ..shader = ui.Gradient.linear(
            const Offset(0, 0),
            const Offset(0, 100),
            [
              Colors.white.withValues(alpha: dark ? 0.10 : 0.45),
              Colors.white.withValues(alpha: 0.0),
            ],
            const [0.0, 0.55],
          ),
      );
    } else {
      // Trên thanh đầu (30dp không khung), phóng nhẹ quanh tâm để biểu tượng
      // đầy đặn và sắc nét.
      canvas.translate(50, 50);
      canvas.scale(1.12);
      canvas.translate(-50, -50);
    }

    if (tileBorder != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(1.5, 1.5, 97, 97),
          const Radius.circular(22.5),
        ),
        Paint()
          ..color = tileBorder!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    final ringP = frame.ring.clamp(0.0, 1.0);
    final tailP = frame.tail.clamp(0.0, 1.0);
    final cutP = frame.frontArc.clamp(0.0, 1.0);
    final swooshP = (frame.backArc * 0.5 + frame.frontArc * 0.5).clamp(
      0.0,
      1.0,
    );

    // Nhóm chữ V 3D bọc trong saveLayer riêng để cắt âm bản rãnh quỹ đạo xuyên
    // thấu chuẩn xác cả khi đặt trên nền trong suốt lẫn nền ô.
    if (ringP > 0 || tailP > 0) {
      canvas.saveLayer(const Rect.fromLTWH(-12, -12, 124, 124), Paint());

      if (ringP > 0) {
        canvas.save();
        if (ringP < 1) {
          canvas.clipRect(Rect.fromLTWH(38, 20, 44, 58 * ringP));
        }
        canvas.drawPath(
          _wingRight,
          Paint()
            ..shader = ui.Gradient.linear(
              const Offset(78, 22),
              const Offset(46, 78),
              dark
                  ? [
                      const Color(0xFF5EC2FF).withValues(alpha: ringP),
                      const Color(0xFF1E7BFF).withValues(alpha: ringP),
                      const Color(0xFF0159DB).withValues(alpha: ringP),
                    ]
                  : [
                      const Color(0xFF2DABFF).withValues(alpha: ringP),
                      const Color(0xFF0159DB).withValues(alpha: ringP),
                      const Color(0xFF003594).withValues(alpha: ringP),
                    ],
              const [0.0, 0.58, 1.0],
            ),
        );
        canvas.drawPath(
          _innerFold,
          Paint()
            ..color = const Color(0xFF2DABFF).withValues(alpha: 0.45 * ringP),
        );
        canvas.restore();
      }

      if (tailP > 0) {
        canvas.save();
        if (tailP < 1) {
          canvas.clipRect(Rect.fromLTWH(15, 20, 46, 62 * tailP));
        }
        canvas.drawPath(
          _wingLeft,
          Paint()
            ..shader = ui.Gradient.linear(
              const Offset(18, 22),
              const Offset(54, 82),
              dark
                  ? [
                      const Color(0xFF5EC2FF).withValues(alpha: tailP),
                      const Color(0xFF1E7BFF).withValues(alpha: tailP),
                      const Color(0xFF0A47B8).withValues(alpha: tailP),
                    ]
                  : [
                      const Color(0xFF2DABFF).withValues(alpha: tailP),
                      const Color(0xFF0159DB).withValues(alpha: tailP),
                      const Color(0xFF002B80).withValues(alpha: tailP),
                    ],
              const [0.0, 0.55, 1.0],
            ),
        );
        canvas.drawPath(
          _apexTip,
          Paint()
            ..color = (dark ? const Color(0xFF0A47B8) : const Color(0xFF002673))
                .withValues(alpha: tailP),
        );
        canvas.restore();
      }

      if (cutP > 0) {
        canvas.save();
        if (cutP < 1) {
          canvas.clipRect(Rect.fromLTWH(8, 10, 84 * cutP, 72));
        }
        canvas.drawPath(_orbitSwoosh, Paint()..blendMode = BlendMode.clear);
        canvas.drawPath(
          _orbitSwoosh,
          Paint()
            ..blendMode = BlendMode.clear
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4.2
            ..strokeJoin = StrokeJoin.round
            ..strokeCap = StrokeCap.round,
        );
        canvas.restore();
      }

      canvas.restore();
    }

    if (swooshP > 0) {
      canvas.save();
      if (swooshP < 1) {
        canvas.clipRect(Rect.fromLTWH(8, 10, 84 * swooshP, 72));
      }
      canvas.drawPath(
        _orbitSwoosh,
        Paint()
          ..shader = ui.Gradient.linear(
            const Offset(14, 68),
            const Offset(90, 24),
            dark
                ? [
                    const Color(0xFF5EC2FF).withValues(alpha: swooshP),
                    const Color(0xFF2DABFF).withValues(alpha: swooshP),
                    const Color(0xFF1E7BFF).withValues(alpha: swooshP),
                  ]
                : [
                    const Color(0xFF2DABFF).withValues(alpha: swooshP),
                    const Color(0xFF0A6CFF).withValues(alpha: swooshP),
                    const Color(0xFF0159DB).withValues(alpha: swooshP),
                  ],
            const [0.0, 0.50, 1.0],
          ),
      );
      canvas.restore();
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(OmniBrandMarkPainter oldDelegate) =>
      oldDelegate.tile != tile ||
      oldDelegate.stroke != stroke ||
      oldDelegate.tileBorder != tileBorder ||
      oldDelegate.drawTile != drawTile ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.dotRadius != dotRadius ||
      oldDelegate.frame != frame;
}
