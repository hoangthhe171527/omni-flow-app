import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../../team/team.dart';

class AssignResult {
  const AssignResult({required this.assigneeId, this.note});

  final String? assigneeId;
  final String? note;
}

/// Hand a conversation to a colleague.
///
/// Shows each person's current load, because the useful question isn't "who
/// exists" but "who can take this now".
class AssignSheet extends ConsumerStatefulWidget {
  const AssignSheet({super.key, this.currentAssigneeId});

  final String? currentAssigneeId;

  @override
  ConsumerState<AssignSheet> createState() => _AssignSheetState();
}

class _AssignSheetState extends ConsumerState<AssignSheet> {
  final _note = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(teamMembersProvider);
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.lg,
        0,
        OmniSpacing.lg,
        OmniSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gán nhân viên',
            style: OmniType.section.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: OmniSpacing.md),
          OmniSearchField(
            hint: 'Tìm nhân viên...',
            debounce: const Duration(milliseconds: 150),
            onChanged: (value) => setState(() => _search = value.toLowerCase()),
          ),
          const SizedBox(height: OmniSpacing.md),
          Flexible(
            child: OmniAsyncView(
              value: members,
              loading: const OmniSkeletonList(count: 4, height: 56),
              onRetry: () => ref.invalidate(teamMembersProvider),
              data: (list) {
                final filtered = list
                    .where(
                      (member) =>
                          _search.isEmpty ||
                          member.name.toLowerCase().contains(_search),
                    )
                    .toList();

                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: filtered.length + 1,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: OmniSpacing.xs),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: scheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.person_off_outlined,
                            size: 18,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        title: Text('Bỏ gán', style: OmniType.caption),
                        subtitle: Text(
                          'Trả hội thoại về hàng chờ',
                          style: OmniType.micro.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        onTap: () => Navigator.pop(
                          context,
                          AssignResult(assigneeId: null, note: _noteText),
                        ),
                      );
                    }

                    final member = filtered[index - 1];
                    final current = member.userId == widget.currentAssigneeId;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: OmniAvatar(
                        name: member.name,
                        imageUrl: member.avatarUrl,
                        size: 40,
                      ),
                      title: Text(
                        member.name,
                        style: OmniType.caption.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        member.roleLabel,
                        style: OmniType.micro.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: current
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: scheme.primary,
                            )
                          : null,
                      onTap: () => Navigator.pop(
                        context,
                        AssignResult(
                          assigneeId: member.userId,
                          note: _noteText,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: OmniSpacing.md),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
              hintText: 'Ghi chú bàn giao (tuỳ chọn)',
              isDense: true,
            ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  String? get _noteText {
    final text = _note.text.trim();
    return text.isEmpty ? null : text;
  }
}
