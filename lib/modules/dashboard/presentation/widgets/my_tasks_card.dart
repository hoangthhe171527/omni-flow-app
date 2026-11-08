/// Thẻ "Việc của tôi" trên Tổng quan: ≤5 việc hôm nay / quá hạn kèm chip hạn.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:omni_app/design/components/components.dart';

import '../../../tasks/domain/task.dart';
import '../../../tasks/routes.dart';
import '../../../tasks/tasks.dart' show DueChip;
import '../../application/dashboard_providers.dart';
import 'dashboard_card_parts.dart';

class MyTasksCard extends ConsumerWidget {
  const MyTasksCard({super.key});

  static const limit = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Thiếu quyền đọc việc hoặc cờ `tasks` tắt → thẻ không tồn tại (và không
    // gọi mạng), không phải một thẻ báo lỗi 403.
    if (!ref.watch(dashboardCardsProvider).tasks) {
      return const SizedBox.shrink();
    }
    final async = ref.watch(dashboardMyTasksProvider);
    final page = async.valueOrNull;
    final items = page?.items.take(limit).toList() ?? const <Task>[];

    Widget? placeholder;
    var rows = const <Widget>[];
    if (async.hasError && !async.isLoading) {
      placeholder = DashboardCardError(
        error: async.error!,
        onRetry: () => ref.invalidate(dashboardMyTasksProvider),
      );
    } else if (page == null) {
      placeholder = const DashboardCardSkeleton();
    } else if (items.isEmpty) {
      placeholder = const DashboardEmptyLine('Không có việc hôm nay');
    } else {
      rows = [
        for (final t in items)
          _TaskRow(
            task: t,
            onTap: () => context.pushNamed(
              TaskRoutes.detail,
              pathParameters: {'id': t.id},
            ),
          ),
      ];
    }

    return DashboardGroup(
      title: 'Việc của tôi',
      storageKey: 'dashboard.my-tasks',
      count: page?.pagination.total,
      rows: rows,
      placeholder: placeholder,
      onSeeAll: items.isEmpty ? null : () => context.goNamed(TaskRoutes.list),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task, required this.onTap});

  final Task task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OmniGroupRow(
    title: task.title,
    maxTitleLines: 2,
    trailing: DueChip(task: task),
    chevron: false,
    onTap: onTap,
  );
}
