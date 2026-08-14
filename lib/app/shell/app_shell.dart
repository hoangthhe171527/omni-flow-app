import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/module/module_registry.dart';
import '../../core/module/nav_destination.dart';
import '../../design/components/components.dart';
import '../../design/tokens/tokens.dart';

/// The tab shell.
///
/// It knows three things: which destinations the registry says are visible, how
/// many fit, and how to switch branches. It contains no role checks, no module
/// names and no per-tab special cases — the previous app's shell branched on a
/// role enum and hard-coded tab indexes (`safeIndex == 4`), which is why adding
/// a screen there meant editing the shell.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// Tabs beyond this many are reached through "Thêm" — five targets is the
  /// most a thumb can hit reliably.
  static const int maxTabs = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final declared = ref.watch(declaredDestinationsProvider);
    final visible = ref.watch(visibleDestinationsProvider);
    final tabs = visible.take(maxTabs).toList();
    final moreBranchIndex = declared.length;

    // Branch index the shell is currently showing, expressed in tab terms.
    final currentBranch = navigationShell.currentIndex;
    final selected = currentBranch == moreBranchIndex
        ? tabs.length
        : tabs.indexWhere((tab) => declared.indexOf(tab) == currentBranch);

    void select(int index) {
      final branch = index >= tabs.length
          ? moreBranchIndex
          : declared.indexOf(tabs[index]);
      navigationShell.goBranch(
        branch,
        initialLocation: branch == navigationShell.currentIndex,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWeb = constraints.maxWidth >= 960;
        return Scaffold(
          body: isWeb
              ? Row(
                  children: [
                    _WebSidebar(
                      tabs: tabs,
                      selectedIndex: selected < 0 ? tabs.length : selected,
                      onSelected: select,
                    ),
                    Expanded(child: navigationShell),
                  ],
                )
              : navigationShell,
          bottomNavigationBar: isWeb
              ? null
              : _ShellNavBar(
                  tabs: tabs,
                  selectedIndex: selected < 0 ? tabs.length : selected,
                  onSelected: select,
                  //
                  // final branch = index >= tabs.length
                  // ? moreBranchIndex
                  // : declared.indexOf(tabs[index]);
                  // navigationShell.goBranch(
                  // branch,
                  // Tapping the active tab pops that tab back to its root — the
                  // behaviour every messaging app has trained users to expect.
                  // initialLocation: branch == navigationShell.currentIndex,
                  // );
                  // },
                  //
                ),
        );
      },
    );
  }
}

class _WebSidebar extends StatelessWidget {
  const _WebSidebar({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<ModuleDestination> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 248,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          right: BorderSide(color: colors.outline.withValues(alpha: .65)),
        ),
      ),
      child: SafeArea(
        right: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: OmniRadius.mdAll,
                    ),
                    child: Icon(
                      Icons.layers_rounded,
                      color: colors.onPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OMNI',
                        style: OmniType.section.copyWith(letterSpacing: 1.8),
                      ),
                      Text(
                        'Không gian làm việc',
                        style: OmniType.micro.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 42),
              Text(
                'ĐIỀU HƯỚNG',
                style: OmniType.overline.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < tabs.length; i++)
                _WebNavItem(
                  destination: tabs[i],
                  selected: selectedIndex == i,
                  onTap: () => onSelected(i),
                ),
              _WebNavItem(
                label: 'Mở rộng',
                icon: Icons.grid_view_outlined,
                selectedIcon: Icons.grid_view_rounded,
                selected: selectedIndex == tabs.length,
                onTap: () => onSelected(tabs.length),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: .06),
                  borderRadius: OmniRadius.lgAll,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: colors.primary.withValues(alpha: .14),
                      child: Text(
                        'TN',
                        style: OmniType.micro.copyWith(color: colors.primary),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Workspace hiện tại',
                            style: OmniType.caption.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Đang hoạt động',
                            style: OmniType.micro.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.more_horiz,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WebNavItem extends StatelessWidget {
  const _WebNavItem({
    this.destination,
    this.label,
    this.icon,
    this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  final ModuleDestination? destination;
  final String? label;
  final IconData? icon;
  final IconData? selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = selected ? colors.primary : colors.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected
            ? colors.primary.withValues(alpha: .09)
            : Colors.transparent,
        borderRadius: OmniRadius.mdAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: OmniRadius.mdAll,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(
                  selected
                      ? (destination?.selectedIcon ?? selectedIcon!)
                      : (destination?.icon ?? icon!),
                  size: 20,
                  color: foreground,
                ),
                const SizedBox(width: 12),
                Text(
                  destination?.label ?? label!,
                  style: OmniType.bodyStrong.copyWith(color: foreground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShellNavBar extends StatelessWidget {
  const _ShellNavBar({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<ModuleDestination> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: scheme.outline.withValues(alpha: 0.7)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: _ShellNavItem(
                    destination: tabs[i],
                    selected: selectedIndex == i,
                    onTap: () => onSelected(i),
                  ),
                ),
              Expanded(
                child: _ShellNavItem.more(
                  selected: selectedIndex == tabs.length,
                  onTap: () => onSelected(tabs.length),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShellNavItem extends ConsumerWidget {
  const _ShellNavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  }) : label = null,
       icon = null,
       selectedIcon = null;

  const _ShellNavItem.more({required this.selected, required this.onTap})
    : destination = null,
      label = 'Thêm',
      icon = Icons.more_horiz_rounded,
      selectedIcon = Icons.more_horiz_rounded;

  final ModuleDestination? destination;
  final String? label;
  final IconData? icon;
  final IconData? selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    final badgeProvider = destination?.badge;
    final count = badgeProvider == null ? 0 : ref.watch(badgeProvider);

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
            decoration: BoxDecoration(
              color: selected
                  ? scheme.primary.withValues(alpha: 0.11)
                  : Colors.transparent,
              borderRadius: OmniRadius.pillAll,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  selected
                      ? (destination?.selectedIcon ?? selectedIcon!)
                      : (destination?.icon ?? icon!),
                  size: 23,
                  color: color,
                ),
                if (count > 0)
                  Positioned(
                    right: -10,
                    top: -6,
                    child: OmniCountBadge(count: count, color: scheme.error),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Text(
            destination?.label ?? label!,
            style: OmniType.micro.copyWith(
              color: color,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
