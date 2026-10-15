import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../../team/team.dart';
import '../../domain/board_person.dart';

export '../../domain/board_person.dart';

/// Chọn người để lọc bảng.
Future<BoardPerson?> showPersonFilterSheet(
  BuildContext context, {
  required BoardPerson current,
}) => showOmniSheet<BoardPerson>(
  context: context,
  builder: (context) => _PersonFilterSheet(current: current),
);

/// Bộ lọc nhanh trên header bảng, neo ngay dưới nút người thay vì trượt một
/// sheet từ đáy lên. Danh sách dài vẫn cuộn trong menu.
Future<BoardPerson?> showPersonFilterMenu(
  BuildContext context, {
  required Rect anchor,
  required BoardPerson current,
}) => showOmniAnchoredMenu<BoardPerson>(
  context: context,
  anchor: anchor,
  width: 320,
  menuKey: const Key('person-filter-menu'),
  semanticsLabel: 'Lọc theo người',
  scrollable: false,
  builder: (_) => SizedBox(
    height: (MediaQuery.sizeOf(context).height * .58).clamp(300.0, 480.0),
    child: _PersonFilterSheet(current: current, inMenu: true),
  ),
);

class _PersonFilterSheet extends ConsumerWidget {
  const _PersonFilterSheet({required this.current, this.inMenu = false});

  final BoardPerson current;
  final bool inMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(teamMembersProvider);
    final text = Theme.of(context).textTheme;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            OmniSpacing.lg,
            OmniSpacing.md,
            OmniSpacing.lg,
            OmniSpacing.sm,
          ),
          child: Text(
            'Lọc theo người',
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        _Row(
          icon: Icons.groups_outlined,
          label: 'Tất cả mọi người',
          selected: current.isEveryone,
          onTap: () => Navigator.of(context).pop(BoardPerson.everyone),
        ),
        _Row(
          icon: Icons.person_add_alt_outlined,
          label: 'Chưa giao ai',
          selected: current.isUnassigned,
          onTap: () => Navigator.of(context).pop(BoardPerson.unassigned),
        ),
        const Divider(height: 1),
        // Danh sách người có thể chưa tải xong, hoặc tải hỏng. Cả hai đều
        // KHÔNG được che mất hai lựa chọn ở trên: "Tất cả" và "Chưa giao ai"
        // không cần biết ai là ai, và "Chưa giao ai" đúng là lựa chọn hay
        // dùng nhất ở đây.
        Flexible(
          child: members.when(
            data: (list) => ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                // `list` chỉ có người chọn được (APP-I10); người đang lọc
                // mà nay không chọn được vẫn hiện để thấy mình lọc ai.
                for (final member in withPickedMembers(list, [
                  ?current.userId,
                ], ref.watch(teamMemberByIdProvider)))
                  _Row(
                    avatarName: member.name,
                    label: member.name,
                    selected: current.userId == member.userId,
                    onTap: () => Navigator.of(
                      context,
                    ).pop(BoardPerson.person(member.userId, member.name)),
                  ),
              ],
            ),
            loading: () => const Padding(
              padding: EdgeInsets.all(OmniSpacing.lg),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (_, _) => Padding(
              padding: const EdgeInsets.all(OmniSpacing.lg),
              child: Text(
                'Chưa tải được danh sách người. Vẫn lọc được "Chưa giao ai".',
                style: text.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ],
    );
    return inMenu ? content : SafeArea(child: content);
  }
}

class _Row extends StatelessWidget {
  const _Row({
    this.icon,
    this.avatarName,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData? icon;

  /// Có tên thì vẽ ảnh đại diện 28 thay cho biểu tượng — một người, không
  /// phải một lựa chọn chung như "Chưa giao ai".
  final String? avatarName;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: avatarName != null
          ? OmniAvatar(name: avatarName!, size: 28)
          : Icon(icon, color: scheme.onSurfaceVariant),
      title: Text(label),
      // Dấu tick chứ không chỉ đổi màu chữ: trong ánh sáng xưởng và với người
      // mù màu, một sắc độ khác đi không phải là một tín hiệu.
      trailing: selected
          ? Icon(Icons.check_rounded, color: scheme.primary)
          : null,
      selected: selected,
      onTap: onTap,
    );
  }
}
