import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/channel.dart';
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
                    // The app-wide inputDecorationTheme sets `filled: true`, and
                    // that inherited fill was the dim box sitting behind the
                    // search text. Zalo has no box here at all — just the icon,
                    // the word, and a rule under the whole header.
                    filled: false,
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
                onTap: () => _openChannelMenu(context, ref),
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
        // One rule under the whole header — the only edge the search area needs.
        Divider(
          height: 1,
          thickness: 1,
          color: OmniColors.chat(
            context,
            OmniColors.chatDivider,
            OmniColors.chatDividerDark,
          ),
        ),
      ],
    );
  }

  /// Channel picker as a MENU anchored to the button, not a bottom sheet.
  ///
  /// A full sheet to choose one value spent a drag handle, a heading and a
  /// wrapped chip grid on a list of at most eight short words — most of what it
  /// put on screen was empty. A menu is the size of its contents, appears where
  /// the finger already is, and dismisses on the choice.
  Future<void> _openChannelMenu(BuildContext context, WidgetRef ref) async {
    final filter = ref.read(inboxFilterProvider);
    final controller = ref.read(inboxFilterProvider.notifier);
    final facets = ref.read(inboxFacetsProvider).valueOrNull;
    final scheme = Theme.of(context).colorScheme;

    final button = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (button == null || overlay == null) return;

    final origin = button.localToGlobal(Offset.zero, ancestor: overlay);
    final position = RelativeRect.fromLTRB(
      origin.dx,
      origin.dy + button.size.height,
      overlay.size.width - origin.dx - button.size.width,
      0,
    );

    // Only platforms this tenant has actually received on: an eight-row menu of
    // channels that have never carried a message is the same padding problem in
    // a different shape.
    final available = [
      for (final channel in inboxChannelOrder)
        if (facets?.channels[channel.slug] != null || filter.channel == channel)
          channel,
    ];

    final picked = await showMenu<_ChannelChoice>(
      context: context,
      position: position,
      // A hairline instead of a heavy popup shadow, matching the header rule.
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.4)),
      ),
      items: [
        _channelItem(
          context,
          value: const _ChannelChoice(null),
          label: 'Tất cả kênh',
          selected: filter.channel == null,
        ),
        for (final channel in available)
          _channelItem(
            context,
            value: _ChannelChoice(channel),
            label: channel.meta.short,
            color: channel.meta.color,
            count: facets?.channels[channel.slug],
            selected: filter.channel == channel,
          ),
      ],
    );

    // The choice is WRAPPED so that "chose Tất cả kênh" (a real pick of null)
    // stays distinguishable from a dismissal — a tap outside must not silently
    // clear the filter.
    if (picked != null) controller.setChannel(picked.channel);
  }

  PopupMenuItem<_ChannelChoice> _channelItem(
    BuildContext context, {
    required _ChannelChoice value,
    required String label,
    required bool selected,
    Color? color,
    int? count,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return PopupMenuItem<_ChannelChoice>(
      value: value,
      height: 40,
      child: Row(
        children: [
          if (color != null)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            )
          else
            const SizedBox(width: 18),
          Expanded(
            child: Text(
              label,
              style: OmniType.caption.copyWith(
                fontSize: 14,
                color: scheme.onSurface,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          if (count != null && count > 0)
            Text(
              '$count',
              style: OmniType.caption.copyWith(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
                fontFeatures: OmniType.tabular,
              ),
            ),
          if (selected)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(
                Icons.check_rounded,
                size: 17,
                color: OmniColors.chatPrimary,
              ),
            ),
        ],
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

/// Wraps the picked channel so that "Tất cả kênh" — a genuine choice of null —
/// is not indistinguishable from dismissing the menu.
class _ChannelChoice {
  const _ChannelChoice(this.channel);

  final Channel? channel;
}
