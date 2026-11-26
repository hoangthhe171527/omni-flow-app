import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../platform/omni_motion_scope.dart';
import '../tokens/tokens.dart';
import 'brand_anchor.dart';
import 'omni_brand.dart';

/// Hướng "Quỹ đạo" (duyệt 26/11/2026): chữ V ở giữa ba vòng elip nghiêng
/// −16°, một vệt sao chổi chạy dọc vòng ngoài, các "hành tinh" là kênh khách
/// hàng (Zalo, Facebook, TikTok, Web, điện thoại) chạy quanh — "Mọi khách hàng,
/// một quỹ đạo". Dùng ở màn khởi động, xác thực và màn Ứng dụng.
///
/// Giảm chuyển động: không chạy đồng hồ, vẽ tĩnh khung cuối (vòng đủ, logo
/// đúng chỗ, hành tinh đứng yên).
class OmniOrbit extends StatefulWidget {
  const OmniOrbit({
    super.key,
    this.scale = 1,
    this.planets = false,
    this.drawIn = false,
    this.showLogo = true,
    this.anchorLogo = false,
    this.spin = false,
    this.opacity = 1,
    this.logoLabel,
  });

  /// Tỉ lệ so với khung gốc của thiết kế (vòng ngoài bán trục 184 × 70).
  final double scale;

  /// Có các hành tinh kênh chạy quanh không (màn đăng nhập).
  final bool planets;

  /// Vòng tự vẽ ra (~1,1 giây, lệch nhau 0,18 giây) và logo xoay vào.
  final bool drawIn;

  /// Có logo ở giữa không (màn Ứng dụng chỉ giữ vòng).
  final bool showLogo;

  /// Logo là đích bay của màn mở app ([BrandAnchor]).
  final bool anchorLogo;

  /// Cả hệ vòng xoay chậm (một vòng mỗi 90 giây).
  final bool spin;

  /// Độ mờ chung (vòng mờ làm nền: 0,45).
  final double opacity;

  /// Nhãn đọc màn hình của logo; null = logo trang trí.
  final String? logoLabel;

  /// Cạnh logo ở tỉ lệ 1 — đúng cỡ logo màn mở app, để logo bay về khớp.
  static const double logoSize = 96;

  /// Khung bố cục ở tỉ lệ 1: vòng ngoài nghiêng + hành tinh lọt gần hết.
  static const Size extent = Size(400, 200);

  /// Bán trục (a, b) của ba vòng ở tỉ lệ 1, theo thứ tự vẽ của thiết kế.
  static const rings = <Size>[Size(150, 54), Size(118, 40), Size(184, 70)];

  /// Độ mờ và nét của từng vòng.
  static const ringOpacity = <double>[0.38, 0.22, 0.12];
  static const ringStroke = <double>[1.4, 1, 1];

  /// Góc nghiêng −16° (ngược chiều kim đồng hồ).
  static const double tilt = -16 * math.pi / 180;

  /// Một vòng sao chổi (giây).
  static const double cometPeriod = 4.2;

  /// Tự vẽ vòng: `cubic-bezier(.6,0,.2,1)` trong 1,1 giây, lệch 0,18 giây.
  static const Curve drawCurve = Cubic(0.6, 0, 0.2, 1);
  static const double drawSeconds = 1.1;
  static const double drawStagger = 0.18;

  /// Nảy nhẹ của logo và chữ — `cubic-bezier(.2,.9,.3,1.2)`.
  static const Curve bounce = Cubic(0.2, 0.9, 0.3, 1.2);

  /// Tiến độ tự vẽ của vòng [index] tại giây [t] (0..1).
  static double drawProgress(int index, double t) => drawCurve.transform(
    ((t - drawStagger * index) / drawSeconds).clamp(0.0, 1.0),
  );

  /// Logo xoay vào giữa theo [t] tuyến tính 0..1: hiện dần, phóng .55 → 1,
  /// xoay −12° → 0, có nảy.
  static ({double opacity, double scale, double angle}) logoIn(double t) {
    final e = bounce.transform(t.clamp(0.0, 1.0));
    return (
      opacity: e.clamp(0.0, 1.0),
      scale: 0.55 + 0.45 * e,
      angle: -12 * math.pi / 180 * (1 - e),
    );
  }

  @override
  State<OmniOrbit> createState() => _OmniOrbitState();
}

class _OmniOrbitState extends State<OmniOrbit>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  final _clock = ValueNotifier<double>(0);
  bool? _moving;

  void _onTick(Duration elapsed) =>
      _clock.value = elapsed.inMicroseconds / Duration.microsecondsPerSecond;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final moving = OmniMotion.enabled(context);
    if (moving == _moving) return;
    _moving = moving;
    if (moving) {
      if (!_ticker.isActive) _ticker.start();
    } else {
      _ticker.stop();
      _clock.value = 0;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scale;
    final moving = _moving ?? false;
    final colors = OmniOrbitColors.of(context);

    Widget? logo;
    if (widget.showLogo) {
      Widget mark = OmniBrandMark(
        size: OmniOrbit.logoSize * s,
        framed: false,
        semanticLabel: widget.logoLabel,
      );
      if (widget.anchorLogo) mark = BrandAnchor(child: mark);
      if (widget.drawIn && moving) {
        mark = AnimatedBuilder(
          animation: _clock,
          builder: (_, child) {
            // Logo vào từ 0,55 giây, trong 1 giây.
            final v = OmniOrbit.logoIn(_clock.value - 0.55);
            return Opacity(
              opacity: v.opacity,
              child: Transform.rotate(
                angle: v.angle,
                child: Transform.scale(scale: v.scale, child: child),
              ),
            );
          },
          child: mark,
        );
      }
      if (widget.opacity < 1) {
        mark = Opacity(opacity: widget.opacity, child: mark);
      }
      logo = mark;
    }

    return SizedBox(
      width: OmniOrbit.extent.width * s,
      height: OmniOrbit.extent.height * s,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: OmniOrbitPainter(
                  clock: _clock,
                  scale: s,
                  drawIn: widget.drawIn && moving,
                  planets: widget.planets,
                  spin: widget.spin && moving,
                  opacity: widget.opacity,
                  glow: widget.showLogo ? 1 : 0,
                  colors: colors,
                ),
              ),
            ),
          ),
          ?logo,
        ],
      ),
    );
  }
}

/// Bảng màu của quỹ đạo theo nền. Nền tối là bản chính của thiết kế.
@immutable
class OmniOrbitColors {
  const OmniOrbitColors({
    required this.ring,
    required this.cometHead,
    required this.cometTail,
    required this.glow,
    required this.edge,
  });

  /// Màu chữ "omni" của chữ lớn ở màn khởi động (nền tối).
  static const word = Color(0xFF2D8BFF);

  static OmniOrbitColors of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return dark
        ? OmniOrbitColors(
            ring: OmniColors.darkPrimary,
            cometHead: const Color(0xFFBFE6FF),
            cometTail: OmniColors.orbit,
            glow: const Color(0xFF0A6CFF),
            edge: bg,
          )
        : OmniOrbitColors(
            ring: OmniColors.primary,
            cometHead: OmniColors.orbit,
            cometTail: OmniColors.primary,
            glow: const Color(0xFF0A6CFF),
            edge: bg,
          );
  }

  final Color ring;
  final Color cometHead;
  final Color cometTail;
  final Color glow;

  /// Viền tách hành tinh khỏi vòng (màu nền).
  final Color edge;

  @override
  bool operator ==(Object other) =>
      other is OmniOrbitColors &&
      other.ring == ring &&
      other.cometHead == cometHead &&
      other.cometTail == cometTail &&
      other.glow == glow &&
      other.edge == edge;

  @override
  int get hashCode => Object.hash(ring, cometHead, cometTail, glow, edge);
}

/// Một hành tinh kênh: chữ (hoặc icon) trắng trên chấm màu của kênh.
@immutable
class OrbitPlanet {
  const OrbitPlanet({
    required this.glyph,
    required this.color,
    required this.ring,
    required this.period,
    required this.phase,
    this.fontFamily,
  });

  final String glyph;
  final Color color;

  /// Chạy trên vòng nào (0..2).
  final int ring;

  /// Một vòng mất bao nhiêu giây.
  final double period;

  /// Vị trí lúc bắt đầu (0..1 của vòng) — các kênh không chồng nhau.
  final double phase;

  /// Null = font chữ của app; 'PhosphorFill' cho icon điện thoại.
  final String? fontFamily;

  /// Năm kênh của thiết kế: Zalo, Facebook, TikTok, Web, điện thoại.
  static final channels = <OrbitPlanet>[
    const OrbitPlanet(
      glyph: 'Z',
      color: Color(0xFF0068FF),
      ring: 0,
      period: 7.5,
      phase: 0.05,
    ),
    const OrbitPlanet(
      glyph: 'f',
      color: Color(0xFF1877F2),
      ring: 1,
      period: 9,
      phase: 0.26,
    ),
    const OrbitPlanet(
      glyph: 'T',
      color: Color(0xFF111111),
      ring: 2,
      period: 11,
      phase: 0.47,
    ),
    const OrbitPlanet(
      glyph: 'W',
      color: Color(0xFF30D158),
      ring: 0,
      period: 13,
      phase: 0.68,
    ),
    // Phosphor Fill "phone" (U+E3B8) — font icon đã khai trong pubspec.
    OrbitPlanet(
      glyph: String.fromCharCode(0xe3b8),
      color: const Color(0xFFFF9F0A),
      ring: 2,
      period: 8.2,
      phase: 0.89,
      fontFamily: 'PhosphorFill',
    ),
  ];
}

/// Vẽ ba vòng, sao chổi, quầng sáng sau logo và (tuỳ chọn) hành tinh.
///
/// [clock] là đồng hồ tính bằng giây: nó đổi thì vẽ lại mà không dựng lại
/// widget. Màn khởi động truyền một giá trị đứng yên cho từng khung.
class OmniOrbitPainter extends CustomPainter {
  OmniOrbitPainter({
    required this.clock,
    required this.colors,
    this.center,
    this.scale = 1,
    this.rings = const [1, 1, 1],
    this.drawIn = false,
    this.opacity = 1,
    this.comet = 1,
    this.planets = false,
    this.spin = false,
    this.glow = 0,
  }) : super(repaint: clock);

  final ValueListenable<double> clock;
  final OmniOrbitColors colors;

  /// Tâm hệ vòng trong khung vẽ; null = giữa khung.
  final Offset? center;
  final double scale;

  /// Tiến độ vẽ từng vòng (0..1) khi [drawIn] tắt.
  final List<double> rings;

  /// Tính tiến độ vẽ vòng từ [clock] (vòng tự vẽ ra).
  final bool drawIn;
  final double opacity;

  /// Độ hiện của sao chổi (0..1).
  final double comet;
  final bool planets;
  final bool spin;

  /// Độ mạnh quầng sáng sau logo (0..1); 0 = không vẽ.
  final double glow;

  static ui.Path _ellipse(Size r) {
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: 2 * r.width,
      height: 2 * r.height,
    );
    // Như đường SVG của thiết kế: từ mép trái, xuống đáy, sang phải, lên đỉnh.
    return ui.Path()
      ..moveTo(-r.width, 0)
      ..arcTo(rect, math.pi, -math.pi, false)
      ..arcTo(rect, 0, -math.pi, false);
  }

  /// Đo một lần ở tỉ lệ 1; mọi cỡ khác chỉ nhân lên khi vẽ.
  static final List<ui.PathMetric> _metrics = [
    for (final r in OmniOrbit.rings) _ellipse(r).computeMetrics().first,
  ];

  static final Map<String, TextPainter> _labels = {};

  static TextPainter _label(OrbitPlanet p, double fontSize) {
    final key = '${p.glyph}|${fontSize.toStringAsFixed(1)}';
    return _labels[key] ??= (TextPainter(
      text: TextSpan(
        text: p.glyph,
        style: TextStyle(
          fontFamily: p.fontFamily ?? OmniType.family,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          height: 1,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout());
  }

  /// Vẽ đoạn [from, to] dọc vòng, quấn qua điểm đầu nếu cần.
  static void _strokeAlong(
    Canvas canvas,
    ui.PathMetric m,
    double from,
    double to,
    Paint paint,
  ) {
    final length = m.length;
    final a = from % length;
    final b = a + (to - from);
    if (b <= length) {
      canvas.drawPath(m.extractPath(a, b), paint);
    } else {
      canvas.drawPath(m.extractPath(a, length), paint);
      canvas.drawPath(m.extractPath(0, b - length), paint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0 || scale <= 0) return;
    final t = clock.value;
    final c = center ?? size.center(Offset.zero);
    final angle = OmniOrbit.tilt + (spin ? t * 2 * math.pi / 90 : 0);

    // Quầng sáng thở sau logo (3,6 giây một nhịp).
    if (glow > 0) {
      final breath = (1 - math.cos(t * 2 * math.pi / 3.6)) / 2;
      final r = 110 * scale * (1 + 0.15 * breath);
      final a = 0.32 * glow * opacity * (1 - 0.3 * breath);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = ui.Gradient.radial(
            c,
            r,
            [
              colors.glow.withValues(alpha: a),
              colors.glow.withValues(alpha: 0),
            ],
            const [0, 0.65],
          ),
      );
    }

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
    canvas.scale(scale);

    for (var i = 0; i < _metrics.length; i++) {
      final p = drawIn ? OmniOrbit.drawProgress(i, t) : rings[i];
      if (p <= 0) continue;
      final m = _metrics[i];
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = OmniOrbit.ringStroke[i] / scale
        ..color = colors.ring.withValues(
          alpha: OmniOrbit.ringOpacity[i] * opacity,
        );
      canvas.drawPath(m.extractPath(0, m.length * math.min(p, 1)), paint);
    }

    // Sao chổi: đầu sáng, đuôi 60dp nhạt dần, chạy dọc vòng 0.
    final cometAlpha =
        comet * opacity * (drawIn ? OmniOrbit.drawProgress(0, t) : 1);
    if (cometAlpha > 0) {
      final m = _metrics[0];
      final head = (t / OmniOrbit.cometPeriod % 1) * m.length;
      final tail = math.min(60 / scale, m.length / 4);
      const steps = 10;
      for (var j = 0; j < steps; j++) {
        final k = 1 - j / steps;
        _strokeAlong(
          canvas,
          m,
          head - tail * (j + 1) / steps,
          head - tail * j / steps,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 2.4 / scale
            ..color = Color.lerp(
              colors.cometTail,
              colors.cometHead,
              k,
            )!.withValues(alpha: cometAlpha * k),
        );
      }
    }
    canvas.restore();

    if (!planets) return;
    final cosA = math.cos(angle);
    final sinA = math.sin(angle);
    final radius = 11 * scale;
    for (final planet in OrbitPlanet.channels) {
      final m = _metrics[planet.ring];
      final along = ((t / planet.period + planet.phase) % 1) * m.length;
      final local = m.getTangentForOffset(along)?.position;
      if (local == null) continue;
      final at =
          Offset(
                local.dx * cosA - local.dy * sinA,
                local.dx * sinA + local.dy * cosA,
              ) *
              scale +
          c;
      canvas.drawCircle(
        at,
        radius,
        Paint()..color = planet.color.withValues(alpha: opacity),
      );
      canvas.drawCircle(
        at,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = colors.edge.withValues(alpha: opacity),
      );
      final label = _label(planet, 10 * scale);
      final fade = opacity < 1;
      if (fade) {
        canvas.saveLayer(
          null,
          Paint()..color = Color.fromRGBO(0, 0, 0, opacity),
        );
      }
      label.paint(canvas, at - Offset(label.width / 2, label.height / 2));
      if (fade) canvas.restore();
    }
  }

  @override
  bool shouldRepaint(OmniOrbitPainter old) =>
      old.clock != clock ||
      old.colors != colors ||
      old.center != center ||
      old.scale != scale ||
      !listEquals(old.rings, rings) ||
      old.drawIn != drawIn ||
      old.opacity != opacity ||
      old.comet != comet ||
      old.planets != planets ||
      old.spin != spin ||
      old.glow != glow;
}

/// Cỡ chữ riêng của hướng Quỹ đạo — nằm trong `lib/design` để màn không đặt
/// cỡ thô (xem `no_raw_font_size_outside_design_test`).
abstract final class OmniOrbitType {
  /// Tiêu đề lớn màn xác thực: 32/800, chữ khít −0,02em.
  static const TextStyle heroTitle = TextStyle(
    fontFamily: OmniType.family,
    fontSize: 32,
    fontWeight: FontWeight.w800,
    height: 1.2,
    letterSpacing: -0.64,
  );

  /// Chữ "Viomni" lớn ở màn khởi động: 40/800.
  static const TextStyle wordmark = TextStyle(
    fontFamily: OmniType.brandFamily,
    fontSize: 40,
    fontWeight: FontWeight.w800,
    height: 1.25,
    letterSpacing: -0.8,
  );

  /// Lời chào một dòng màn Ứng dụng: 26/800.
  static const TextStyle greeting = TextStyle(
    fontFamily: OmniType.family,
    fontSize: 26,
    fontWeight: FontWeight.w800,
    height: 1.25,
    letterSpacing: -0.52,
  );

  /// Số trong thẻ "Hôm nay": 24/800, số đều.
  static const TextStyle stat = TextStyle(
    fontFamily: OmniType.family,
    fontSize: 24,
    fontWeight: FontWeight.w800,
    height: 1.2,
    fontFeatures: OmniType.tabular,
  );

  /// Chữ nút chính cao 54: 17/600.
  static const TextStyle button = TextStyle(
    fontFamily: OmniType.family,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );
}
