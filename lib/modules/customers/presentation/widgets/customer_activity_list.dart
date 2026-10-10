import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../design/platform/omni_motion_scope.dart';
import '../../../../design/tokens/tokens.dart';
import '../../domain/customer_activity.dart';

/// Dòng thời gian hoạt động của khách (`CustomerDetail.dc.html` tab Hoạt động):
/// chấm tròn 26 theo loại, vạch nối 2px, nội dung và thời gian tương đối.
/// Mỗi dòng "nổi lên" lệch nhau 50ms; giảm chuyển động thì hiện thẳng.
class CustomerActivityList extends StatelessWidget {
  const CustomerActivityList({super.key, required this.items});

  final List<CustomerActivity> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(OmniSpacing.section),
        child: Center(
          child: Text(
            'Chưa có hoạt động',
            style: OmniType.body.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            _Rise(
              index: i,
              child: _ActivityTile(
                activity: items[i],
                isLast: i == items.length - 1,
              ),
            ),
        ],
      ),
    );
  }
}

class _Rise extends StatelessWidget {
  const _Rise({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!OmniMotion.enabled(context)) return child;
    final step = index.clamp(0, 10);
    final total = 300 + 50 * step;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(50 * step / total, 1, curve: OmniCurves.standard),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.activity, required this.isLast});

  final CustomerActivity activity;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, background, foreground) = _look(activity.kind, scheme);
    final when = Formatters.relative(activity.at);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 26,
            child: Column(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: background,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 14, color: foreground),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: scheme.outlineVariant),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.text.isEmpty ? '—' : activity.text,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: OmniType.body.copyWith(color: scheme.onSurface),
                  ),
                  if (when.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      when,
                      style: OmniType.micro.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static (IconData, Color, Color) _look(ActivityKind kind, ColorScheme s) =>
      switch (kind) {
        ActivityKind.message => (
          Icons.chat_bubble_outline_rounded,
          s.primaryContainer,
          s.onPrimaryContainer,
        ),
        ActivityKind.call => (
          Icons.call_outlined,
          s.tertiaryContainer,
          s.onTertiaryContainer,
        ),
        ActivityKind.order => (
          Icons.receipt_long_outlined,
          s.errorContainer,
          s.onErrorContainer,
        ),
        ActivityKind.task => (
          Icons.task_alt_rounded,
          s.surfaceContainerHighest,
          s.onSurfaceVariant,
        ),
        ActivityKind.note => (
          Icons.sticky_note_2_outlined,
          s.surfaceContainerHighest,
          s.onSurfaceVariant,
        ),
        ActivityKind.other => (
          Icons.more_horiz_rounded,
          s.surfaceContainerHighest,
          s.onSurfaceVariant,
        ),
      };
}
