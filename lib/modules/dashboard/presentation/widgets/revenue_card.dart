/// Thẻ doanh thu Tổng quan: chọn Tuần/Tháng/Năm, số lớn cộng dồn, chênh lệch
/// so với cùng kỳ, biểu đồ kéo xem từng ngày, vạch trục và chú giải.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omni_app/design/components/omni_card.dart';
import 'package:omni_app/design/components/omni_segmented.dart';
import 'package:omni_app/design/components/omni_states.dart';
import 'package:omni_app/design/platform/omni_motion_scope.dart';
import 'package:omni_app/design/tokens/omni_colors.dart';
import 'package:omni_app/design/tokens/omni_motion.dart';
import 'package:omni_app/design/tokens/omni_typography.dart';

import '../../application/dashboard_providers.dart';
import '../../domain/revenue_period.dart';
import '../../domain/revenue_series.dart';
import 'revenue_chart.dart';

class RevenueCard extends ConsumerStatefulWidget {
  const RevenueCard({super.key});

  @override
  ConsumerState<RevenueCard> createState() => _RevenueCardState();
}

class _RevenueCardState extends ConsumerState<RevenueCard> {
  int? _scrub;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(revenueSeriesProvider);
    final range = ref.watch(revenueRangeProvider);
    // Không có nguồn (thiếu quyền / module tắt) → thẻ biến mất hẳn.
    if (async.hasValue && async.value == null && !async.isLoading) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    // Một thể hiện chuỗi duy nhất: lấy thẳng từ provider, không dựng lại.
    final s = async.valueOrNull;
    final Widget body;
    // Lỗi xét trước: AsyncError giữ giá trị cũ, nếu không thì đổi kỳ thất bại
    // sẽ hiện số của kỳ trước mà không có nút thử lại.
    if (async.hasError && !async.isLoading) {
      body = OmniErrorView(
        error: async.error!,
        onRetry: () => ref.invalidate(revenueSeriesProvider),
      );
    } else if (s != null) {
      // Đang tải kỳ mới → số cũ mờ đi cho tới khi có số đúng kỳ.
      final stale = s.range != range;
      body = AnimatedOpacity(
        key: const ValueKey('revenue-stale'),
        opacity: stale ? .4 : 1,
        duration: OmniMotion.enabled(context)
            ? OmniDuration.fast
            : Duration.zero,
        child: IgnorePointer(ignoring: stale, child: _content(context, s)),
      );
    } else if (async.hasError) {
      body = OmniErrorView(
        error: async.error!,
        onRetry: () => ref.invalidate(revenueSeriesProvider),
      );
    } else {
      body = const _Skeleton();
    }
    return OmniCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      background: scheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OmniSegmented(
            labels: [for (final r in RevenueRange.values) r.label],
            index: range.index,
            onChanged: (i) {
              setState(() => _scrub = null);
              ref.read(revenueRangeProvider.notifier).state =
                  RevenueRange.values[i];
            },
          ),
          const SizedBox(height: 12),
          body,
        ],
      ),
    );
  }

  Widget _content(BuildContext context, RevenueSeries s) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final n = math.max(1, s.slots);
    final i = _scrub?.clamp(0, n - 1);

    final String caption, big, sub;
    if (i == null) {
      caption = switch (s.range) {
        RevenueRange.week => 'Doanh thu tuần này',
        RevenueRange.month => 'Doanh thu tháng này',
        RevenueRange.year => 'Doanh thu năm nay',
      };
      big = formatCompactVnd(s.headline);
      final k = s.cumCurrent.length - 1;
      final pv = s.cumPrevious.isEmpty
          ? null
          : s.cumPrevious[math.min(math.max(k, 0), s.cumPrevious.length - 1)];
      sub =
          '${pv == null ? 'Chưa có số cùng kỳ' : 'So với cùng kỳ ${formatCompactVnd(pv)}'}'
          ' · dự kiến ${formatCompactVnd(s.projectedEnd)}';
    } else {
      caption = revenueSlotLabel(s.range, i);
      final v = s.valueAt(i);
      big = v == null ? 'Chưa tới' : formatCompactVnd(v);
      final p = s.previousAt(i);
      sub = 'Kỳ trước: ${p == null ? '—' : formatCompactVnd(p)}';
    }

    final target = s.targetRatio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(caption, style: OmniType.micro.copyWith(color: muted)),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                big,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: OmniType.moneyHero.copyWith(color: scheme.onSurface),
              ),
            ),
            if (i == null) ...[
              const SizedBox(width: 8),
              _Delta(ratio: s.deltaRatio),
            ],
          ],
        ),
        Text(sub, maxLines: 2, style: OmniType.micro.copyWith(color: muted)),
        const SizedBox(height: 8),
        RevenueChart(
          series: s,
          scrubIndex: i,
          onScrub: (v) => setState(() => _scrub = v),
          ringColor: scheme.surface,
        ),
        const SizedBox(height: 4),
        _Ticks(range: s.range, slots: n, color: muted),
        const SizedBox(height: 8),
        Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
        const SizedBox(height: 8),
        ExcludeSemantics(
          child: Row(
            children: [
              _LegendSample(color: scheme.primary, dashed: false),
              const SizedBox(width: 5),
              Text('Kỳ này', style: OmniType.micro.copyWith(color: muted)),
              const SizedBox(width: 14),
              _LegendSample(
                color: OmniColors.mutedBarOf(context),
                dashed: true,
              ),
              const SizedBox(width: 5),
              Text('Kỳ trước', style: OmniType.micro.copyWith(color: muted)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  target == null ? '' : '${(target * 100).round()}% mục tiêu',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: OmniType.micro.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Delta extends StatelessWidget {
  const _Delta({required this.ratio});

  final double? ratio;

  @override
  Widget build(BuildContext context) {
    final r = ratio;
    final scheme = Theme.of(context).colorScheme;
    final Color color;
    final String text;
    IconData? icon;
    String? label;
    if (r == null) {
      color = scheme.onSurfaceVariant;
      text = '—';
    } else {
      final up = r >= 0;
      color = up
          ? OmniColors.byBrightness(
              context,
              OmniColors.primaryPressed,
              scheme.primary,
            )
          : OmniColors.dangerTextOf(context);
      icon = up ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded;
      text = '${(r.abs() * 100).round()}%';
      label = '${up ? 'tăng' : 'giảm'} $text so với cùng kỳ';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(4),
      ),
      // Font app không có ▲/▼ (font_glyph_coverage_test) → dùng icon.
      child: Semantics(
        label: label,
        excludeSemantics: label != null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) Icon(icon, size: 18, color: color),
            Text(
              text,
              style: OmniType.micro.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vạch trục dưới biểu đồ, đặt đúng vị trí ô (biểu đồ không tự vẽ chữ).
class _Ticks extends StatelessWidget {
  const _Ticks({required this.range, required this.slots, required this.color});

  final RevenueRange range;
  final int slots;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ticks = <(int, String)>[
      ...switch (range) {
        RevenueRange.week => const [(0, 'T2'), (2, 'T4'), (4, 'T6'), (6, 'CN')],
        RevenueRange.month => [
          (0, '1'),
          (9, '10'),
          (19, '20'),
          (slots - 1, '$slots'),
        ],
        RevenueRange.year => const [
          (0, 'T1'),
          (3, 'T4'),
          (7, 'T8'),
          (11, 'T12'),
        ],
      },
    ].where((t) => t.$1 < slots).toList();
    final style = OmniType.micro.copyWith(color: color);
    return ExcludeSemantics(
      child: SizedBox(
        height: 18,
        child: Stack(
          children: [
            for (final (i, label) in ticks)
              Align(
                alignment: Alignment(
                  slots <= 1 ? -1 : -1 + 2 * i / (slots - 1),
                  0,
                ),
                child: Text(label, style: style),
              ),
          ],
        ),
      ),
    );
  }
}

class _LegendSample extends StatelessWidget {
  const _LegendSample({required this.color, required this.dashed});

  final Color color;
  final bool dashed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 12,
    height: 3,
    child: CustomPaint(painter: _SamplePainter(color, dashed)),
  );
}

class _SamplePainter extends CustomPainter {
  _SamplePainter(this.color, this.dashed);

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final p = Paint()
      ..color = color
      ..strokeWidth = dashed ? 1.5 : 2.5
      ..strokeCap = dashed ? StrokeCap.butt : StrokeCap.round;
    if (!dashed) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
      return;
    }
    for (var x = 0.0; x < size.width; x += 6) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + 3, size.width), y), p);
    }
  }

  @override
  bool shouldRepaint(_SamplePainter o) =>
      o.color != color || o.dashed != dashed;
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      OmniSkeletonBox(height: 14, width: 120),
      SizedBox(height: 6),
      OmniSkeletonBox(height: 30, width: 160),
      SizedBox(height: 12),
      OmniSkeletonBox(height: RevenueChart.height),
    ],
  );
}
