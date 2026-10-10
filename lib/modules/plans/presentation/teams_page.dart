import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/nav/shell_bar_inset.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../../../security/guard/access_requirement.dart';
import '../../../security/session/session_controller.dart';
import '../../tasks/application/tasks_providers.dart';
import '../../tasks/domain/task_permissions.dart';
import '../application/plans_providers.dart';
import '../plans_module.dart';
import 'create_plan_page.dart';
import 'create_team_page.dart';
import 'widgets/create_choice_sheet.dart';
import 'widgets/plan_list_card.dart';

/// Gốc tab Việc: dự án xếp theo team, và thẻ "Dòng việc" ở cuối
/// (`Tasks.dc.html`, nửa `isPlans`).
///
/// Người NHẬN việc mở màn này để xem dự án mình thuộc về. Người GIAO việc mở
/// nó để trả lời "cây nào đang ở công đoạn nào, tắc ở đâu" — và chỉ họ mới
/// thấy nút +. "Việc của tôi" không còn là tab nhưng vẫn sống trong "Tất cả".
class TeamsPage extends ConsumerStatefulWidget {
  const TeamsPage({super.key});

  @override
  ConsumerState<TeamsPage> createState() => _TeamsPageState();
}

class _TeamsPageState extends ConsumerState<TeamsPage> {
  /// Bật trước khi sheet mở, tắt khi nó trả về: nút + xoay thành × đúng lúc
  /// sheet hiện.
  bool _sheetOpen = false;

  /// Một nút, hai thứ tạo được — đúng như myXteam.
  Future<void> _create({required bool canCreateTeam}) async {
    setState(() => _sheetOpen = true);
    final choice = await showCreateChoiceSheet(
      context,
      canCreateTeam: canCreateTeam,
    );
    if (!mounted) return;
    setState(() => _sheetOpen = false);
    if (choice == null) return;

    // Bắt trước `await`: sau khi trang tạo đóng, widget này có thể đã rời cây.
    final container = ProviderScope.containerOf(context);
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => switch (choice) {
          CreateChoice.team => const CreateTeamPage(),
          CreateChoice.plan => const CreatePlanPage(),
        },
      ),
    );
    container.invalidate(teamsWithPlansProvider);
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(teamsWithPlansProvider);
    final taskAccess = ref.watch(taskAccessProvider);
    final access = ref.watch(accessProvider);
    final isAssigner = taskAccess.isAssigner;
    // Cùng quyền mà API đòi ở đường ghi `/teams` — xem `Interfaces/routes.php`.
    final canCreateTeam = access.can('organization.org_units.create');
    final canDeleteTeam =
        taskAccess.canDelete && access.can('organization.org_units.delete');
    final canOpenFeed = const AccessRequirement.any(
      TaskPermissions.anyRead,
    ).isSatisfiedBy(access);

    return Scaffold(
      appBar: const OmniTopBar(semanticsTitle: 'Việc'),
      floatingActionButton: isAssigner
          ? ShellFabLift(
              child: CreateSquareButton(
                open: _sheetOpen,
                onPressed: () => _create(canCreateTeam: canCreateTeam),
              ),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(teamsWithPlansProvider),
        child: OmniAsyncView(
          value: groups,
          onRetry: () => ref.invalidate(teamsWithPlansProvider),
          data: (list) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              16,
              12,
              16,
              OmniSpacing.bottomSafe,
            ),
            children: [
              if (list.isEmpty)
                SizedBox(
                  height: 260,
                  child: OmniEmptyState(
                    icon: Icons.workspaces_outline,
                    title: 'Chưa có team nào',
                    message: isAssigner
                        ? 'Tạo một team để nhóm các dự án lại.'
                        : 'Khi bạn được thêm vào một dự án, nó sẽ hiện ở đây.',
                  ),
                ),
              for (final group in list) ...[
                PlanListCard(group: group, canDelete: canDeleteTeam),
                const SizedBox(height: 14),
              ],
              if (canOpenFeed) const _TimelineCard(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thẻ "Dòng việc" cuối danh sách: lối vào dòng hoạt động và KPI tháng.
class _TimelineCard extends ConsumerWidget {
  const _TimelineCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final tone = OmniTaskTones.of(context).today;
    // Lỗi / đang tải đều rơi về phụ đề trung tính: thẻ này là lối vào, không
    // được biến mất chỉ vì con số KPI chưa có.
    final delivered = ref.watch(workshopKpiProvider).valueOrNull?.delivered;
    final subtitle = delivered == null
        ? 'KPI tháng · feed 7 ngày'
        : 'KPI tháng · $delivered việc xong';
    const radius = BorderRadius.all(Radius.circular(8));

    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.pushNamed(PlansModule.timeline),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: tone.background,
                    borderRadius: radius,
                  ),
                  child: Icon(
                    Icons.timeline_rounded,
                    size: 20,
                    color: tone.foreground,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dòng việc',
                        style: text.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: OmniTaskTones.of(context).none.foreground,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
