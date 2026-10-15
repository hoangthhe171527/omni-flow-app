import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../../tasks/application/tasks_providers.dart';
import '../../../team/team.dart';
import '../../data/plan_cover_upload.dart';
import '../../domain/plan.dart';

/// Một mục của menu kế hoạch.
enum PlanMenuAction {
  edit,
  members,
  labels,
  fields,
  copy,
  moveTeam,
  archived,
  files,
  report,
  transferOwner,
  close,
  reopen,
  delete;

  bool get danger => this == close || this == delete;
}

/// Các nhóm của menu kế hoạch theo quyền, đúng thứ tự `Board.dc.html`
/// (`.og`). Nhóm rỗng bị bỏ.
///
/// - [canManage]: chủ / quản lý kế hoạch hoặc người giao việc — sửa, thành
///   viên, trường, sao chép, chuyển team, đóng / mở lại.
/// - [canViewLabels]: đọc được danh mục nhãn (`system_options.read`).
/// - [canDelete]: như `canDeletePlan` của bảng.
///
/// Ba mục đọc ("Việc đã lưu trữ", "Tệp đính kèm", "Báo cáo kế hoạch") ai mở
/// được bảng cũng có: chỉ cần `tasks.read`. Ghi trong các màn đó (khôi phục,
/// xoá tệp) tự ẩn theo quyền.
///
/// - [canTransferOwner]: "Chuyển chủ kế hoạch" (Nhóm 2) — API có khả năng
///   (`ApiCapability.projectTransferOwner` trong phiên) VÀ người này là chủ hiện tại hoặc giữ
///   `tasks.projects.manage.all`, đúng luật `TransferProjectOwner`.
///
/// Chưa có: "Sao chép liên kết" (Task 11).
List<List<PlanMenuAction>> planMenuGroups(
  Plan plan, {
  required bool canManage,
  required bool canDelete,
  required bool canViewLabels,
  bool canTransferOwner = false,
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
      PlanMenuAction.archived,
      PlanMenuAction.files,
      PlanMenuAction.report,
    ],
    [
      if (canTransferOwner) PlanMenuAction.transferOwner,
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

({IconData icon, String label}) _planMenuMeta(PlanMenuAction action) =>
    switch (action) {
      PlanMenuAction.edit => (
        icon: Icons.edit_outlined,
        label: 'Sửa tên, mô tả, nền',
      ),
      PlanMenuAction.members => (
        icon: Icons.person_add_alt_outlined,
        label: 'Thành viên',
      ),
      PlanMenuAction.labels => (icon: Icons.sell_outlined, label: 'Nhãn màu'),
      PlanMenuAction.fields => (
        icon: Icons.list_alt_outlined,
        label: 'Trường tuỳ chỉnh',
      ),
      PlanMenuAction.copy => (
        icon: Icons.copy_outlined,
        label: 'Sao chép kế hoạch',
      ),
      PlanMenuAction.moveTeam => (
        icon: Icons.arrow_forward_rounded,
        label: 'Chuyển sang team khác',
      ),
      PlanMenuAction.archived => (
        icon: Icons.archive_outlined,
        label: 'Việc đã lưu trữ',
      ),
      PlanMenuAction.files => (
        icon: Icons.attach_file_rounded,
        label: 'Tệp đính kèm',
      ),
      PlanMenuAction.report => (
        icon: Icons.bar_chart_rounded,
        label: 'Báo cáo kế hoạch',
      ),
      PlanMenuAction.transferOwner => (
        icon: Icons.how_to_reg_outlined,
        label: 'Chuyển chủ kế hoạch',
      ),
      PlanMenuAction.close => (
        icon: Icons.lock_outline_rounded,
        label: 'Đóng kế hoạch',
      ),
      PlanMenuAction.reopen => (
        icon: Icons.lock_open_outlined,
        label: 'Mở lại kế hoạch',
      ),
      PlanMenuAction.delete => (
        icon: Icons.delete_outline,
        label: 'Xoá kế hoạch',
      ),
    };

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

/// Menu nhanh của nút `…` trong header kế hoạch, neo ngay tại nút giống menu
/// `+` ở màn Team. Danh sách dài tự cuộn trong vùng an toàn của màn hình.
Future<PlanMenuAction?> showPlanMenu(
  BuildContext context, {
  required Rect anchor,
  required Plan plan,
  required List<List<PlanMenuAction>> groups,
}) => showOmniAnchoredMenu<PlanMenuAction>(
  context: context,
  anchor: anchor,
  width: 344,
  menuKey: const Key('plan-actions-menu'),
  semanticsLabel: 'Tuỳ chọn kế hoạch',
  builder: (_) => PlanAnchoredMenu(plan: plan, groups: groups),
);

class PlanAnchoredMenu extends ConsumerWidget {
  const PlanAnchoredMenu({super.key, required this.plan, required this.groups});

  final Plan plan;
  final List<List<PlanMenuAction>> groups;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final archived = groups.any((g) => g.contains(PlanMenuAction.archived))
        ? ref.watch(archivedTasksProvider(plan.id)).valueOrNull
        : null;
    final archivedCount = archived == null
        ? null
        : archived.truncated
        ? '${archived.tasks.length}+'
        : '${archived.tasks.length}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var g = 0; g < groups.length; g++)
          Column(
            key: Key('plan-menu-group-$g'),
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < groups[g].length; i++)
                Builder(
                  builder: (_) {
                    final action = groups[g][i];
                    final meta = _planMenuMeta(action);
                    final trailing = switch (action) {
                      PlanMenuAction.members => '${planMemberCount(plan)}',
                      PlanMenuAction.archived => archivedCount,
                      _ => null,
                    };
                    return OmniAnchoredMenuItem(
                      icon: meta.icon,
                      label: meta.label,
                      divider: g > 0 || i > 0,
                      destructive: action.danger,
                      trailing: trailing == null
                          ? null
                          : Text(
                              trailing,
                              style: OmniType.caption.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                      onTap: () => Navigator.of(context).pop(action),
                    );
                  },
                ),
            ],
          ),
      ],
    );
  }
}

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
    // Số việc đã lưu trữ: tải lười khi sheet mở; đang tải hay lỗi thì không
    // có số, menu vẫn dùng được. Dừng ở trần mà server còn nữa thì "500+".
    final archived = groups.any((g) => g.contains(PlanMenuAction.archived))
        ? ref.watch(archivedTasksProvider(plan.id)).valueOrNull
        : null;
    final archivedCount = archived == null
        ? null
        : archived.truncated
        ? '${archived.tasks.length}+'
        : '${archived.tasks.length}';
    final coverUrl = resolveProjectCoverUrl(plan.cover);

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
                  ClipRRect(
                    key: const Key('plan-menu-cover'),
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox.square(
                      dimension: 36,
                      child: coverUrl == null
                          ? ColoredBox(
                              color: scheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.folder_outlined,
                                size: 20,
                                color: scheme.onSurfaceVariant,
                              ),
                            )
                          : CachedNetworkImage(
                              imageUrl: coverUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => ColoredBox(
                                color: scheme.surfaceContainerHighest,
                                child: Icon(
                                  Icons.folder_outlined,
                                  size: 20,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
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
                        trailing: switch (groups[g][i]) {
                          PlanMenuAction.members => '${planMemberCount(plan)}',
                          PlanMenuAction.archived => archivedCount,
                          _ => null,
                        },
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
    final meta = _planMenuMeta(action);
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
                meta.icon,
                size: OmniIconSize.lg,
                color: action.danger ? danger : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  meta.label,
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
