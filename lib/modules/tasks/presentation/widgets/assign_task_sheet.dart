import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../../team/team.dart';

/// Chọn ai làm một công việc, ngay trên điện thoại.
///
/// Trước đây danh sách người làm chỉ ĐỌC được: muốn giao việc phải mở máy
/// tính. Nhưng người giao việc ở xưởng đứng giữa nhà xưởng, không ngồi bàn —
/// và một thao tác chỉ làm được ở chỗ họ không đứng thì thực tế là không có.
///
/// Chọn NHIỀU người, vì một đầu việc thường hai người cùng làm (§B2). Bỏ chọn
/// hết cũng là một lựa chọn có nghĩa: trả việc về "chưa gán ai" để ai rảnh tự
/// nhận — đúng mô hình pull-based ở §3.
///
/// Trả về `null` khi người dùng đóng sheet mà không lưu, và danh sách id khi
/// họ bấm lưu. Chỗ gọi tự so với danh sách cũ để khỏi ghi rỗng.
Future<List<String>?> showAssignTaskSheet({
  required BuildContext context,
  required List<String> currentIds,
  String title = 'Ai làm việc này',
  String Function(int picked)? confirmLabel,
  Set<String>? allowedIds,
}) => showOmniSheet<List<String>>(
  context: context,
  builder: (context) => _AssignTaskSheet(
    currentIds: currentIds,
    allowedIds: allowedIds,
    title: title,
    confirmLabel: confirmLabel,
  ),
);

/// Bộ chọn người làm neo ngay tại nút giao việc trong màn chi tiết.
///
/// Header, tìm kiếm và nút xác nhận luôn đứng yên; chỉ danh sách thành viên
/// cuộn. Các nơi đang ở giữa một form (tạo việc, người theo dõi) tiếp tục dùng
/// [showAssignTaskSheet] để không trộn hai mô hình điều hướng.
Future<List<String>?> showAssignTaskMenu({
  required BuildContext context,
  required Rect anchor,
  required List<String> currentIds,
  String title = 'Ai làm việc này',
}) => showOmniAnchoredMenu<List<String>>(
  context: context,
  anchor: anchor,
  width: 344,
  menuKey: const Key('assign-task-menu'),
  semanticsLabel: title,
  scrollable: false,
  builder: (_) => _AssignTaskMenu(currentIds: currentIds, title: title),
);

class _AssignTaskMenu extends ConsumerStatefulWidget {
  const _AssignTaskMenu({required this.currentIds, required this.title});

  final List<String> currentIds;
  final String title;

  @override
  ConsumerState<_AssignTaskMenu> createState() => _AssignTaskMenuState();
}

class _AssignTaskMenuState extends ConsumerState<_AssignTaskMenu> {
  late final Set<String> _picked = {...widget.currentIds};
  String _search = '';

  void _toggle(String userId) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_picked.remove(userId)) _picked.add(userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final members = ref.watch(teamMembersProvider);
    final desiredHeight = (MediaQuery.sizeOf(context).height * .68).clamp(
      320.0,
      560.0,
    );

    return SizedBox(
      height: desiredHeight,
      child: Column(
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.only(left: 16, right: 6),
            color: scheme.surfaceContainerLow.withValues(alpha: .7),
            child: Row(
              children: [
                Icon(
                  Icons.person_add_alt_outlined,
                  size: OmniIconSize.md,
                  color: scheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: OmniType.bodyStrong.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                Text(
                  '${_picked.length} đã chọn',
                  style: OmniType.micro.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  tooltip: 'Đóng chọn người làm',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: OmniSearchField(
              hint: 'Tìm người...',
              dense: true,
              outlined: true,
              debounce: Duration.zero,
              onChanged: (value) => setState(() => _search = value),
            ),
          ),
          Expanded(
            child: OmniAsyncView(
              value: members,
              onRetry: () => ref.invalidate(teamDirectoryProvider),
              isEmpty: (rows) => _visible(rows).isEmpty,
              empty: const OmniEmptyState(
                icon: Icons.person_search_outlined,
                title: 'Không tìm thấy ai',
                message: 'Thử tên khác, hoặc xoá ô tìm kiếm.',
              ),
              data: (rows) {
                final visible = _visible(rows);
                return ListView.builder(
                  key: const Key('assign-task-members'),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final member = visible[index];
                    final selected = _picked.contains(member.userId);
                    return _AssignMemberRow(
                      member: member,
                      selected: selected,
                      onTap: () => _toggle(member.userId),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: scheme.surfaceContainerHighest),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_picked.toList()),
                child: Text(
                  _picked.isEmpty
                      ? 'Bỏ gán tất cả'
                      : 'Giao cho ${_picked.length} người',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<TeamMember> _visible(List<TeamMember> members) {
    final needle = _search.trim().toLowerCase();
    return withPickedMembers(
          members,
          _picked,
          ref.watch(teamMemberByIdProvider),
        )
        .where((m) => needle.isEmpty || m.name.toLowerCase().contains(needle))
        .toList();
  }
}

class _AssignMemberRow extends StatelessWidget {
  const _AssignMemberRow({
    required this.member,
    required this.selected,
    required this.onTap,
  });

  final TeamMember member;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final role = _assigneeRoleLabel(member);
    return Semantics(
      button: true,
      selected: selected,
      label: '${member.name}, $role',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.only(left: 16, right: 8),
          color: selected
              ? scheme.primaryContainer.withValues(alpha: .32)
              : null,
          child: Row(
            children: [
              OmniAvatar(
                name: member.name,
                imageUrl: member.avatarUrl,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: OmniType.body.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      role,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: OmniType.micro.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Checkbox.adaptive(
                value: selected,
                onChanged: (_) => onTap(),
                shape: const CircleBorder(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssignTaskSheet extends ConsumerStatefulWidget {
  const _AssignTaskSheet({
    required this.currentIds,
    required this.title,
    this.confirmLabel,
    this.allowedIds,
  });

  final List<String> currentIds;

  /// Chỉ cho chọn trong tập này (thành viên kế hoạch đích khi sao chép);
  /// null = không lọc. Người đang được chọn lúc mở vẫn hiện để còn gỡ.
  final Set<String>? allowedIds;
  final String title;

  /// Chữ nút lưu theo số người đã chọn; null = chữ của "giao việc".
  final String Function(int picked)? confirmLabel;

  @override
  ConsumerState<_AssignTaskSheet> createState() => _AssignTaskSheetState();
}

class _AssignTaskSheetState extends ConsumerState<_AssignTaskSheet> {
  late final Set<String> _picked = {...widget.currentIds};

  /// Người được chọn lúc mở: luôn hiện, kể cả ngoài `allowedIds`, để gỡ được
  /// — và không biến mất khỏi danh sách ngay khi vừa bỏ chọn.
  late final Set<String> _initial = {...widget.currentIds};
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final members = ref.watch(teamMembersProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            OmniSpacing.lg,
            OmniSpacing.sm,
            OmniSpacing.lg,
            OmniSpacing.md,
          ),
          child: Text(
            widget.title,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: OmniSpacing.lg),
          child: OmniSearchField(
            hint: 'Tìm người...',
            onChanged: (value) => setState(() => _search = value),
          ),
        ),
        const SizedBox(height: OmniSpacing.sm),
        Flexible(
          child: OmniAsyncView(
            value: members,
            onRetry: () => ref.invalidate(teamDirectoryProvider),
            isEmpty: (rows) => _visible(rows).isEmpty,
            empty: const OmniEmptyState(
              icon: Icons.person_search_outlined,
              title: 'Không tìm thấy ai',
              message: 'Thử tên khác, hoặc xoá ô tìm kiếm.',
            ),
            data: (rows) => ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: OmniSpacing.sm),
              children: [
                for (final member in _visible(rows))
                  CheckboxListTile.adaptive(
                    value: _picked.contains(member.userId),
                    onChanged: (on) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        if (on ?? false) {
                          _picked.add(member.userId);
                        } else {
                          _picked.remove(member.userId);
                        }
                      });
                    },
                    title: Text(member.name),
                    subtitle: Text(_assigneeRoleLabel(member)),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            OmniSpacing.lg,
            OmniSpacing.sm,
            OmniSpacing.lg,
            OmniSpacing.lg,
          ),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(_picked.toList()),
              // Nói ra số người đã chọn: bỏ chọn hết là một lựa chọn hợp lệ
              // (trả việc về hàng đợi chung), nên nút phải phân biệt được nó
              // với việc bấm nhầm.
              child: Text(
                widget.confirmLabel?.call(_picked.length) ??
                    (_picked.isEmpty
                        ? 'Bỏ gán tất cả'
                        : 'Giao cho ${_picked.length} người'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Lọc theo ô tìm kiếm, và chỉ những người còn hoạt động VÀ đã nhận lời mời
  /// (APP-I10).
  ///
  /// Giao việc cho một tài khoản đã ngừng hoạt động là giao vào chỗ không ai
  /// nhận — nhưng người ĐANG được gán vẫn hiện, để còn gỡ họ ra.
  List<TeamMember> _visible(List<TeamMember> members) {
    final needle = _search.trim().toLowerCase();
    final allowed = widget.allowedIds;

    // `members` chỉ có người chọn được (`teamMembersProvider`).
    return withPickedMembers(
          members,
          _picked,
          ref.watch(teamMemberByIdProvider),
        )
        .where(
          (m) =>
              allowed == null ||
              allowed.contains(m.userId) ||
              _initial.contains(m.userId),
        )
        .where((m) => needle.isEmpty || m.name.toLowerCase().contains(needle))
        .toList();
  }
}

String _assigneeRoleLabel(TeamMember member) {
  final raw = member.roleLabel.trim();
  return switch (raw.toLowerCase()) {
    'admin' => 'Quản trị viên',
    'manager' => 'Quản lý',
    'employee' || 'member' || 'worker' => 'Nhân viên',
    'sale' || 'sales' => 'Kinh doanh',
    _ => raw,
  };
}
