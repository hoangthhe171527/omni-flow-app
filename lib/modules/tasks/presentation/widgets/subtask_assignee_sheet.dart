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

class _Sheet extends ConsumerStatefulWidget {
  const _Sheet({required this.projectId, required this.subtask});

  final String? projectId;
  final Subtask subtask;

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

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: OmniSpacing.lg),
            child: OmniSearchField(
              hint: 'Tìm người...',
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
            child: OmniAsyncView<List<TeamMember>>(
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
                    side: BorderSide(
                      color: OmniColors.controlBorderOf(context),
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: OmniRadius.xsAll,
                    ),
                  ),
                  child: const Text('Bỏ gán'),
                ),
              ),
            ),
        ],
      ),
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
