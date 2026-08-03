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

    final scheme = Theme.of(context).colorScheme;
    final meta = OmniColors.chat(
      context,
      OmniColors.chatMeta,
      OmniColors.chatMetaDark,
    );

    return Column(
      children: [
        // Zalo's header is ONE flat line — a magnifier, a hint, and two icon
        // buttons. Ours was three stacked bands (a shadowed search card, quick
        // pills, then a channel row) that ate ~140px before a single
        // conversation appeared. The platform row moved into the filter sheet;
        // it is a setting a rep changes occasionally, not something worth a
        // permanent row.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
          child: Row(
            children: [
              Icon(Icons.search_rounded, size: 22, color: meta),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: TextEditingController(text: filter.search)
                    ..selection = TextSelection.collapsed(
                      offset: filter.search.length,
                    ),
                  onChanged: controller.setSearch,
                  textInputAction: TextInputAction.search,
                  style: OmniType.body.copyWith(
                    fontSize: 16,
                    color: scheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Tìm kiếm',
                    hintStyle: OmniType.body.copyWith(
                      fontSize: 16,
                      color: meta,
                    ),
                  ),
                ),
              ),
              _FilterButton(
                active: filter.channel != null || filter.label != null,
                onTap: () => _openFilterSheet(context, ref),
              ),
            ],
          ),
        ),
        // The one filter row worth keeping visible: triage state is what a rep
        // switches between all day.
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            itemCount: quickFilters.length,
            separatorBuilder: (_, _) => const SizedBox(width: OmniSpacing.sm),
            itemBuilder: (context, index) {
              final quick = quickFilters[index];
              return Center(
                child: OmniFilterPill(
                  label: quick.label,
                  selected: filter.quick == quick,
                  count: facets?.countFor(quick, currentUserId: userId),
                  onTap: () => controller.setQuick(quick),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Future<void> _openFilterSheet(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final filter = ref.watch(inboxFilterProvider);
          final controller = ref.read(inboxFilterProvider.notifier);
          final facets = ref.watch(inboxFacetsProvider).valueOrNull;

          return SafeArea(
            child: Padding(
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
                  Text('Kênh', style: OmniType.bodyStrong),
                  const SizedBox(height: OmniSpacing.md),
                  Wrap(
                    spacing: OmniSpacing.sm,
                    runSpacing: OmniSpacing.sm,
                    children: [
                      _ChannelChip(
                        label: 'Tất cả kênh',
                        selected: filter.channel == null,
                        onTap: () => controller.setChannel(null),
                      ),
                      for (final channel in inboxChannelOrder)
                        if (facets?.channels[channel.slug] != null ||
                            filter.channel == channel)
                          _ChannelChip(
                            label: channel.meta.short,
                            color: channel.meta.color,
                            count: facets?.channels[channel.slug],
                            selected: filter.channel == channel,
                            onTap: () => controller.setChannel(
                              filter.channel == channel ? null : channel,
                            ),
                          ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Filter entry point, with a dot when something is narrowing the list.
///
/// Without the dot a filtered inbox is indistinguishable from an empty one, and
/// "where did my conversations go" is the most expensive confusion this screen
/// can cause.
class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return IconButton(
      onPressed: onTap,
      tooltip: 'Lọc theo kênh',
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            Icons.tune_rounded,
            size: 22,
            color: active ? OmniColors.chatPrimary : scheme.onSurfaceVariant,
          ),
          if (active)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: OmniColors.chatPrimary,
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.surface, width: 1.5),
                ),
              ),
            ),
        ],
      ),
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
                  decoration: BoxDecoration(
                    color: tint,
                    shape: BoxShape.circle,
                  ),
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
