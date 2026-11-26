import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../tokens/tokens.dart';
import 'omni_brand.dart';

/// Màn mở app (artifact "Màn xác thực" duyệt 26/11): khung đầu TRÙNG màn khởi
/// động của hệ điều hành — logo trần 96 đứng giữa màn, không ô nền — rồi hai
/// vòng hào quang nở ra sau logo, một vòng sáng tỏa ra từ mép logo, chữ
/// "Viomni" nổi lên bên dưới; hào quang tắt hẳn trước khi logo bay về chỗ.
///
/// Hào quang chỉ tỏa ra NGOÀI logo: mọi lớp sáng bị mặt nạ chừa trống một vòng
/// bán kính [_clearRadius] quanh tâm logo, không phủ lên logo.
///
/// [progress] = null là khung TĨNH của màn chờ khôi phục phiên: logo + hai vòng
/// hào quang, không chữ; [pulse] (0..1, lặp) cho hai vòng sáng tỏa thay vòng
/// quay.
class OmniSplash extends StatelessWidget {
  const OmniSplash({super.key, this.progress, this.pulse, this.flight});

  /// Thời điểm trên trục thời gian, tính theo đơn vị [timeline]: 0..1 là phần
  /// dựng hình; lớn hơn 1 khi đang bay.
  final double? progress;

  /// Pha của nhịp tỏa ở màn chờ (0..1, lặp). Null = không tỏa.
  final double? pulse;

  /// Pha bay logo về chỗ của nó trên màn đích (xem `LaunchSplash`).
  final SplashFlight? flight;

  /// Phần dựng hình: hào quang nở, vòng tỏa, chữ nổi; hết hào quang ở ~990ms.
  static const timeline = Duration(milliseconds: 960);

  /// `cubic-bezier(.32,.72,0,1)` — pha bay: rời chỗ nhanh, đáp êm.
  static const Curve flightCurve = Cubic(0.32, 0.72, 0, 1);

  /// Cạnh logo trần giữa màn — đúng cỡ logo trên màn khởi động hệ điều hành.
  static const double logoSize = 96;

  /// Vòng hào quang trên nền sáng — chỉ dùng ở đây nên không thành token.
  static const _lightHaloOuter = Color(0xFFEBF3FF);
  static const _lightHaloInner = Color(0xFFDCEBFF);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final s = progress == null
        ? _SplashFrame.still
        : _SplashFrame.at(progress! * timeline.inMilliseconds);
    final fly = flight?.t ?? 0;

    final rings = <({double scale, double opacity})>[
      if (s.ringOpacity > 0) (scale: s.ringScale, opacity: s.ringOpacity),
      if (pulse != null) ...[_pulseRing(pulse!), _pulseRing(pulse! + 0.5)],
    ];

    Widget word = _LetterWordmark(letters: s.letters, dark: dark);
    // Bay mà đích không có chữ (màn đăng nhập): chữ mờ và trượt lên 24.
    if (flight != null && flight!.wordTarget == null) {
      word = Opacity(
        opacity: 1 - fly,
        child: Transform.translate(offset: Offset(0, -24 * fly), child: word),
      );
    }

    final background = dark ? OmniColors.ink : OmniColors.background;

    // Material chứ không ColoredBox: lớp phủ nằm TRÊN navigator, ngoài mọi
    // Scaffold, và chữ không có Material phía trên thì Flutter gạch chân vàng.
    return Material(
      color: background.withValues(alpha: 1 - fly),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: 1 - fly,
                  child: CustomPaint(
                    painter: _AuraPainter(
                      haloOpacity: s.haloOpacity,
                      haloScale: s.haloScale,
                      rings: rings,
                      dark: dark,
                    ),
                  ),
                ),
              ),
              // Logo đúng giữa màn như màn khởi động hệ điều hành.
              Center(
                child: _FlyTo(
                  target: flight?.logoTarget,
                  t: fly,
                  child: const KeyedSubtree(
                    key: ValueKey('splash-logo'),
                    child: OmniBrandMark(
                      size: logoSize,
                      framed: false,
                      semanticLabel: 'Logo Viomni',
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: h / 2 + logoSize / 2 + 18,
                child: Center(
                  child: _FlyTo(
                    target: flight?.wordTarget,
                    t: fly,
                    child: word,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Một vòng của nhịp tỏa màn chờ: hiện nhanh, nở 1 → 2,2 rồi tắt dần.
  static ({double scale, double opacity}) _pulseRing(double phase) {
    final p = phase % 1;
    final eased = const Cubic(0.2, 0.6, 0.35, 1).transform(p);
    final opacity = p < 0.18 ? p / 0.18 : 1 - (p - 0.18) / 0.82;
    return (scale: 1 + 1.2 * eased, opacity: opacity.clamp(0.0, 1.0));
  }
}

/// Bán kính vùng trống quanh tâm logo (logo trần 96 rộng ~84) và mép mờ của nó.
const double _clearRadius = 60;
const double _clearFade = 82;

/// Hai vòng hào quang + các vòng tỏa, cắt bởi mặt nạ chừa trống quanh logo.
class _AuraPainter extends CustomPainter {
  _AuraPainter({
    required this.haloOpacity,
    required this.haloScale,
    required this.rings,
    required this.dark,
  });

  final double haloOpacity;
  final double haloScale;
  final List<({double scale, double opacity})> rings;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    if (haloOpacity <= 0 && rings.isEmpty) return;
    final c = size.center(Offset.zero);
    final bounds = Offset.zero & size;
    canvas.saveLayer(bounds, Paint());

    if (haloOpacity > 0) {
      final outer = dark ? OmniColors.inkHaloOuter : OmniSplash._lightHaloOuter;
      final inner = dark ? OmniColors.inkHaloInner : OmniSplash._lightHaloInner;
      canvas.drawCircle(
        c,
        170 * haloScale,
        Paint()..color = outer.withValues(alpha: haloOpacity),
      );
      canvas.drawCircle(
        c,
        125 * haloScale,
        Paint()..color = inner.withValues(alpha: haloOpacity),
      );
    }

    final peak = OmniColors.orbit.withValues(alpha: dark ? 0.40 : 0.32);
    final tail = OmniColors.primary.withValues(alpha: dark ? 0.16 : 0.10);
    for (final ring in rings) {
      if (ring.opacity <= 0) continue;
      final r = 90 * ring.scale;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.transparent,
              peak.withValues(alpha: peak.a * ring.opacity),
              tail.withValues(alpha: tail.a * ring.opacity),
              Colors.transparent,
            ],
            stops: const [0.56, 0.67, 0.73, 0.80],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    // Mặt nạ: giữ phần ngoài, xoá phần trong vòng [_clearRadius] quanh logo.
    const maskRadius = 240.0;
    canvas.drawRect(
      bounds,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = const RadialGradient(
          colors: [Colors.transparent, Colors.black, Colors.black],
          stops: [_clearRadius / maskRadius, _clearFade / maskRadius, 1],
        ).createShader(Rect.fromCircle(center: c, radius: maskRadius)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AuraPainter old) =>
      old.haloOpacity != haloOpacity ||
      old.haloScale != haloScale ||
      old.dark != dark ||
      old.rings.length != rings.length ||
      !_sameRings(old.rings, rings);

  static bool _sameRings(
    List<({double scale, double opacity})> a,
    List<({double scale, double opacity})> b,
  ) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Pha bay: [t] (đã qua đường cong) 0..1, và đích của logo / chữ tính theo toạ
/// độ màn hình. [wordTarget] null nghĩa là đích không có chữ đi kèm.
@immutable
class SplashFlight {
  const SplashFlight({required this.t, this.logoTarget, this.wordTarget});

  final double t;
  final Rect? logoTarget;
  final Rect? wordTarget;
}

/// "Viomni" cỡ 28/800, mỗi ký tự nổi lên riêng: trượt lên 10dp và hiện dần.
/// Màu như [OmniWordmark]: "Vi" mực/trắng, "omni" màu chính/quỹ đạo sáng.
class _LetterWordmark extends StatelessWidget {
  const _LetterWordmark({required this.letters, required this.dark});

  static const _text = 'Viomni';
  static const _fontSize = 28.0;

  final List<double> letters;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    if (letters.every((v) => v <= 0)) return const SizedBox.shrink();
    final base = OmniType.wordmark.copyWith(
      fontSize: _fontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.02 * _fontSize,
    );
    return Semantics(
      label: _text,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _text.length; i++)
            Opacity(
              opacity: letters[i],
              child: Transform.translate(
                offset: Offset(0, 10 * (1 - letters[i])),
                child: Text(
                  _text[i],
                  style: base.copyWith(
                    color: i < 2
                        ? (dark ? Colors.white : OmniColors.ink)
                        : (dark ? OmniColors.orbit : OmniColors.primary),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Vẽ con của nó dời từ chỗ bố cục sẵn tới [target] (toạ độ màn hình), giữ
/// tỉ lệ và căn giữa trong đích, theo [t] 0..1. Chỉ đổi lúc vẽ — bố cục của
/// cột không xê dịch — và `applyPaintTransform` khớp, nên `localToGlobal`
/// (và bài kiểm) thấy đúng chỗ đang vẽ.
class _FlyTo extends SingleChildRenderObjectWidget {
  const _FlyTo({required this.target, required this.t, super.child});

  final Rect? target;
  final double t;

  @override
  _RenderFlyTo createRenderObject(BuildContext context) =>
      _RenderFlyTo(target, t);

  @override
  void updateRenderObject(BuildContext context, _RenderFlyTo renderObject) {
    renderObject
      ..target = target
      ..t = t;
  }
}

class _RenderFlyTo extends RenderProxyBox {
  _RenderFlyTo(this._target, this._t);

  Rect? _target;
  set target(Rect? value) {
    if (value == _target) return;
    _target = value;
    markNeedsPaint();
  }

  double _t;
  set t(double value) {
    if (value == _t) return;
    _t = value;
    markNeedsPaint();
  }

  bool get _flying => _target != null && _t > 0 && !size.isEmpty;

  Matrix4 _transform() {
    if (!_flying) return Matrix4.identity();
    final target = _target!;
    final local = Rect.fromPoints(
      globalToLocal(target.topLeft),
      globalToLocal(target.bottomRight),
    );
    final scale = math.min(
      local.width / size.width,
      local.height / size.height,
    );
    final end = Rect.fromCenter(
      center: local.center,
      width: size.width * scale,
      height: size.height * scale,
    );
    final r = Rect.lerp(Offset.zero & size, end, _t)!;
    return Matrix4.translationValues(r.left, r.top, 0)
      ..scaleByDouble(r.width / size.width, r.height / size.height, 1, 1);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_flying) {
      layer = null;
      return super.paint(context, offset);
    }
    layer = context.pushTransform(
      needsCompositing,
      offset,
      _transform(),
      super.paint,
      oldLayer: layer is TransformLayer ? layer as TransformLayer? : null,
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(_transform());
  }
}

/// Mọi giá trị của một khung hình, tính từ mốc thời gian (ms). Mốc theo
/// artifact duyệt (tổng 1,6 giây, bay từ 960ms).
class _SplashFrame {
  const _SplashFrame({
    required this.haloOpacity,
    required this.haloScale,
    required this.ringOpacity,
    required this.ringScale,
    required this.letters,
  });

  /// Khung tĩnh của màn chờ: logo + hai vòng hào quang, không chữ.
  static const still = _SplashFrame(
    haloOpacity: 1,
    haloScale: 1,
    ringOpacity: 0,
    ringScale: 1,
    letters: [0, 0, 0, 0, 0, 0],
  );

  factory _SplashFrame.at(double ms) {
    double seg(double start, double duration, Curve curve) {
      final t = ((ms - start) / duration).clamp(0.0, 1.0);
      return curve.transform(t);
    }

    // Hào quang: nở 0 → 480ms (.7 → 1), giữ, tắt 800 → 990ms trước khi bay.
    final haloIn = seg(0, 480, _outExpo);
    final haloOut = seg(800, 190, Curves.easeInOut);

    // Vòng tỏa một lần: 320 → 930ms, hiện nhanh rồi nở 1 → 2,2 và tắt dần.
    final ringT = ((ms - 320) / 610).clamp(0.0, 1.0);
    final ringOpacity = ringT <= 0 || ringT >= 1
        ? 0.0
        : ringT < 0.13
        ? ringT / 0.13
        : 1 - (ringT - 0.13) / 0.87;

    return _SplashFrame(
      haloOpacity: haloIn * (1 - haloOut),
      haloScale: 0.7 + 0.3 * haloIn + 0.04 * haloOut,
      ringOpacity: ringOpacity,
      ringScale: 1 + 1.2 * Curves.easeOut.transform(ringT),
      letters: [for (var i = 0; i < 6; i++) seg(190 + 45.0 * i, 400, _outExpo)],
    );
  }

  /// `cubic-bezier(.16,1,.3,1)` — ra nhanh, đáp êm.
  static const _outExpo = Cubic(0.16, 1, 0.3, 1);

  final double haloOpacity;
  final double haloScale;
  final double ringOpacity;
  final double ringScale;
  final List<double> letters;
}
