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
    final choice = await showOmniViecSheet<_RoleChoice>(
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
    final scheme = Theme.of(context).colorScheme;
    final plan = _plan;
    final draft = _draft;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thành viên'),
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
              padding: const EdgeInsets.fromLTRB(
                OmniSpacing.lg,
                OmniSpacing.md,
                OmniSpacing.lg,
                OmniSpacing.bottomSafe,
              ),
              children: [
                // Chủ luôn đứng đầu, kể cả khi không nằm trong `member_ids`.
                if (plan.ownerId case final owner?
                    when owner.isNotEmpty && !draft.containsKey(owner))
                  _MemberRow(
                    name: byId[owner]?.name ?? 'Chủ kế hoạch',
                    avatarUrl: byId[owner]?.avatarUrl,
                    role: PlanRole.owner,
                  ),
                for (final entry in draft.entries)
                  _MemberRow(
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
                const SizedBox(height: OmniSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      foregroundColor: scheme.primary,
                    ),
                    onPressed: _add,
                    icon: const Icon(Icons.person_add_alt_outlined),
                    label: const Text('Thêm thành viên'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.name,
    required this.role,
    this.avatarUrl,
    this.onTap,
  });

  final String name;
  final String? avatarUrl;
  final PlanRole role;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Row(
        children: [
          OmniAvatar(name: name, imageUrl: avatarUrl, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: OmniType.body.copyWith(
                fontWeight: FontWeight.w500,
                color: scheme.onSurface,
              ),
            ),
          ),
          Text(
            planRoleLabel(role),
            style: OmniType.caption.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (onTap != null)
            Icon(
              Icons.expand_more_rounded,
              size: OmniIconSize.lg,
              color: scheme.onSurfaceVariant,
            ),
        ],
      ),
    );
    if (onTap == null) return row;

    return Semantics(
      button: true,
      label: 'Đổi vai $name',
      excludeSemantics: true,
      child: InkWell(onTap: onTap, child: row),
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
    final scheme = Theme.of(context).colorScheme;
    final danger = OmniTaskTones.of(context).highPriority.foreground;

    Widget row(String label, _RoleChoice value, {bool selected = false}) {
      final isDanger = value is _Remove;

      return InkWell(
        onTap: () => Navigator.of(context).pop(value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: OmniType.body.copyWith(
                    fontWeight: FontWeight.w500,
                    color: isDanger ? danger : scheme.onSurface,
                  ),
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_rounded,
                  size: OmniIconSize.lg,
                  color: scheme.primary,
                ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const OmniSheetHandle(gap: 6),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: OmniType.section.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: 8),
          for (final role in const [
            PlanRole.manager,
            PlanRole.member,
            PlanRole.viewer,
          ])
            row(planRoleLabel(role), _SetRole(role), selected: role == current),
          row('Gỡ khỏi kế hoạch', const _Remove()),
        ],
      ),
    );
  }
}
