import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../../tasks/application/tasks_providers.dart';
import '../application/plans_providers.dart';
import '../plans_module.dart';
import 'widgets/plan_row.dart';

/// Team → Kế hoạch, tầng trên của cây công việc.
///
/// Người NHẬN việc mở màn này để xem kế hoạch mình đang thuộc về. Người GIAO
/// việc mở nó để trả lời "cây nào đang ở công đoạn nào, tắc ở đâu" — và chỉ
/// họ mới thấy nút tạo.
class TeamsPage extends ConsumerWidget {
  const TeamsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(teamsWithPlansProvider);
    final isAssigner = ref.watch(taskAccessProvider).isAssigner;

    return Scaffold(
      appBar: AppBar(title: const Text('Teams')),
      floatingActionButton: isAssigner
          ? FloatingActionButton.extended(
              onPressed: () => _comingInNextStep(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tạo mới'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(teamsWithPlansProvider),
        child: OmniAsyncView(
          value: groups,
          onRetry: () => ref.invalidate(teamsWithPlansProvider),
          isEmpty: (list) => list.isEmpty,
          empty: OmniEmptyState(
            icon: Icons.workspaces_outline,
            title: 'Chưa có team nào',
            message: isAssigner
                ? 'Tạo một team để nhóm các kế hoạch của xưởng lại.'
                : 'Khi bạn được thêm vào một kế hoạch, nó sẽ hiện ở đây.',
          ),
          data: (list) => ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              OmniSpacing.lg,
              OmniSpacing.lg,
              OmniSpacing.lg,
              OmniSpacing.bottomSafe,
            ),
            itemCount: list.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: OmniSpacing.section),
            itemBuilder: (context, index) => _TeamBlock(group: list[index]),
          ),
        ),
      ),
    );
  }

  void _comingInNextStep(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tạo team và kế hoạch — đang làm.')),
    );
  }
}

class _TeamBlock extends StatelessWidget {
  const _TeamBlock({required this.group});

  final TeamWithPlans group;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                group.team.name,
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (group.team.memberCount > 0)
              Text(
                '${group.team.memberCount} người',
                style: text.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        if ((group.team.description ?? '').isNotEmpty) ...[
          const SizedBox(height: OmniSpacing.xs),
          Text(
            group.team.description!,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: OmniSpacing.md),
        if (group.plans.isEmpty)
          // Nói rõ là rỗng. Một khối tiêu đề không có gì bên dưới đọc như một
          // lỗi tải, và người dùng sẽ kéo để tải lại mãi.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(OmniSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: OmniRadius.lgAll,
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Text(
              'Team này chưa có kế hoạch nào.',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          )
        else
          for (final plan in group.plans) ...[
            PlanRow(
              plan: plan,
              onTap: () => context.pushNamed(
                PlansModule.board,
                pathParameters: {'id': plan.id},
              ),
            ),
            if (plan != group.plans.last)
              const SizedBox(height: OmniSpacing.sm),
          ],
      ],
    );
  }
}
