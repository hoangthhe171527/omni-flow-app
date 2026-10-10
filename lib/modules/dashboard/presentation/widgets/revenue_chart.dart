/// Biểu đồ doanh thu cộng dồn: kỳ này (nét liền + nền), kỳ trước (đứt 4,4),
/// dự kiến (chấm 1.5,3), vạch chỉ tiêu cam khi có; kéo ngang để xem từng ngày.
library;

import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:omni_app/design/platform/omni_motion_scope.dart';
import 'package:omni_app/design/tokens/omni_colors.dart';
import 'package:omni_app/design/tokens/omni_motion.dart';
import 'package:omni_app/design/tokens/omni_typography.dart';

import '../../domain/revenue_period.dart';
import '../../domain/revenue_series.dart';

class RevenueChart extends StatefulWidget {
  const RevenueChart({
    super.key,
    required this.series,
    required this.onScrub,
    this.scrubIndex,
  });

  static const double height = 112;

  final RevenueSeries series;
  final ValueChanged<int?> onScrub;
  final int? scrubIndex;

  @override
  State<RevenueChart> createState() => _RevenueChartState();
}

class _RevenueChartState extends State<RevenueChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _draw = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  late final Animation<double> _progress = CurvedAnimation(
    parent: _draw,
    curve: OmniCurves.standard,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _run();
    } else if (!OmniMotion.enabled(context)) {
      _draw.value = 1;
    }
  }

  @override
  void didUpdateWidget(RevenueChart old) {
    super.didUpdateWidget(old);
    if (!identical(old.series, widget.series)) _run();
  }

  void _run() {
    if (OmniMotion.enabled(context)) {
      _draw.forward(from: 0);
    } else {
      _draw.value = 1;
    }
  }

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  int get _n => math.max(1, widget.series.slots);

  int _indexAt(double x, double w) {
    if (_n == 1 || w <= 0) return 0;
    return ((x / w).clamp(0.0, 1.0) * (_n - 1)).round();
  }

  void _step(int delta) {
    final k = widget.series.cumCurrent.length - 1;
    final from = widget.scrubIndex ?? math.max(0, k);
    widget.onScrub((from + delta).clamp(0, _n - 1));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.series;
    final scheme = Theme.of(context).colorScheme;
    final i = widget.scrubIndex;
    return Semantics(
      container: true,
      label: s.summary(),
      // Có value thì Flutter đòi cả increasedValue/decreasedValue.
      value: i == null ? null : _tipLine(s, i),
      increasedValue: i == null ? null : _tipLine(s, math.min(_n - 1, i + 1)),
      decreasedValue: i == null ? null : _tipLine(s, math.max(0, i - 1)),
      onIncrease: () => _step(1),
      onDecrease: () => _step(-1),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => widget.onScrub(_indexAt(d.localPosition.dx, w)),
            onHorizontalDragStart: (d) =>
                widget.onScrub(_indexAt(d.localPosition.dx, w)),
            onHorizontalDragUpdate: (d) =>
                widget.onScrub(_indexAt(d.localPosition.dx, w)),
            onHorizontalDragEnd: (_) => widget.onScrub(null),
            onHorizontalDragCancel: () => widget.onScrub(null),
            child: SizedBox(
              width: w,
              height: RevenueChart.height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _progress,
                      builder: (context, _) => CustomPaint(
                        painter: RevenueChartPainter(
                          series: s,
                          progress: _draw.isCompleted ? 1.0 : _progress.value,
                          scrubIndex: i,
                          lineColor: scheme.primary,
                          prevColor: OmniColors.mutedBarOf(context),
                          targetColor: OmniColors.byBrightness(
                            context,
                            OmniColors.warning,
                            OmniColors.warningTextDark,
                          ),
                          guideColor: scheme.onSurface.withValues(alpha: .25),
                          surfaceColor: scheme.surface,
                        ),
                      ),
                    ),
                  ),
                  if (i != null) _tooltip(context, s, i, w),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _tooltip(BuildContext context, RevenueSeries s, int i, double w) {
    final x = _n == 1 ? 0.0 : i / (_n - 1) * w;
    const tipW = 132.0;
    final left = (x - tipW / 2).clamp(0.0, math.max(0.0, w - tipW)).toDouble();
    final ink = Theme.of(context).colorScheme.inverseSurface;
    final onInk = Theme.of(context).colorScheme.onInverseSurface;
    final prev = s.previousAt(i);
    return Positioned(
      left: left,
      top: 0,
      width: tipW,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: ink,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _tipLine(s, i),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OmniType.micro.copyWith(
                    color: onInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Kỳ trước ${prev == null ? '—' : formatCompactVnd(prev)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OmniType.micro.copyWith(
                    color: onInk.withValues(alpha: .75),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _slotLabel(RevenueRange r, int i) => switch (r) {
  RevenueRange.week => const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'][i % 7],
  RevenueRange.month => 'Ngày ${i + 1}',
  RevenueRange.year => 'T${i + 1}',
};

String _tipLine(RevenueSeries s, int i) {
  final v = s.valueAt(i);
  return '${v == null ? 'Chưa tới' : formatCompactVnd(v)} · '
      '${_slotLabel(s.range, i)}';
}

class RevenueChartPainter extends CustomPainter {
  RevenueChartPainter({
    required this.series,
    required this.progress,
    required this.scrubIndex,
    required this.lineColor,
    required this.prevColor,
    required this.targetColor,
    required this.guideColor,
    required this.surfaceColor,
  });

  final RevenueSeries series;
  final double progress;
  final int? scrubIndex;
  final Color lineColor, prevColor, targetColor, guideColor, surfaceColor;

  bool get showTarget => series.target != null;

  @override
  void paint(Canvas canvas, Size size) {
    final cur = series.cumCurrent, prev = series.cumPrevious;
    if (cur.isEmpty && prev.isEmpty) return;
    final n = math.max(1, series.slots);
    final w = size.width, h = size.height;
    final k = cur.length - 1;
    final projEnd = series.projectedEnd;
    // Đúng bản mẫu: trục Y không tính điểm dự kiến (đường dự kiến có thể vượt).
    var max = [series.target ?? 0.0, ...prev, ...cur].fold<double>(0, math.max);
    max = max <= 0 ? 1 : max * 1.08;
    double x(int i) => n == 1 ? 0 : i / (n - 1) * w;
    double y(double v) => h - v / max * h;
    Path poly(List<double> a) {
      final p = Path();
      for (var i = 0; i < a.length; i++) {
        i == 0 ? p.moveTo(x(i), y(a[i])) : p.lineTo(x(i), y(a[i]));
      }
      return p;
    }

    Paint stroke(Color c, double width) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final t = series.target;
    if (t != null) {
      final ty = y(t);
      _dashed(
        canvas,
        Path()
          ..moveTo(0, ty)
          ..lineTo(w, ty),
        stroke(targetColor, 1),
        3,
        3,
      );
    }
    if (prev.length > 1) {
      _dashed(canvas, poly(prev), stroke(prevColor, 1.5), 4, 4);
    }
    if (cur.isNotEmpty) {
      final line = poly(cur);
      if (cur.length > 1) {
        final area = Path.from(line)
          ..lineTo(x(k), h)
          ..lineTo(0, h)
          ..close();
        canvas.drawPath(
          area,
          Paint()..color = lineColor.withValues(alpha: .1 * progress),
        );
        canvas.drawPath(_partial(line, progress), stroke(lineColor, 2));
      }
      if (progress >= 1) {
        if (k < n - 1) {
          _dashed(
            canvas,
            Path()
              ..moveTo(x(k), y(cur[k]))
              ..lineTo(x(n - 1), y(projEnd)),
            stroke(lineColor.withValues(alpha: .7), 1.5),
            1.5,
            3,
          );
        }
        final end = Offset(x(k), y(cur[k]));
        canvas.drawCircle(end, 4, Paint()..color = surfaceColor);
        canvas.drawCircle(end, 3, Paint()..color = lineColor);
      }
    }
    final si = scrubIndex;
    if (si != null && si >= 0 && si < n) {
      final sx = x(si);
      canvas.drawLine(Offset(sx, 0), Offset(sx, h), stroke(guideColor, 1));
      final v = series.valueAt(si) ?? series.previousAt(si) ?? 0;
      final c = Offset(sx, y(v));
      canvas.drawCircle(c, 5, Paint()..color = surfaceColor);
      canvas.drawCircle(c, 5, stroke(lineColor, 2.5));
    }
  }

  static Path _partial(Path p, double t) {
    if (t >= 1) return p;
    final out = Path();
    for (final PathMetric m in p.computeMetrics()) {
      out.addPath(m.extractPath(0, m.length * t), Offset.zero);
    }
    return out;
  }

  static void _dashed(Canvas c, Path p, Paint paint, double on, double off) {
    for (final m in p.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        c.drawPath(m.extractPath(d, math.min(d + on, m.length)), paint);
        d += on + off;
      }
    }
  }

  @override
  bool shouldRepaint(RevenueChartPainter o) =>
      !identical(o.series, series) ||
      o.progress != progress ||
      o.scrubIndex != scrubIndex ||
      o.lineColor != lineColor ||
      o.prevColor != prevColor ||
      o.targetColor != targetColor ||
      o.guideColor != guideColor ||
      o.surfaceColor != surfaceColor;
}
