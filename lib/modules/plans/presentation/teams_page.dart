import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../../../security/session/session_controller.dart';
import '../../tasks/application/tasks_providers.dart';
import '../application/plans_providers.dart';
import '../plans_module.dart';
import 'create_plan_page.dart';
import 'create_team_page.dart';
import 'widgets/plan_row.dart';

/// Team → Dự án, tầng trên của cây công việc.
///
/// Người NHẬN việc mở màn này để xem dự án mình đang thuộc về. Người GIAO
/// việc mở nó để trả lời "cây nào đang ở công đoạn nào, tắc ở đâu" — và chỉ
/// họ mới thấy nút tạo.
class TeamsPage extends ConsumerWidget {
  const TeamsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(teamsWithPlansProvider);
    final isAssigner = ref.watch(taskAccessProvider).isAssigner;
    // Cùng quyền mà API đòi ở đường ghi `/teams` — xem `Interfaces/routes.php`.
    final canCreateTeam = ref
        .watch(accessProvider)
        .can('organization.org_units.create');

    return Scaffold(
      appBar: const OmniAppBar(title: 'Dự án'),
      floatingActionButton: isAssigner
          ? FloatingActionButton.extended(
              onPressed: () => _create(context, canCreateTeam: canCreateTeam),
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
                ? 'Tạo một team để nhóm các dự án lại.'
                : 'Khi bạn được thêm vào một dự án, nó sẽ hiện ở đây.',
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

  /// Một nút, hai thứ tạo được — đúng như myXteam.
  ///
  /// Hỏi trước bằng một sheet thay vì hai nút nổi: hai FAB trên một màn buộc
  /// người dùng đọc cả hai nhãn trước mỗi lần bấm, còn một nút thì họ chỉ đọc
  /// khi thật sự cần chọn.
  Future<void> _create(
    BuildContext context, {
    required bool canCreateTeam,
  }) async {
    final choice = await showOmniSheet<_CreateChoice>(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tạo team giờ LÀ tạo một đơn vị trong cơ cấu tổ chức — cùng thứ
          // web tạo, và cùng thứ `Membership` gắn người vào. API đòi quyền
          // org tương ứng; vai `manager` có sẵn, nhưng một vai tự cấu hình
          // thì chưa chắc. Bày ra một dòng bấm vào là 403 tệ hơn không bày.
          if (canCreateTeam)
            ListTile(
              minTileHeight: 56,
              leading: const Icon(Icons.workspaces_outline),
              title: const Text('Tạo team'),
              subtitle: const Text('Một nhóm người, chứa nhiều dự án'),
              onTap: () => Navigator.of(context).pop(_CreateChoice.team),
            ),
          ListTile(
            minTileHeight: 56,
            leading: const Icon(Icons.assignment_outlined),
            title: const Text('Tạo dự án'),
            subtitle: const Text('Các nhóm việc và công việc trong đó'),
            onTap: () => Navigator.of(context).pop(_CreateChoice.plan),
          ),
          const SizedBox(height: OmniSpacing.sm),
        ],
      ),
    );

    if (choice == null || !context.mounted) return;

    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => switch (choice) {
          _CreateChoice.team => const CreateTeamPage(),
          _CreateChoice.plan => const CreatePlanPage(),
        },
      ),
    );
  }
}

enum _CreateChoice { team, plan }

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
              'Team này chưa có dự án nào.',
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
