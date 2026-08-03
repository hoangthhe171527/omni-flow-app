import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../../../security/session/session_controller.dart';
import '../../application/inbox_providers.dart';
import '../../domain/inbox_filter.dart';
import '../inbox_page.dart';

/// Search + two levels of filtering: quick state pills, then platform/account.
///
/// Counts come from the server's faceted search, so each number already accounts
/// for the other active filters — tapping a pill can never surface a different
/// count than it promised.
class InboxFilterBar extends ConsumerWidget {
  const InboxFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(inboxFilterProvider);
    final controller = ref.read(inboxFilterProvider.notifier);
    final facets = ref.watch(inboxFacetsProvider).valueOrNull;
    final userId = ref.watch(sessionProvider).user?.id;
    final access = ref.watch(inboxAccessProvider);

    final quickFilters = [
      InboxQuickFilter.all,
      InboxQuickFilter.unread,
      if (access.showsAssigneeFilter) InboxQuickFilter.mine,
      if (access.showsAssigneeFilter) InboxQuickFilter.unassigned,
      InboxQuickFilter.urgent,
      InboxQuickFilter.closed,
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            OmniSpacing.lg,
            0,
            OmniSpacing.lg,
            OmniSpacing.md,
          ),
          child: OmniSearchField(
            hint: 'Tìm kiếm hội thoại...',
            initialValue: filter.search,
            onChanged: controller.setSearch,
          ),
        ),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: OmniSpacing.lg),
            itemCount: quickFilters.length,
            separatorBuilder: (_, _) => const SizedBox(width: OmniSpacing.sm),
            itemBuilder: (context, index) {
              final quick = quickFilters[index];
              return OmniFilterPill(
                label: quick.label,
                selected: filter.quick == quick,
                count: facets?.countFor(quick, currentUserId: userId),
                onTap: () => controller.setQuick(quick),
              );
            },
          ),
        ),
        const SizedBox(height: OmniSpacing.md),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: OmniSpacing.lg),
            itemCount: inboxChannelOrder.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: OmniSpacing.sm),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _ChannelChip(
                  label: 'Tất cả kênh',
                  selected: filter.channel == null,
                  onTap: () => controller.setChannel(null),
                );
              }
              final channel = inboxChannelOrder[index - 1];
              final count = facets?.channels[channel.slug];
              // Hide platforms this tenant has never received a message on —
              // an eight-chip row of empty channels is noise.
              if (count == null && filter.channel != channel) {
                return const SizedBox.shrink();
              }
              return _ChannelChip(
                label: channel.meta.short,
                color: channel.meta.color,
                count: count,
                selected: filter.channel == channel,
                onTap: () => controller.setChannel(
                  filter.channel == channel ? null : channel,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: OmniSpacing.md),
      ],
    );
  }
}

class _ChannelChip extends StatelessWidget {
  const _ChannelChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = color ?? scheme.onSurfaceVariant;

    return Material(
      color: selected ? tint.withValues(alpha: 0.12) : scheme.surface,
      borderRadius: OmniRadius.pillAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: OmniRadius.pillAll,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: OmniSpacing.md),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: OmniRadius.pillAll,
            border: Border.all(color: selected ? tint : scheme.outline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (color != null) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: OmniType.micro.copyWith(
                  color: selected ? tint : scheme.onSurface,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 5),
                Text(
                  '$count',
                  style: OmniType.micro.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontFeatures: OmniType.tabular,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
