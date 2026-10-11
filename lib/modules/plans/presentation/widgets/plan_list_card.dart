import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../design/components/components.dart';
import '../../application/plans_providers.dart';
import '../../data/plans_api.dart';
import '../../plans_module.dart';
import 'plan_row.dart';

/// Một team: tiêu đề hoa + số người + (⋯), rồi MỘT thẻ bo 8 chứa các dòng dự án
/// ngăn bằng vạch (`Tasks.dc.html`, nửa `isPlans`).
class PlanListCard extends StatelessWidget {
  const PlanListCard({super.key, required this.group, required this.canDelete});

  final TeamWithPlans group;
  final bool canDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final showMore = canDelete && !group.synthetic && group.team.id.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hàng tiêu đề cao ≥ 44 khi có nút ⋯, để vùng chạm của nút không đẩy
        // tiêu đề lệch so với các team không có nó.
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: showMore ? 44 : 24),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  group.team.name.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (group.team.memberCount > 0)
                Text(
                  '${group.team.memberCount} người',
                  style: text.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              if (showMore)
                PopupMenuButton<_TeamAction>(
                  tooltip: 'Tuỳ chọn team',
                  onSelected: (action) {
                    if (action == _TeamAction.delete) _deleteTeam(context);
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: _TeamAction.delete,
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: scheme.error),
                          const SizedBox(width: 8),
                          Text(
                            'Xoá team',
                            style: TextStyle(color: scheme.error),
                          ),
                        ],
                      ),
                    ),
                  ],
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      Icons.more_horiz_rounded,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if ((group.team.description ?? '').isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            group.team.description!,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 6),
        if (group.plans.isEmpty)
          // Nói rõ là rỗng. Một khối tiêu đề không có gì bên dưới đọc như một
          // lỗi tải, và người dùng sẽ kéo để tải lại mãi.
          CustomPaint(
            painter: _DashedBorder(color: scheme.outlineVariant),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              child: Text(
                'Team này chưa có dự án nào.',
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(7)),
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  children: [
                    for (var i = 0; i < group.plans.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: scheme.surfaceContainerHighest,
                        ),
                      PlanRow(
                        plan: group.plans[i],
                        onTap: () => context.pushNamed(
                          PlansModule.board,
                          pathParameters: {'id': group.plans[i].id},
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _deleteTeam(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    // Bắt trước `await`: sau hộp thoại xác nhận, widget này có thể đã rời cây
    // (realtime dựng lại danh sách), và `ref` của nó khi đó không còn dùng được.
    final container = ProviderScope.containerOf(context);
    if (group.plans.isNotEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Team còn ${group.plans.length} dự án. Hãy chuyển các dự án sang team khác trước.',
          ),
        ),
      );
      return;
    }

    final confirmed = await showOmniConfirm(
      context: context,
      title: 'Xoá team “${group.team.name}”?',
      message:
          'Team sẽ biến mất trên cả điện thoại và web. Hành động này không thể hoàn tác.',
      confirmLabel: 'Xoá team',
      destructive: true,
    );
    if (!confirmed) return;

    try {
      await container.read(plansApiProvider).deleteTeam(group.team.id);
      container.invalidate(teamsWithPlansProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Đã xoá team.')));
    } on AppException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

enum _TeamAction { delete }

/// Viền đứt bo 8 cho khối "chưa có dự án" — Flutter không có sẵn viền đứt.
class _DashedBorder extends CustomPainter {
  _DashedBorder({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(0.75),
          const Radius.circular(8),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 8) {
        canvas.drawPath(metric.extractPath(d, d + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder oldDelegate) => oldDelegate.color != color;
}
