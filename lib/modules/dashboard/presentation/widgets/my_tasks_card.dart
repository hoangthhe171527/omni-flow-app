/// Thẻ "Việc của tôi" trên Tổng quan: ≤5 việc hôm nay / quá hạn kèm chip hạn.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/design/tokens/omni_typography.dart';

import '../../../../security/session/session_controller.dart';
import '../../../tasks/domain/task.dart';
import '../../../tasks/domain/task_permissions.dart';
import '../../../tasks/routes.dart';
import '../../../tasks/tasks.dart' show DueChip;
import '../../application/dashboard_providers.dart';
import 'dashboard_card_parts.dart';

class MyTasksCard extends ConsumerWidget {
  const MyTasksCard({super.key});

  static const limit = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Thiếu quyền đọc việc → thẻ không tồn tại (và không gọi mạng), không
    // phải một thẻ báo lỗi 403.
    if (!ref.watch(accessProvider).canAny(TaskPermissions.anyRead)) {
      return const SizedBox.shrink();
    }
    final async = ref.watch(dashboardMyTasksProvider);
    final page = async.valueOrNull;
    final items = page?.items.take(limit).toList() ?? const <Task>[];

    final Widget body;
    if (async.hasError && !async.isLoading) {
      body = DashboardCardError(
        error: async.error!,
        onRetry: () => ref.invalidate(dashboardMyTasksProvider),
      );
    } else if (page == null) {
      body = const DashboardCardSkeleton();
    } else if (items.isEmpty) {
      body = const DashboardEmptyLine('Không có việc hôm nay');
    } else {
      body = Column(
        children: [
          for (final t in items)
            _TaskRow(
              task: t,
              onTap: () => context.pushNamed(
                TaskRoutes.detail,
                pathParameters: {'id': t.id},
              ),
            ),
        ],
      );
    }

    return OmniCollapsibleCard(
      title: 'Việc của tôi',
      count: page?.pagination.total,
      footer: items.isEmpty
          ? null
          : DashboardSeeAll(onPressed: () => context.goNamed(TaskRoutes.list)),
      child: body,
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task, required this.onTap});

  final Task task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OmniType.body.copyWith(color: scheme.onSurface),
                ),
              ),
              const SizedBox(width: 8),
              DueChip(task: task),
            ],
          ),
        ),
      ),
    );
  }
}
