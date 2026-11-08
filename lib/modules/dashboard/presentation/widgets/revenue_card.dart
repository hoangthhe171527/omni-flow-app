/// Thẻ doanh thu Tổng quan: chọn Tuần/Tháng/Năm, số lớn cộng dồn, chênh lệch
/// so với cùng kỳ, biểu đồ kéo xem từng ngày, vạch trục và chú giải.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omni_app/design/components/omni_group.dart';
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
    // Một thể hiện chuỗi duy nhất: lấy thẳng từ provider, không dựng lại.
    final s = async.valueOrNull;
    final Widget body;
    // Lỗi xét trước: AsyncError giữ giá trị cũ, nếu không thì đổi kỳ thất bại
    // sẽ hiện số của kỳ trước mà không có nút thử lại.
    if (async.hasError && !async.isLoading) {
      body = _Shell(
        child: OmniErrorView(
          error: async.error!,
          onRetry: () => ref.invalidate(revenueSeriesProvider),
        ),
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
      body = _Shell(
        child: OmniErrorView(
          error: async.error!,
          onRetry: () => ref.invalidate(revenueSeriesProvider),
        ),
      );
    } else {
      body = const _Shell(child: _Skeleton());
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: OmniGroupSection.gap),
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
          const SizedBox(height: OmniGroupSection.gap),
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

    final String caption, big;
    // Số phụ là dòng "nhãn — số" trong nhóm, đủ chữ số.
    final rows = <(String, String)>[];
    if (i == null) {
      final (caption0, endLabel) = switch (s.range) {
        RevenueRange.week => ('Doanh thu tuần này', 'Dự kiến cuối tuần'),
        RevenueRange.month => ('Doanh thu tháng này', 'Dự kiến cuối tháng'),
        RevenueRange.year => ('Doanh thu năm nay', 'Dự kiến cuối năm'),
      };
      caption = caption0;
      big = formatFullVnd(s.headline);
      final k = s.cumCurrent.length - 1;
      final pv = s.cumPrevious.isEmpty
          ? null
          : s.cumPrevious[math.min(math.max(k, 0), s.cumPrevious.length - 1)];
      rows.add((
        'Cùng kỳ trước',
        pv == null ? 'Chưa có số' : formatFullVnd(pv),
      ));
      rows.add((endLabel, formatFullVnd(s.projectedEnd)));
      final target = s.targetRatio;
      if (target != null) {
        rows.add(('Đạt mục tiêu', '${(target * 100).round()}%'));
      }
    } else {
      caption = revenueSlotLabel(s.range, i);
      final v = s.valueAt(i);
      big = v == null ? 'Chưa tới' : formatFullVnd(v);
      final p = s.previousAt(i);
      rows.add(('Kỳ trước', p == null ? '—' : formatFullVnd(p)));
    }

    return OmniGroupSection(
      dividerIndent: 14,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Column(
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
                      style: OmniType.moneyHero.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  if (i == null) ...[
                    const SizedBox(width: 8),
                    _Delta(ratio: s.deltaRatio),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              RevenueChart(
                series: s,
                scrubIndex: i,
                onScrub: (v) {
                  if (v != _scrub) setState(() => _scrub = v);
                },
                ringColor: scheme.surface,
              ),
              const SizedBox(height: 4),
              _Ticks(range: s.range, slots: n, color: muted),
            ],
          ),
        ),
        for (final (label, value) in rows)
          OmniGroupRow(title: label, value: value),
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
        borderRadius: BorderRadius.circular(999),
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

/// Thẻ trắng bo 18 cho trạng thái tải / lỗi (cùng dáng nhóm lồng).
class _Shell extends StatelessWidget {
  const _Shell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(18),
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );
}
