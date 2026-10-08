import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens/tokens.dart';
import 'omni_brand.dart';

/// Màn mở app "quỹ đạo" (`Splash.dc.html`): nền mực, vòng tròn vẽ ra, đuôi
/// bong bóng, hai nửa quỹ đạo, chấm vàng quay vào chỗ rồi bật sáng, chữ
/// "Viomni" và câu khẩu hiệu nổi lên.
///
/// [progress] = null là khung hình CUỐI (tĩnh) — màn chờ khôi phục phiên dùng
/// đúng khung này, để khi lớp hiệu ứng mờ đi thì bên dưới là cùng một hình và
/// không có cú giật nào.
class OmniSplash extends StatelessWidget {
  const OmniSplash({super.key, this.progress, this.footer});

  /// Thời điểm trên trục thời gian của hiệu ứng, 0..1 trên [timeline].
  final double? progress;

  /// Thứ đặt ở đáy màn — màn chờ khôi phục phiên đặt một vạch tiến độ ở đây.
  final Widget? footer;

  /// Toàn bộ trục thời gian: nét cuối (chấm vàng bật) kết thúc ở 1600ms, quầng
  /// sáng tắt dần thêm một chút — lớp phủ bắt đầu mờ ở mốc này.
  static const timeline = Duration(milliseconds: 1700);

  static const _tileSize = 148.0;

  static const String tagline = 'Mọi khách hàng, một quỹ đạo';

  @override
  Widget build(BuildContext context) {
    final ms = progress == null
        ? double.infinity
        : progress! * timeline.inMilliseconds;
    final s = _SplashFrame.at(ms);

    // Material chứ không ColoredBox: lớp phủ nằm TRÊN navigator, ngoài mọi
    // Scaffold, và chữ không có Material phía trên thì Flutter gạch chân vàng.
    return Material(
      color: OmniColors.ink,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          // Hai quầng tròn đồng tâm, tâm lệch xuống dưới giữa màn 73dp — đúng
          // vị trí trong khung 390×844 của thiết kế.
          final haloCenter = Offset(w / 2, h / 2 + 73);

          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              _halo(haloCenter, 315, OmniColors.inkHaloOuter),
              _halo(haloCenter, 235, OmniColors.inkHaloInner),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Opacity(
                      opacity: s.tileOpacity,
                      child: Transform.scale(
                        scale: s.tileScale,
                        child: SizedBox.square(
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
                                onInk: true,
                                frame: s.mark,
                                semanticLabel: 'Logo Viomni',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    _Rise(
                      value: s.word,
                      child: const OmniWordmark(fontSize: 34, onInk: true),
                    ),
                    const SizedBox(height: OmniSpacing.sm),
                    _Rise(
                      value: s.tag,
                      child: Text(
                        tagline,
                        style: OmniType.bodyStrong.copyWith(
                          fontWeight: FontWeight.w400,
                          color: OmniColors.inkMutedForeground,
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

/// Mọi giá trị của một khung hình, tính từ mốc thời gian (ms).
///
/// Mỗi mốc và thời lượng dưới đây chép từ `animation-delay` và
/// `animation-duration` của `Splash.dc.html`.
class _SplashFrame {
  const _SplashFrame({
    required this.tileScale,
    required this.tileOpacity,
    required this.mark,
    required this.glowOpacity,
    required this.glowScale,
    required this.word,
    required this.tag,
  });

  factory _SplashFrame.at(double ms) {
    double seg(double start, double duration, [Curve curve = _std]) {
      final t = ((ms - start) / duration).clamp(0.0, 1.0);
      return curve.transform(t);
    }

    // sp-tile: 0 → 420ms, thu nhỏ .86 → 1 và hiện dần.
    final tile = seg(0, 420);

    // sp-pop: 1240 → 1600ms. 0%: 0, 60%: 1.35, 100%: 1 — đường cong nảy áp
    // cho TỪNG đoạn giữa hai mốc, như CSS làm.
    final popT = ((ms - 1240) / 360).clamp(0.0, 1.0);
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

    // sp-glow: 1280 → 2180ms, ease-out. Độ mờ 0 → .55 (giữa) → 0; cỡ .6 → 1.6.
    final glowT = ((ms - 1280) / 900).clamp(0.0, 1.0);
    final glowOpacity = glowT <= 0 || glowT >= 1
        ? 0.0
        : glowT <= 0.5
        ? 0.55 * Curves.easeOut.transform(glowT / 0.5)
        : 0.55 * (1 - Curves.easeOut.transform((glowT - 0.5) / 0.5));

    return _SplashFrame(
      tileScale: 0.86 + 0.14 * tile,
      tileOpacity: tile.clamp(0.0, 1.0),
      mark: OmniBrandFrame(
        ring: seg(120, 620),
        tail: seg(340, 620),
        backArc: seg(520, 620),
        frontArc: seg(600, 620),
        // sp-orbit: 640 → 1400ms, quay từ −200° về chỗ nghỉ.
        dotTurn: -200 * (1 - seg(640, 760)),
        dotScale: math.max(0, dotScale),
        dotOpacity: dotOpacity,
      ),
      glowOpacity: glowOpacity,
      glowScale: 0.6 + glowT,
      word: seg(1000, 480).clamp(0.0, 1.0),
      tag: seg(1150, 480).clamp(0.0, 1.0),
    );
  }

  static const _std = OmniCurves.standard;

  final double tileScale;
  final double tileOpacity;
  final OmniBrandFrame mark;
  final double glowOpacity;
  final double glowScale;
  final double word;
  final double tag;
}
