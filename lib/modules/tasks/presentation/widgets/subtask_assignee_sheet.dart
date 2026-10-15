import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/text_search.dart';
import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../../../security/session/session_controller.dart';
import '../../../team/team.dart';
import '../../application/tasks_providers.dart';
import '../../domain/task.dart';

/// Kết quả của bảng "Ai làm việc này". `null` (đóng bảng, hoặc chọn đúng người
/// đang giữ) = không ghi gì.
sealed class SubtaskAssignResult {
  const SubtaskAssignResult();
}

class SubtaskAssignTo extends SubtaskAssignResult {
  const SubtaskAssignTo(this.userId);

  final String userId;
}

class SubtaskUnassign extends SubtaskAssignResult {
  const SubtaskUnassign();
}

/// Chọn ai làm một việc con: thành viên dự án (hoặc cả workspace khi việc không
/// thuộc dự án nào), có ô tìm, ✓ ở người đang giữ, và "Bỏ gán" khi đang có người.
Future<SubtaskAssignResult?> showSubtaskAssigneeSheet(
  BuildContext context, {
  required String? projectId,
  required Subtask subtask,
}) => showOmniSheet<SubtaskAssignResult>(
  context: context,
  builder: (_) => _Sheet(projectId: projectId, subtask: subtask),
);

/// Bộ chọn một người làm, neo trực tiếp vào nút người làm của việc con.
Future<SubtaskAssignResult?> showSubtaskAssigneeMenu(
  BuildContext context, {
  required Rect anchor,
  required String? projectId,
  required Subtask subtask,
}) => showOmniAnchoredMenu<SubtaskAssignResult>(
  context: context,
  anchor: anchor,
  width: 344,
  menuKey: const Key('subtask-assignee-menu'),
  semanticsLabel: 'Giao người làm việc con',
  scrollable: false,
  builder: (_) => SizedBox(
    height: (MediaQuery.sizeOf(context).height * .64).clamp(320.0, 540.0),
    child: _Sheet(projectId: projectId, subtask: subtask, inMenu: true),
  ),
);

class _Sheet extends ConsumerStatefulWidget {
  const _Sheet({
    required this.projectId,
    required this.subtask,
    this.inMenu = false,
  });

  final String? projectId;
  final Subtask subtask;
  final bool inMenu;

  @override
  ConsumerState<_Sheet> createState() => _SheetState();
}

class _SheetState extends ConsumerState<_Sheet> {
  String _query = '';

  AsyncValue<List<TeamMember>> _members() => widget.projectId == null
      ? ref.watch(teamMembersProvider)
      : ref.watch(projectMembersProvider(widget.projectId!));

  void _retry() {
    if (widget.projectId == null) {
      ref.invalidate(teamDirectoryProvider);
    } else {
      ref.invalidate(projectMembersProvider(widget.projectId!));
    }
  }

  bool _matches(TeamMember m) =>
      matchesQuery(label: m.name, subtitle: m.jobTitle ?? '', query: _query);

  void _pick(TeamMember m) => Navigator.of(context).pop(
    m.userId == widget.subtask.assigneeId ? null : SubtaskAssignTo(m.userId),
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final members = _members();
    final byId = ref.watch(teamMemberByIdProvider);
    final currentId = widget.subtask.assigneeId;

    // Người thợ không có quyền đọc danh bạ (`membership.members.read`) nên
    // danh sách của họ lỗi hoặc rỗng — nhưng họ vẫn nhận việc con về mình được
    // (luật cũ "Tôi nhận"). Dòng của chính mình luôn có trong trường hợp đó.
    final me = ref.watch(sessionProvider.select((s) => s.user));
    final loadedRows = members.valueOrNull;
    final needsSelfRow =
        me != null &&
        (members.hasError || (loadedRows != null && loadedRows.isEmpty));
    final self = needsSelfRow
        ? TeamMember(
            membershipId: '',
            userId: me.id,
            name: me.fullName,
            avatarUrl: me.avatarUrl,
          )
        : null;
    final showSelf = self != null && _matches(self);

    List<TeamMember> visible(List<TeamMember> rows) =>
        withPickedMembers(rows, [?currentId], byId)
            .where((m) => _matches(m) && !(showSelf && m.userId == self.userId))
            .toList();

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.inMenu)
          Container(
            constraints: const BoxConstraints(minHeight: 64),
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ai làm việc này',
                        style: OmniType.bodyStrong.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                      Text(
                        'Việc con: ${widget.subtask.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: OmniType.micro.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Đóng chọn người làm',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              OmniSpacing.lg,
              OmniSpacing.sm,
              OmniSpacing.lg,
              0,
            ),
            child: Text(
              'Ai làm việc này',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              OmniSpacing.lg,
              2,
              OmniSpacing.lg,
              OmniSpacing.md,
            ),
            child: Text(
              'Việc con: ${widget.subtask.title}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: OmniType.micro.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
        Padding(
          padding: EdgeInsets.fromLTRB(
            widget.inMenu ? 12 : OmniSpacing.lg,
            widget.inMenu ? 10 : 0,
            widget.inMenu ? 12 : OmniSpacing.lg,
            0,
          ),
          child: OmniSearchField(
            hint: 'Tìm người...',
            dense: widget.inMenu,
            outlined: widget.inMenu,
            debounce: Duration.zero,
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        const SizedBox(height: OmniSpacing.sm),
        if (showSelf)
          _MemberRow(
            member: self,
            subtitle: 'Tôi',
            selected: self.userId == currentId,
            onTap: () => _pick(self),
          ),
        Flexible(
          child: widget.inMenu
              ? _CompactMemberResults(
                  value: members,
                  rows: members.valueOrNull == null
                      ? const []
                      : visible(members.valueOrNull!),
                  suppressEmpty: showSelf,
                  currentId: currentId,
                  onRetry: _retry,
                  onPick: _pick,
                )
              : OmniAsyncView<List<TeamMember>>(
                  value: members,
                  onRetry: _retry,
                  isEmpty: (rows) => visible(rows).isEmpty,
                  empty: showSelf
                      ? const SizedBox.shrink()
                      : const OmniEmptyState(
                          icon: Icons.person_search_outlined,
                          title: 'Không tìm thấy ai',
                          message: 'Thử tên khác, hoặc xoá ô tìm kiếm.',
                        ),
                  data: (rows) => ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: OmniSpacing.sm),
                    children: [
                      for (final m in visible(rows))
                        _MemberRow(
                          member: m,
                          subtitle: m.jobTitle,
                          selected: m.userId == currentId,
                          onTap: () => _pick(m),
                        ),
                    ],
                  ),
                ),
        ),
        // Luôn hiện khi đang có người, kể cả khi danh sách tải hỏng: gỡ người
        // không cần danh sách.
        if (currentId != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              OmniSpacing.lg,
              OmniSpacing.sm,
              OmniSpacing.lg,
              OmniSpacing.lg,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: () =>
                    Navigator.of(context).pop(const SubtaskUnassign()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: OmniColors.dangerTextOf(context),
                  side: BorderSide(color: OmniColors.controlBorderOf(context)),
                  shape: const RoundedRectangleBorder(
                    borderRadius: OmniRadius.xsAll,
                  ),
                ),
                child: const Text('Bỏ gán'),
              ),
            ),
          ),
      ],
    );
    return widget.inMenu ? content : SafeArea(child: content);
  }
}

/// Trạng thái nạp/rỗng/lỗi gọn cho popover. Các trạng thái toàn trang của
/// [OmniAsyncView] cố ý rộng rãi nên không phù hợp vùng neo thấp gần cuối màn.
class _CompactMemberResults extends StatelessWidget {
  const _CompactMemberResults({
    required this.value,
    required this.rows,
    required this.suppressEmpty,
    required this.currentId,
    required this.onRetry,
    required this.onPick,
  });

  final AsyncValue<List<TeamMember>> value;
  final List<TeamMember> rows;
  final bool suppressEmpty;
  final String? currentId;
  final VoidCallback onRetry;
  final ValueChanged<TeamMember> onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (value.isLoading && value.valueOrNull == null) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (value.hasError && value.valueOrNull == null) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: [
          Row(
            children: [
              Icon(
                Icons.wifi_off_rounded,
                size: OmniIconSize.md,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Không tải được danh sách',
                  style: OmniType.caption.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton(onPressed: onRetry, child: const Text('Thử lại')),
            ],
          ),
        ],
      );
    }
    if (rows.isEmpty) {
      if (suppressEmpty) return const SizedBox.shrink();
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        children: [
          Row(
            children: [
              Icon(
                Icons.person_search_outlined,
                size: OmniIconSize.md,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Không tìm thấy ai',
                  style: OmniType.caption.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: OmniSpacing.sm),
      children: [
        for (final member in rows)
          _MemberRow(
            member: member,
            subtitle: member.jobTitle,
            selected: member.userId == currentId,
            onTap: () => onPick(member),
          ),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final TeamMember member;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 46),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: OmniSpacing.lg,
            vertical: 7,
          ),
          child: Row(
            children: [
              OmniAvatar(
                name: member.name,
                imageUrl: member.avatarUrl,
                size: 32,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: text.bodyLarge?.copyWith(
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Text(
                        subtitle!,
                        style: OmniType.micro.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_rounded, size: 20, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
