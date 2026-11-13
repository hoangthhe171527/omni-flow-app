import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/components/components.dart';
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

    return OmniSheetBody(
      header: OmniSheetHeader(
        title: 'Gán nhân viên',
        trailing: OmniGlassCircle(
          child: IconButton(
            tooltip: 'Đóng',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ),
      ),
      children: [
        OmniGlass(
          blur: false,
          radius: 22,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: OmniSearchField(
            hint: 'Tìm nhân viên...',
            flat: true,
            dense: true,
            debounce: const Duration(milliseconds: 150),
            onChanged: (value) => setState(() => _search = value.toLowerCase()),
          ),
        ),
        OmniGroupSection(
          title: 'Ghi chú bàn giao',
          dividerIndent: 14,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: TextField(
                controller: _note,
                decoration: const InputDecoration(
                  hintText: 'Ghi chú bàn giao (tuỳ chọn)',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                ),
                maxLines: 2,
              ),
            ),
          ],
        ),
        OmniAsyncView(
          value: members,
          loading: const Column(
            children: [
              OmniSkeletonBox(height: 48),
              SizedBox(height: 8),
              OmniSkeletonBox(height: 48),
              SizedBox(height: 8),
              OmniSkeletonBox(height: 48),
            ],
          ),
          onRetry: () => ref.invalidate(teamDirectoryProvider),
          data: (list) {
            final filtered = list
                .where(
                  (member) =>
                      // `teamMembersProvider` chỉ có người chọn được
                      // (đang làm, đã nhận lời mời — APP-I10).
                      _search.isEmpty ||
                      member.name.toLowerCase().contains(_search),
                )
                .toList();

            return OmniGroupSection(
              dividerIndent: 62,
              children: [
                OmniGroupRow(
                  icon: Icons.person_off_outlined,
                  title: 'Bỏ gán',
                  subtitle: 'Trả hội thoại về hàng chờ',
                  chevron: false,
                  onTap: () => Navigator.pop(
                    context,
                    AssignResult(assigneeId: null, note: _noteText),
                  ),
                ),
                for (final member in filtered)
                  OmniGroupRow(
                    leading: OmniAvatar(
                      name: member.name,
                      imageUrl: member.avatarUrl,
                      size: 36,
                    ),
                    title: member.name,
                    subtitle: member.roleLabel,
                    selected: member.userId == widget.currentAssigneeId,
                    chevron: false,
                    onTap: () => Navigator.pop(
                      context,
                      AssignResult(assigneeId: member.userId, note: _noteText),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  String? get _noteText {
    final text = _note.text.trim();
    return text.isEmpty ? null : text;
  }
}
