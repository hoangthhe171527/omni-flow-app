import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../design/components/components.dart';
import '../../../../design/platform/omni_motion_scope.dart';
import '../../../../design/tokens/tokens.dart';
import '../../domain/customer_activity.dart';

/// Dòng thời gian hoạt động của khách trong một nhóm lồng [OmniGroupSection]
/// bo 18, [OmniIconTile] 28×28 một tông trung tính và vạch chia lùi 54px.
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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: OmniGroupSection(
        dividerIndent: 54,
        children: [
          for (var i = 0; i < items.length; i++)
            _Rise(
              index: i,
              child: _ActivityTile(activity: items[i]),
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
    // Bậc hiệu năng thấp: hiện ngay (mỗi mục hiện dần = một lớp vẽ mờ).
    if (!OmniMotion.enabled(context) ||
        !OmniPerformance.riseOnScroll(context)) {
      return child;
    }
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
  const _ActivityTile({required this.activity});

  final CustomerActivity activity;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final when = Formatters.relative(activity.at);

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OmniIconTile(_icon(activity.kind)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
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
          ],
        ),
      ),
    );
  }

  static IconData _icon(ActivityKind kind) => switch (kind) {
    ActivityKind.message => Icons.chat_bubble_outline_rounded,
    ActivityKind.call => Icons.call_outlined,
    ActivityKind.order => Icons.receipt_long_outlined,
    ActivityKind.task => Icons.task_alt_rounded,
    ActivityKind.note => Icons.sticky_note_2_outlined,
    ActivityKind.other => Icons.more_horiz_rounded,
  };
}
