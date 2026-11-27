import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../tokens/tokens.dart';
import 'omni_brand.dart';
import 'omni_orbit.dart';

/// Màn mở app — hướng "Quỹ đạo" (duyệt 26/11/2026): ba vòng elip tự vẽ ra
/// (~1,1 giây, lệch nhau 0,18 giây), chữ V xoay vào giữa có nảy, chữ "Viomni"
/// hiện từng chữ ("Vi" trắng, "omni" xanh), rồi khẩu hiệu "Mọi khách hàng,
/// một quỹ đạo" mờ dần vào; sao chổi chạy dọc vòng ngoài suốt hiệu ứng.
///
/// Khung đầu trùng màn khởi động của hệ điều hành: logo trần 96 đứng giữa màn
/// (không loé) — logo thu lại rồi mới xoay vào theo bản duyệt.
///
/// [progress] = null là khung TĨNH của màn chờ khôi phục phiên: vòng đủ + logo,
/// không chữ; [pulse] (0..1, lặp) là pha sao chổi — nói "đang làm" thay vòng
/// quay.
class OmniSplash extends StatelessWidget {
  const OmniSplash({super.key, this.progress, this.pulse, this.flight});

  /// Thời điểm trên trục thời gian, tính theo đơn vị [timeline]: 0..1 là phần
  /// dựng hình; lớn hơn 1 khi đang bay.
  final double? progress;

  /// Pha sao chổi ở màn chờ (0..1, lặp một vòng). Null = sao chổi đứng yên.
  final double? pulse;

  /// Pha bay logo về chỗ của nó trên màn đích (xem `LaunchSplash`).
  final SplashFlight? flight;

  /// Phần dựng hình: vòng vẽ, logo vào, chữ, khẩu hiệu — xong ở 2,1 giây.
  static const timeline = Duration(milliseconds: 2100);

  /// `cubic-bezier(.32,.72,0,1)` — pha bay: rời chỗ nhanh, đáp êm.
  static const Curve flightCurve = Cubic(0.32, 0.72, 0, 1);

  /// Cạnh logo trần giữa màn — đúng cỡ logo trên màn khởi động hệ điều hành
  /// và bằng [OmniOrbit.logoSize] để vòng quỹ đạo khớp tỉ lệ khi bay.
  static const double logoSize = OmniOrbit.logoSize;

  /// Khẩu hiệu dưới chữ "Viomni".
  static const tagline = 'Mọi khách hàng, một quỹ đạo';

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final s = progress == null
        ? _SplashFrame.still
        : _SplashFrame.at(progress! * timeline.inMilliseconds);
    final fly = flight?.t ?? 0;
    // Đồng hồ của sao chổi (giây).
    final seconds = progress != null
        ? progress! * timeline.inMilliseconds / 1000
        : (pulse ?? 0) * OmniOrbit.cometPeriod;

    Widget word = _LetterWordmark(letters: s.letters, dark: dark);
    // Bay mà đích không có chữ (màn đăng nhập): chữ mờ và trượt lên 24.
    if (flight != null && flight!.wordTarget == null) {
      word = Opacity(
        opacity: 1 - fly,
        child: Transform.translate(offset: Offset(0, -24 * fly), child: word),
      );
    }

    final background = dark ? OmniColors.darkBackground : OmniColors.background;
    final scheme = Theme.of(context).colorScheme;

    // Material chứ không ColoredBox: lớp phủ nằm TRÊN navigator, ngoài mọi
    // Scaffold, và chữ không có Material phía trên thì Flutter gạch chân vàng.
    return Material(
      color: background.withValues(alpha: 1 - fly),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final h = size.height;
          final mid = size.center(Offset.zero);
          // Khi bay, hệ vòng đi theo logo: tâm và tỉ lệ nội suy về logo đích
          // (lớp phủ phủ toàn màn từ gốc, toạ độ màn hình dùng thẳng được).
          final target = flight?.logoTarget;
          final ringCenter = target == null
              ? mid
              : Offset.lerp(mid, target.center, fly)!;
          final ringScale = target == null
              ? 1.0
              : 1 + (target.shortestSide / logoSize - 1) * fly;

          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: OmniOrbitPainter(
                    clock: AlwaysStoppedAnimation<double>(seconds),
                    colors: OmniOrbitColors.of(context),
                    center: ringCenter,
                    scale: ringScale,
                    rings: s.rings,
                    comet: s.comet,
                    // Vòng mờ đi khi bay: màn đăng nhập có sẵn vòng của nó
                    // đúng chỗ đó — hai lớp chéo mờ, không có cú cắt.
                    opacity: 1 - fly,
                    glow: 1 - fly,
                  ),
                ),
              ),
              // Logo đúng giữa màn như màn khởi động hệ điều hành.
              Center(
                child: _FlyTo(
                  target: flight?.logoTarget,
                  t: fly,
                  child: KeyedSubtree(
                    key: const ValueKey('splash-logo'),
                    child: Transform.rotate(
                      angle: s.logoAngle,
                      child: Transform.scale(
                        scale: s.logoScale,
                        child: const OmniBrandMark(
                          size: logoSize,
                          framed: false,
                          semanticLabel: 'Logo Viomni',
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: h / 2 + 110,
                child: Center(
                  child: _FlyTo(
                    target: flight?.wordTarget,
                    t: fly,
                    child: word,
                  ),
                ),
              ),
              if (s.tagline > 0)
                Positioned(
                  left: 24,
                  right: 24,
                  top: h / 2 + 168,
                  child: Opacity(
                    opacity: (s.tagline * (1 - fly)).clamp(0.0, 1.0),
                    child: Text(
                      tagline,
                      textAlign: TextAlign.center,
                      style: OmniType.body.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
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

/// "Viomni" cỡ 40/800, mỗi ký tự nảy lên riêng: trượt lên 14dp và hiện dần.
/// Nền tối: "Vi" trắng, "omni" xanh [OmniOrbitColors.word]; nền sáng: mực /
/// màu chính.
class _LetterWordmark extends StatelessWidget {
  const _LetterWordmark({required this.letters, required this.dark});

  static const _text = 'Viomni';

  final List<double> letters;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    if (letters.every((v) => v <= 0)) return const SizedBox.shrink();
    return Semantics(
      label: _text,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _text.length; i++)
            Opacity(
              opacity: letters[i].clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, 14 * (1 - letters[i])),
                child: Text(
                  _text[i],
                  style: OmniOrbitType.wordmark.copyWith(
                    color: i < 2
                        ? (dark ? Colors.white : OmniColors.ink)
                        : (dark ? OmniOrbitColors.word : OmniColors.primary),
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

/// Mọi giá trị của một khung hình, tính từ mốc thời gian (ms). Mốc theo bản
/// duyệt "Quỹ đạo" (dựng hình 2,1 giây, bay từ 2,1 giây).
class _SplashFrame {
  const _SplashFrame({
    required this.rings,
    required this.comet,
    required this.logoScale,
    required this.logoAngle,
    required this.letters,
    required this.tagline,
  });

  /// Khung tĩnh của màn chờ: vòng đủ, logo đúng chỗ, không chữ.
  static const still = _SplashFrame(
    rings: [1, 1, 1],
    comet: 1,
    logoScale: 1,
    logoAngle: 0,
    letters: [0, 0, 0, 0, 0, 0],
    tagline: 0,
  );

  factory _SplashFrame.at(double ms) {
    double seg(double start, double duration, Curve curve) {
      final t = ((ms - start) / duration).clamp(0.0, 1.0);
      return curve.transform(t);
    }

    final seconds = ms / 1000;
    final rings = [
      for (var i = 0; i < 3; i++) OmniOrbit.drawProgress(i, seconds),
    ];

    // Logo: khung đầu đủ cỡ như màn khởi động hệ điều hành, thu về .55 và
    // nghiêng −12° (0 → 450ms), rồi xoay vào có nảy (550 → 1550ms).
    final double scale;
    final double angle;
    if (ms < 550) {
      final w = seg(0, 450, Curves.easeInCubic);
      scale = 1 - 0.45 * w;
      angle = -12 * math.pi / 180 * w;
    } else {
      final v = OmniOrbit.logoIn((ms - 550) / 1000);
      scale = v.scale;
      angle = v.angle;
    }

    return _SplashFrame(
      rings: rings,
      comet: rings[0],
      logoScale: scale,
      logoAngle: angle,
      letters: [
        for (var i = 0; i < 6; i++) seg(1050 + 60.0 * i, 500, OmniOrbit.bounce),
      ],
      tagline: seg(1500, 600, Curves.easeOut),
    );
  }

  final List<double> rings;
  final double comet;
  final double logoScale;
  final double logoAngle;
  final List<double> letters;
  final double tagline;
}
