import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../application/team_providers.dart';

class TeamPage extends ConsumerWidget {
  const TeamPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(teamMembersProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Nhân viên')),
      body: OmniAsyncView(
        value: members,
        onRetry: () => ref.invalidate(teamMembersProvider),
        isEmpty: (list) => list.isEmpty,
        empty: const OmniEmptyState(
          icon: Icons.group_outlined,
          title: 'Chưa có nhân viên',
          message: 'Mời đồng nghiệp vào workspace để bắt đầu phân công.',
        ),
        data: (list) => ListView.separated(
          padding: const EdgeInsets.all(OmniSpacing.lg),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: OmniSpacing.sm),
          itemBuilder: (context, index) {
            final member = list[index];
            return OmniCard(
              padding: const EdgeInsets.all(OmniSpacing.md),
              child: Row(
                children: [
                  OmniAvatar(name: member.name, imageUrl: member.avatarUrl),
                  const SizedBox(width: OmniSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.name,
                          style: OmniType.bodyStrong.copyWith(
                            color: scheme.onSurface,
                          ),
                        ),
                        Text(
                          member.email ?? member.roleLabel,
                          style: OmniType.micro.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OmniStatusChip(
                    label: member.roleLabel,
                    tone: member.isActive ? OmniTone.info : OmniTone.neutral,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
