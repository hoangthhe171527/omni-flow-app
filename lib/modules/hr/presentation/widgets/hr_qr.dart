import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

/// Mã QR vẽ bằng một [CustomPainter] (gói `qr` thuần Dart). Nền trắng, ô đen
/// — đúng cả ở chế độ tối để app ngân hàng quét được.
class HrQrCode extends StatelessWidget {
  const HrQrCode({super.key, required this.data, this.size = 200});

  final String data;
  final double size;

  @override
  Widget build(BuildContext context) {
    final image = QrImage(
      QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.M),
    );
    return Semantics(
      label: 'Mã QR nhận lương',
      image: true,
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: CustomPaint(painter: _QrPainter(image)),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.image);

  final QrImage image;

  @override
  void paint(Canvas canvas, Size size) {
    final n = image.moduleCount;
    final cell = size.shortestSide / n;
    final path = Path();
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        if (image.isDark(r, c)) {
          // Nới 0,3 px để không hở vạch trắng giữa hai ô kề nhau.
          path.addRect(Rect.fromLTWH(c * cell, r * cell, cell + .3, cell + .3));
        }
      }
    }
    canvas.drawPath(path, Paint()..color = Colors.black);
  }

  @override
  bool shouldRepaint(_QrPainter old) => old.image != image;
}
