import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../../team/team.dart';
import '../application/plans_providers.dart';
import '../data/plans_api.dart';
import '../domain/plan.dart';
import 'edit_plan_page.dart';
import 'widgets/member_picker_sheet.dart';

/// Tên vai trên màn (bốn vai `member_roles`).
String planRoleLabel(PlanRole role) => switch (role) {
  PlanRole.owner => 'Chủ',
  PlanRole.manager => 'Quản lý',
  PlanRole.member => 'Thành viên',
  PlanRole.viewer => 'Người xem',
};

/// Thành viên kế hoạch và vai của họ.
///
/// Lưu gửi `member_ids` và `member_roles` cùng lúc ([PlanPatch.members]).
/// Vai `owner` chỉ đổi qua "Chuyển chủ kế hoạch" (server từ chối nâng ai lên
/// `owner` hay hạ `owner_id` qua `member_roles`), nên chủ — và người đã mang
/// vai chủ từ dữ liệu cũ — không đổi vai hay gỡ được ở đây, và luôn được gửi
/// đi với vai `owner`.
class PlanMembersPage extends ConsumerStatefulWidget {
  const PlanMembersPage({super.key, required this.planId});

  final String planId;

  @override
  ConsumerState<PlanMembersPage> createState() => _PlanMembersPageState();
}

class _PlanMembersPageState extends ConsumerState<PlanMembersPage> {
  Plan? _plan;

  /// Bản nháp, giữ thứ tự: id người → vai.
  Map<String, PlanRole>? _draft;
  Map<String, PlanRole> _initial = const {};
  bool _saving = false;

  static Map<String, PlanRole> _membersOf(Plan plan) {
    final members = <String, PlanRole>{
      for (final id in plan.memberIds)
        id: plan.memberRoles[id] ?? PlanRole.member,
      ...plan.memberRoles,
    };
    if (plan.ownerId case final owner? when members.containsKey(owner)) {
      members[owner] = PlanRole.owner;
    }

    return members;
  }

  bool get _dirty {
    final draft = _draft;
    if (draft == null || draft.length != _initial.length) return draft != null;
    for (final entry in draft.entries) {
      if (_initial[entry.key] != entry.value) return true;
    }
    return false;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await savePlanPatch(
      context,
      widget.planId,
      PlanPatch(members: Map.of(_draft!)),
    );
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _add() async {
    final draft = _draft!;
    final owner = _plan?.ownerId;
    final picked = await showMemberPicker(
      context,
      selected: {
        for (final e in draft.entries)
          if (e.value != PlanRole.owner) e.key,
      },
    );
    if (picked == null || !mounted) return;
    setState(() {
      draft.removeWhere(
        (id, role) => role != PlanRole.owner && !picked.contains(id),
      );
      for (final id in picked) {
        draft.putIfAbsent(
          id,
          () => id == owner ? PlanRole.owner : PlanRole.member,
        );
      }
    });
  }

  Future<void> _change(String userId, String name) async {
    final draft = _draft!;
    final current = draft[userId];
    final choice = await showOmniSheet<_RoleChoice>(
      context: context,
      builder: (ctx) => _RoleSheet(name: name, current: current),
    );
    if (choice == null || !mounted) return;
    setState(() {
      switch (choice) {
        case _SetRole(:final role):
          draft[userId] = role;
        case _Remove():
          draft.remove(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(planProvider(widget.planId));
    final loaded = async.valueOrNull;
    if (loaded != null && _plan == null) {
      _plan = loaded;
      _initial = _membersOf(loaded);
      _draft = Map.of(_initial);
    }
    final byId = ref.watch(teamMemberByIdProvider);
    final plan = _plan;
    final draft = _draft;

    return Scaffold(
      appBar: OmniAppBar(
        title: 'Thành viên',
        actions: [
          PlanSaveAction(saving: _saving, onPressed: _dirty ? _save : null),
        ],
      ),
      body: plan == null || draft == null
          ? OmniAsyncView(
              value: async,
              onRetry: () => ref.invalidate(planProvider(widget.planId)),
              data: (_) => const SizedBox.shrink(),
            )
          : ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(
                OmniSpacing.lg,
                OmniGroupSection.gap,
                OmniSpacing.lg,
                OmniSpacing.bottomSafe,
              ),
              children: [
                OmniGroupSection(
                  dividerIndent: 62,
                  children: [
                    OmniGroupRow.add(
                      title: 'Thêm thành viên',
                      icon: Icons.person_add_alt_outlined,
                      onTap: _add,
                    ),
                    // Chủ luôn đứng đầu, kể cả khi không nằm trong
                    // `member_ids`.
                    if (plan.ownerId case final owner?
                        when owner.isNotEmpty && !draft.containsKey(owner))
                      _memberRow(
                        name: byId[owner]?.name ?? 'Chủ kế hoạch',
                        avatarUrl: byId[owner]?.avatarUrl,
                        role: PlanRole.owner,
                      ),
                    for (final entry in draft.entries)
                      _memberRow(
                        name: byId[entry.key]?.name ?? 'Người dùng đã rời',
                        avatarUrl: byId[entry.key]?.avatarUrl,
                        role: entry.value,
                        onTap: entry.value == PlanRole.owner
                            ? null
                            : () => _change(
                                entry.key,
                                byId[entry.key]?.name ?? 'Người dùng đã rời',
                              ),
                      ),
                  ],
                ),
              ],
            ),
    );
  }

  /// Vai là chữ phụ kèm ›, riêng Chủ không có › (không đổi được ở đây).
  Widget _memberRow({
    required String name,
    required PlanRole role,
    String? avatarUrl,
    VoidCallback? onTap,
  }) {
    final row = OmniGroupRow(
      leading: OmniAvatar(name: name, imageUrl: avatarUrl, size: 36),
      title: name,
      maxTitleLines: 1,
      value: planRoleLabel(role),
      onTap: onTap,
    );
    if (onTap == null) return row;

    return Semantics(
      button: true,
      label: 'Đổi vai $name',
      excludeSemantics: true,
      onTap: onTap,
      child: row,
    );
  }
}

sealed class _RoleChoice {
  const _RoleChoice();
}

class _SetRole extends _RoleChoice {
  const _SetRole(this.role);
  final PlanRole role;
}

class _Remove extends _RoleChoice {
  const _Remove();
}

class _RoleSheet extends StatelessWidget {
  const _RoleSheet({required this.name, required this.current});

  final String name;
  final PlanRole? current;

  @override
  Widget build(BuildContext context) {
    return OmniSheetBody(
      header: OmniSheetHeader(title: name),
      children: [
        // Vai hiện tại trắng mờ và có ✓.
        OmniGroupSection(
          dividerIndent: 14,
          children: [
            for (final role in const [
              PlanRole.manager,
              PlanRole.member,
              PlanRole.viewer,
            ])
              OmniGroupRow(
                title: planRoleLabel(role),
                selected: role == current,
                onTap: () => Navigator.of(context).pop(_SetRole(role)),
              ),
          ],
        ),
        OmniGroupSection(
          dividerIndent: 14,
          children: [
            OmniGroupRow(
              title: 'Gỡ khỏi kế hoạch',
              destructive: true,
              onTap: () => Navigator.of(context).pop(const _Remove()),
            ),
          ],
        ),
      ],
    );
  }
}
