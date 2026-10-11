import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../../team/team.dart';
import '../../domain/plan.dart';

/// Một mục của menu kế hoạch.
enum PlanMenuAction {
  edit,
  members,
  labels,
  fields,
  copy,
  moveTeam,
  close,
  reopen,
  delete;

  bool get danger => this == close || this == delete;
}

/// Các nhóm của menu kế hoạch theo quyền, đúng thứ tự `Board.dc.html`
/// (`.og`). Nhóm rỗng bị bỏ; trả rỗng nghĩa là không có ⋯.
///
/// - [canManage]: chủ / quản lý kế hoạch hoặc người giao việc — sửa, thành
///   viên, trường, sao chép, chuyển team, đóng / mở lại.
/// - [canViewLabels]: đọc được danh mục nhãn (`system_options.read`).
/// - [canDelete]: như `canDeletePlan` của bảng.
///
/// Chưa có: "Sao chép liên kết", "Chuyển chủ kế hoạch" (Task 10–11, chờ API),
/// "Việc đã lưu trữ", "Tệp đính kèm", "Báo cáo kế hoạch" (Task 7).
List<List<PlanMenuAction>> planMenuGroups(
  Plan plan, {
  required bool canManage,
  required bool canDelete,
  required bool canViewLabels,
}) {
  final active = plan.planStatus == PlanStatus.active;
  final groups = [
    [
      if (canManage) PlanMenuAction.edit,
      if (canManage) PlanMenuAction.members,
      if (canViewLabels) PlanMenuAction.labels,
      if (canManage) PlanMenuAction.fields,
    ],
    [
      if (canManage) PlanMenuAction.copy,
      if (canManage) PlanMenuAction.moveTeam,
    ],
    [
      if (canManage) active ? PlanMenuAction.close : PlanMenuAction.reopen,
      // Năng lực giữ lại từ bảng cũ, không có trong bản mẫu: cuối nhóm 3.
      if (canDelete) PlanMenuAction.delete,
    ],
  ];

  return [
    for (final group in groups)
      if (group.isNotEmpty) group,
  ];
}

/// Số người trong kế hoạch: chủ, `member_ids` và mọi khoá `member_roles`.
int planMemberCount(Plan plan) => {
  if (plan.ownerId case final owner? when owner.isNotEmpty) owner,
  ...plan.memberIds,
  ...plan.memberRoles.keys,
}.length;

/// Mở menu kế hoạch; trả mục đã chọn hoặc null khi đóng.
Future<PlanMenuAction?> showPlanMenuSheet(
  BuildContext context, {
  required Plan plan,
  required List<List<PlanMenuAction>> groups,
}) => showOmniViecSheet<PlanMenuAction>(
  context: context,
  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
  builder: (_) => PlanMenuSheet(plan: plan, groups: groups),
);

/// Menu kế hoạch (`Board.dc.html` `isMenu`): nền `#F5F7FA`, đệm 8/16/30, đầu
/// sheet có ô màu nền kế hoạch và dòng "Team · chủ: Tên" (tên chủ tra trong
/// danh bạ), các nhóm `.og` nền surface bo 8.
class PlanMenuSheet extends ConsumerWidget {
  const PlanMenuSheet({super.key, required this.plan, required this.groups});

  final Plan plan;
  final List<List<PlanMenuAction>> groups;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final ownerName = plan.ownerId == null
        ? null
        : ref.watch(teamMemberByIdProvider)[plan.ownerId]?.name;
    final subtitle = [
      if (plan.teamName case final team? when team.isNotEmpty) team,
      if (ownerName case final owner? when owner.isNotEmpty) 'chủ: $owner',
    ].join(' · ');

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      label: 'Tuỳ chọn kế hoạch',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const OmniSheetHandle(),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    key: const Key('plan-menu-cover'),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: OmniCovers.gradientOf(plan.cover),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: OmniType.section.copyWith(
                            color: scheme.onSurface,
                            height: 1.25,
                          ),
                        ),
                        if (subtitle.isNotEmpty)
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: OmniType.micro.copyWith(
                              fontWeight: FontWeight.w400,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            for (var g = 0; g < groups.length; g++) ...[
              if (g > 0) const SizedBox(height: 10),
              Container(
                key: Key('plan-menu-group-$g'),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < groups[g].length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: scheme.surfaceContainerHighest,
                        ),
                      _MenuRow(
                        action: groups[g][i],
                        trailing: groups[g][i] == PlanMenuAction.members
                            ? '${planMemberCount(plan)}'
                            : null,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Một dòng `.op`: cao 48, biểu tượng 20 màu phụ, chữ 15 w500.
class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.action, this.trailing});

  final PlanMenuAction action;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final danger = OmniTaskTones.of(context).highPriority.foreground;
    final (icon, label) = switch (action) {
      PlanMenuAction.edit => (Icons.edit_outlined, 'Sửa tên, mô tả, nền'),
      PlanMenuAction.members => (Icons.person_add_alt_outlined, 'Thành viên'),
      PlanMenuAction.labels => (Icons.sell_outlined, 'Nhãn màu'),
      PlanMenuAction.fields => (Icons.list_alt_outlined, 'Trường tuỳ chỉnh'),
      PlanMenuAction.copy => (Icons.copy_outlined, 'Sao chép kế hoạch'),
      PlanMenuAction.moveTeam => (
        Icons.arrow_forward_rounded,
        'Chuyển sang team khác',
      ),
      PlanMenuAction.close => (Icons.lock_outline_rounded, 'Đóng kế hoạch'),
      PlanMenuAction.reopen => (Icons.lock_open_outlined, 'Mở lại kế hoạch'),
      PlanMenuAction.delete => (Icons.delete_outline, 'Xoá kế hoạch'),
    };
    final color = action.danger ? danger : scheme.onSurface;

    return InkWell(
      onTap: () => Navigator.of(context).pop(action),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Icon(
                icon,
                size: OmniIconSize.lg,
                color: action.danger ? danger : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: OmniType.body.copyWith(
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
              if (trailing case final value?)
                Text(
                  value,
                  style: OmniType.caption.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
