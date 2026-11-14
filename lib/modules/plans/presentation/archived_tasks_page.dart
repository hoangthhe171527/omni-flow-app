import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/nav/shell_bar_inset.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../../../security/session/session_controller.dart';
import '../../tasks/application/tasks_providers.dart';
import '../../tasks/data/tasks_api.dart';
import '../../tasks/domain/task.dart';
import '../../tasks/tasks_module.dart';
import '../application/plans_providers.dart';
import '../domain/plan.dart';

/// Việc đã lưu trữ: mở trực tiếp từ menu Vận hành (xem tất cả hoặc chọn kế
/// hoạch để lọc) hoặc từ menu của một kế hoạch (`planId` truyền sẵn).
///
/// `GET /tasks?[project_id=]&archived=archived`. "Khôi phục" gửi
/// `PUT /tasks/{id} {archived:false}`; dòng biến mất ngay khi server nhận,
/// việc quay về bảng.
class ArchivedTasksPage extends ConsumerStatefulWidget {
  const ArchivedTasksPage({
    super.key,
    this.planId,
    this.canRestore,
  });

  /// Null khi mở trực tiếp từ menu Vận hành (xem tất cả hoặc chọn kế hoạch).
  final String? planId;

  /// Có `tasks.write` và không phải người xem của kế hoạch — đúng điều kiện
  /// `ProjectAccessService::assertCanEditTasks` phía API.
  /// Khi null (mở từ menu Vận hành), tự suy ra theo từng việc và quyền
  /// `taskAccessProvider.canUpdate`.
  final bool? canRestore;

  @override
  ConsumerState<ArchivedTasksPage> createState() => _ArchivedTasksPageState();
}

class _ArchivedTasksPageState extends ConsumerState<ArchivedTasksPage> {
  /// Đã khôi phục trong phiên này: ẩn ngay, không chờ danh sách tải lại.
  final _restored = <String>{};

  /// Đang gửi: nút tắt để không gửi hai lần.
  final _busy = <String>{};

  late String? _selectedPlanId = widget.planId;

  @override
  void didUpdateWidget(covariant ArchivedTasksPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.planId != widget.planId) {
      _selectedPlanId = widget.planId;
    }
  }

  Future<void> _restore(Task task) async {
    HapticFeedback.selectionClick();
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context);
    setState(() => _busy.add(task.id));
    try {
      await container.read(tasksApiProvider).setArchived(task.id, false);
      if (mounted) setState(() => _restored.add(task.id));
      final targetPlanId = task.projectId ?? _selectedPlanId;
      if (targetPlanId != null && targetPlanId.isNotEmpty) {
        container.invalidate(planTasksProvider(targetPlanId));
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Đã khôi phục “${task.title}”.')),
      );
    } on AppException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _busy.remove(task.id));
    }
  }

  Future<void> _pickPlan(List<Plan> plans) async {
    final picked = await showOmniSheet<String?>(
      context: context,
      builder: (sheetContext) => OmniSheetBody(
        header: OmniSheetHeader(
          title: 'Chọn kế hoạch',
          trailing: OmniTopBarAction(
            icon: Icons.close_rounded,
            tooltip: 'Đóng',
            onPressed: () => Navigator.of(sheetContext).pop(_selectedPlanId),
          ),
        ),
        children: [
          OmniGroupSection(
            children: [
              OmniGroupRow(
                title: 'Tất cả kế hoạch',
                selected: _selectedPlanId == null,
                chevron: false,
                onTap: () => Navigator.of(sheetContext).pop(null),
              ),
              for (final plan in plans)
                OmniGroupRow(
                  title: plan.name,
                  selected: _selectedPlanId == plan.id,
                  chevron: false,
                  onTap: () => Navigator.of(sheetContext).pop(plan.id),
                ),
            ],
          ),
        ],
      ),
    );
    if (!mounted || picked == _selectedPlanId) return;
    setState(() => _selectedPlanId = picked);
  }

  void _invalidateCurrent() {
    final planId = _selectedPlanId;
    if (planId != null && planId.isNotEmpty) {
      ref.invalidate(archivedTasksProvider(planId));
    } else {
      ref.invalidate(allArchivedTasksProvider);
    }
  }

  bool _canRestoreTask(Task task, Map<String, Plan> planById, bool canUpdate, String? me) {
    final explicit = widget.canRestore;
    if (explicit != null) return explicit;
    if (!canUpdate) return false;
    final plan = planById[task.projectId ?? _selectedPlanId];
    if (me == null || plan == null) return true;
    return plan.ownerId == me || plan.memberRoles[me] != PlanRole.viewer;
  }

  String? _subtitleOf(Task task, Map<String, Plan> planById) {
    final section = (task.sectionName ?? '').trim();
    if (_selectedPlanId != null) {
      return section.isEmpty ? null : section;
    }
    final planName = (planById[task.projectId]?.name ?? '').trim();
    if (planName.isNotEmpty && section.isNotEmpty) {
      return '$planName · $section';
    }
    if (planName.isNotEmpty) return planName;
    return section.isEmpty ? null : section;
  }

  @override
  Widget build(BuildContext context) {
    final planId = _selectedPlanId;
    final archived = planId != null && planId.isNotEmpty
        ? ref.watch(archivedTasksProvider(planId))
        : ref.watch(allArchivedTasksProvider);

    final showPlanFilter = widget.planId == null;
    final groups = showPlanFilter
        ? ref.watch(teamsWithPlansProvider).valueOrNull ?? const <TeamWithPlans>[]
        : const <TeamWithPlans>[];
    final allPlans = [
      for (final g in groups) ...[...g.plans, ...g.closedPlans],
    ];
    final planById = {for (final p in allPlans) p.id: p};

    final canUpdate = widget.canRestore ?? ref.watch(taskAccessProvider).canUpdate;
    final me = widget.canRestore == null
        ? ref.watch(sessionProvider).user?.id
        : null;

    final scheme = Theme.of(context).colorScheme;
    final bottomPadding = math.max(
      OmniSpacing.bottomSafe,
      ShellBarInset.of(context) + MediaQuery.viewPaddingOf(context).bottom + 24,
    );

    return Scaffold(
      appBar: OmniAppBar(
        title: 'Việc đã lưu trữ',
        centerTitle: widget.planId == null,
        fallbackBack: widget.planId == null
            ? null
            : () => context.go('/plans/${widget.planId}'),
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: () async => _invalidateCurrent(),
        child: OmniAsyncView(
          value: archived,
          onRetry: _invalidateCurrent,
          data: (result) {
            final tasks = [
              for (final t in result.tasks)
                if (!_restored.contains(t.id)) t,
            ];

            final filterSection = showPlanFilter
                ? OmniGroupSection(
                    children: [
                      OmniGroupRow(
                        title: 'Kế hoạch',
                        value: planId == null
                            ? 'Tất cả kế hoạch'
                            : (planById[planId]?.name ?? 'Tất cả kế hoạch'),
                        onTap: allPlans.isEmpty
                            ? null
                            : () => _pickPlan(allPlans),
                      ),
                    ],
                  )
                : null;

            if (tasks.isEmpty) {
              if (!showPlanFilter) {
                return const OmniEmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'Chưa có việc nào được lưu trữ',
                  message: 'Việc lưu trữ từ menu của việc sẽ nằm ở đây.',
                );
              }
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  OmniSpacing.lg,
                  OmniSpacing.md,
                  OmniSpacing.lg,
                  bottomPadding,
                ),
                children: [
                  filterSection!,
                  const SizedBox(height: OmniSpacing.xl),
                  const OmniEmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'Chưa có việc nào được lưu trữ',
                    message: 'Việc lưu trữ từ menu của việc sẽ nằm ở đây.',
                  ),
                ],
              );
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                OmniSpacing.lg,
                OmniSpacing.md,
                OmniSpacing.lg,
                bottomPadding,
              ),
              children: [
                if (filterSection != null) ...[
                  filterSection,
                  const SizedBox(height: OmniGroupSection.gap),
                ],
                // Dừng ở trần mà server còn nữa: nói ra ở ĐẦU danh sách, không
                // lặng lẽ dừng ở việc thứ 500.
                if (result.truncated) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                    child: Text(
                      'Chỉ hiện $kMaxArchivedTasks việc lưu trữ đầu tiên. '
                      'Tìm việc cũ hơn trên web.',
                      style: OmniType.caption.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
                OmniGroupSection(
                  dividerIndent: 14,
                  children: [
                    for (final task in tasks)
                      if (_canRestoreTask(task, planById, canUpdate, me))
                        Stack(
                          key: ValueKey('archived-${task.id}'),
                          alignment: Alignment.centerRight,
                          children: [
                            OmniGroupRow(
                              title: task.title,
                              subtitle: _subtitleOf(task, planById),
                              chevron: false,
                              onTap: () => context.pushNamed(
                                TasksModule.detail,
                                pathParameters: {'id': task.id},
                              ),
                              trailing: const SizedBox(width: 92, height: 32),
                            ),
                            Positioned(
                              right: 14,
                              child: _RestoreGlassPill(
                                taskTitle: task.title,
                                busy: _busy.contains(task.id),
                                onPressed: () => _restore(task),
                              ),
                            ),
                          ],
                        )
                      else
                        OmniGroupRow(
                          key: ValueKey('archived-${task.id}'),
                          title: task.title,
                          subtitle: _subtitleOf(task, planById),
                          chevron: true,
                          onTap: () => context.pushNamed(
                            TasksModule.detail,
                            pathParameters: {'id': task.id},
                          ),
                        ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RestoreGlassPill extends StatelessWidget {
  const _RestoreGlassPill({
    required this.taskTitle,
    required this.busy,
    required this.onPressed,
  });

  final String taskTitle;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      container: true,
      button: true,
      label: 'Khôi phục $taskTitle',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        child: Center(
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: busy ? null : onPressed,
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: OmniGlass.buttonDecoration(context),
                child: Text(
                  'Khôi phục',
                  style: OmniType.caption.copyWith(
                    color: busy ? scheme.onSurfaceVariant : scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
