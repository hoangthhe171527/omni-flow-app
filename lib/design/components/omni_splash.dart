import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../tokens/tokens.dart';
import 'omni_brand.dart';

/// Màn mở app "quỹ đạo" (khung `Intro` của bản thiết kế): ô logo hiện ra khỏi
/// lớp mờ, vòng tròn vẽ ra, đuôi bong bóng, hai nửa quỹ đạo, chấm vàng quay
/// vào chỗ rồi bật sáng, chữ "Viomni" nổi lên từng ký tự, rồi câu khẩu hiệu.
///
/// Nền theo theme: sáng là [OmniColors.background] với hai vòng sáng xanh nhạt,
/// tối là nền mực.
///
/// [progress] = null là khung hình CUỐI (tĩnh) — màn chờ khôi phục phiên dùng
/// đúng khung này, để khi lớp hiệu ứng mờ đi thì bên dưới là cùng một hình và
/// không có cú giật nào.
class OmniSplash extends StatelessWidget {
  const OmniSplash({super.key, this.progress, this.footer, this.flight});

  /// Thời điểm trên trục thời gian, tính theo đơn vị [timeline]: 0..1 là phần
  /// dựng hình; lớn hơn 1 khi đang bay (quầng vàng vẫn tắt dần nốt).
  final double? progress;

  /// Thứ đặt ở đáy màn — màn chờ khôi phục phiên đặt một vạch tiến độ ở đây.
  final Widget? footer;

  /// Pha bay logo về chỗ của nó trên màn đích (xem `LaunchSplash`).
  final SplashFlight? flight;

  /// Phần dựng hình: chữ và khẩu hiệu xong ở 1750ms, giữ một nhịp rồi bay.
  static const timeline = Duration(milliseconds: 1800);

  /// `cubic-bezier(.65,0,.35,1)` — vào chậm, ra chậm: nét vẽ và pha bay.
  static const Curve flightCurve = Cubic(0.65, 0, 0.35, 1);

  static const _tileSize = 148.0;

  static const String tagline = 'Mọi khách hàng, một quỹ đạo';

  /// Vòng sáng trên nền sáng — chỉ dùng ở đây nên không thành token.
  static const _lightHaloOuter = Color(0xFFEAF4F3);
  static const _lightHaloInner = Color(0xFFE1F0EE);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ms = progress == null
        ? double.infinity
        : progress! * timeline.inMilliseconds;
    final s = _SplashFrame.at(ms);
    final fly = flight?.t ?? 0;
    // Bay mà đích không có chữ (màn đăng nhập): chữ mờ và trượt lên 24.
    final wordLeaves = flight != null && flight!.wordTarget == null;

    final background = dark ? OmniColors.ink : OmniColors.background;

    // Material chứ không ColoredBox: lớp phủ nằm TRÊN navigator, ngoài mọi
    // Scaffold, và chữ không có Material phía trên thì Flutter gạch chân vàng.
    return Material(
      color: background.withValues(alpha: 1 - fly),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          // Hai quầng tròn đồng tâm, tâm lệch xuống dưới giữa màn 73dp — đúng
          // vị trí trong khung 390×844 của thiết kế.
          final haloCenter = Offset(w / 2, h / 2 + 73);

          Widget word = _LetterWordmark(letters: s.letters, dark: dark);
          if (wordLeaves) {
            word = Opacity(
              opacity: 1 - fly,
              child: Transform.translate(
                offset: Offset(0, -24 * fly),
                child: word,
              ),
            );
          }

          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Opacity(
                opacity: 1 - fly,
                child: Stack(
                  children: [
                    _halo(
                      haloCenter,
                      315 * s.haloOuter,
                      dark ? OmniColors.inkHaloOuter : _lightHaloOuter,
                    ),
                    _halo(
                      haloCenter,
                      235 * s.haloInner,
                      dark ? OmniColors.inkHaloInner : _lightHaloInner,
                    ),
                  ],
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _FlyTo(
                      target: flight?.logoTarget,
                      t: fly,
                      child: KeyedSubtree(
                        key: const ValueKey('splash-logo'),
                        child: _logo(s),
                      ),
                    ),
                    const SizedBox(height: 28),
                    _FlyTo(target: flight?.wordTarget, t: fly, child: word),
                    const SizedBox(height: OmniSpacing.sm),
                    Opacity(
                      opacity: 1 - fly,
                      child: _Rise(
                        value: s.tag,
                        child: Text(
                          tagline,
                          style: OmniType.bodyStrong.copyWith(
                            fontWeight: FontWeight.w400,
                            color: dark
                                ? OmniColors.inkMutedForeground
                                : OmniColors.mutedForeground,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (footer != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 40,
                  child: Center(child: footer),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Ô logo 148 với quầng vàng sau chấm; hiện ra khỏi lớp mờ.
  Widget _logo(_SplashFrame s) {
    final tile = SizedBox.square(
      dimension: _tileSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (s.glowOpacity > 0)
            Positioned(
              left: 34,
              top: 4,
              width: 80,
              height: 80,
              child: Opacity(
                opacity: s.glowOpacity,
                child: Transform.scale(
                  scale: s.glowScale,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      color: OmniColors.sun,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          OmniBrandMark(
            size: _tileSize,
            frame: s.mark,
            semanticLabel: 'Logo Viomni',
          ),
        ],
      ),
    );
    return Opacity(
      opacity: s.tileOpacity,
      child: _blur(
        s.tileBlur,
        Transform.scale(scale: s.tileScale, child: tile),
      ),
    );
  }

  Widget _halo(Offset center, double radius, Color color) {
    return Positioned(
      left: center.dx - radius,
      top: center.dy - radius,
      width: radius * 2,
      height: radius * 2,
      child: DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
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

Widget _blur(double sigma, Widget child) {
  if (sigma <= 0.01) return child;
  return ImageFiltered(
    imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
    child: child,
  );
}

/// Chữ trượt lên 14dp và hiện dần (`sp-rise`).
class _Rise extends StatelessWidget {
  const _Rise({required this.value, required this.child});

  final double value;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, 14 * (1 - value)),
        child: child,
      ),
    );
  }
}

/// "Viomni" cỡ 34, mỗi ký tự nổi lên riêng: trượt lên 14dp, hết mờ 6 → 0.
/// Màu như [OmniWordmark]: "Vi" mực/trắng, "omni" màu chính/quỹ đạo sáng.
class _LetterWordmark extends StatelessWidget {
  const _LetterWordmark({required this.letters, required this.dark});

  static const _text = 'Viomni';
  static const _fontSize = 34.0;

  final List<double> letters;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final base = OmniType.wordmark.copyWith(
      fontSize: _fontSize,
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
                offset: Offset(0, 14 * (1 - letters[i])),
                child: _blur(
                  6 * (1 - letters[i]),
                  Text(
                    _text[i],
                    style: base.copyWith(
                      color: i < 2
                          ? (dark ? Colors.white : OmniColors.ink)
                          : (dark ? OmniColors.orbit : OmniColors.primary),
                    ),
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

/// Mọi giá trị của một khung hình, tính từ mốc thời gian (ms).
///
/// Mốc, thời lượng và đường cong chép từ khung `Intro` của bản thiết kế.
class _SplashFrame {
  const _SplashFrame({
    required this.tileScale,
    required this.tileOpacity,
    required this.tileBlur,
    required this.haloOuter,
    required this.haloInner,
    required this.mark,
    required this.glowOpacity,
    required this.glowScale,
    required this.letters,
    required this.tag,
  });

  factory _SplashFrame.at(double ms) {
    double seg(double start, double duration, Curve curve) {
      final t = ((ms - start) / duration).clamp(0.0, 1.0);
      return curve.transform(t);
    }

    // Ô logo: 0 → 550ms, .9 → 1, hiện dần, mờ 10 → 0.
    final tile = seg(0, 550, _outExpo);

    // Chấm bật: 1200 → 1620ms. 0%: 0, 60%: 1.35, 100%: 1 — đường cong nảy áp
    // cho TỪNG đoạn giữa hai mốc, như CSS làm.
    final popT = ((ms - 1200) / 420).clamp(0.0, 1.0);
    double dotScale;
    double dotOpacity;
    if (popT <= 0.6) {
      final u = OmniCurves.pop.transform(popT / 0.6);
      dotScale = 1.35 * u;
      dotOpacity = u.clamp(0.0, 1.0);
    } else {
      final u = OmniCurves.pop.transform((popT - 0.6) / 0.4);
      dotScale = 1.35 - 0.35 * u;
      dotOpacity = 1;
    }

    // Quầng vàng: 1240 → 2140ms, ease-out. Độ mờ 0 → .55 (giữa) → 0; cỡ .6 → 1.6.
    final glowT = ((ms - 1240) / 900).clamp(0.0, 1.0);
    final glowOpacity = glowT <= 0 || glowT >= 1
        ? 0.0
        : glowT <= 0.5
        ? 0.55 * Curves.easeOut.transform(glowT / 0.5)
        : 0.55 * (1 - Curves.easeOut.transform((glowT - 0.5) / 0.5));

    return _SplashFrame(
      tileScale: 0.9 + 0.1 * tile,
      tileOpacity: tile.clamp(0.0, 1.0),
      tileBlur: 10 * (1 - tile).clamp(0.0, 1.0),
      haloOuter: 0.7 + 0.3 * seg(0, 1000, _outExpo),
      haloInner: 0.7 + 0.3 * seg(80, 1000, _outExpo),
      mark: OmniBrandFrame(
        ring: seg(120, 620, OmniSplash.flightCurve),
        tail: seg(380, 500, OmniSplash.flightCurve),
        backArc: seg(520, 600, OmniSplash.flightCurve),
        frontArc: seg(620, 600, OmniSplash.flightCurve),
        // Chấm vàng: 620 → 1420ms, quay từ −220° về chỗ nghỉ.
        dotTurn: -220 * (1 - seg(620, 800, _outExpo)),
        dotScale: math.max(0, dotScale),
        dotOpacity: dotOpacity,
      ),
      glowOpacity: glowOpacity,
      glowScale: 0.6 + glowT,
      letters: [
        for (var i = 0; i < 6; i++)
          seg(950 + 45.0 * i, 500, _outExpo).clamp(0.0, 1.0),
      ],
      tag: seg(1250, 500, _outExpo).clamp(0.0, 1.0),
    );
  }

  /// `cubic-bezier(.16,1,.3,1)` — ra nhanh, đáp êm.
  static const _outExpo = Cubic(0.16, 1, 0.3, 1);

  final double tileScale;
  final double tileOpacity;
  final double tileBlur;
  final double haloOuter;
  final double haloInner;
  final OmniBrandFrame mark;
  final double glowOpacity;
  final double glowScale;
  final List<double> letters;
  final double tag;
}
