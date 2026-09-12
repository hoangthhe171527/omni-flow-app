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

class _PersonFilterSheet extends ConsumerWidget {
  const _PersonFilterSheet({required this.current});

  final BoardPerson current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(teamMembersProvider);
    final text = Theme.of(context).textTheme;

    return SafeArea(
      child: Column(
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
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
                  for (final member in list)
                    _Row(
                      icon: Icons.person_outline_rounded,
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
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(icon, color: scheme.onSurfaceVariant),
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
