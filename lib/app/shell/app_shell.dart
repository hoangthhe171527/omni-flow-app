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

    final selectedIndex = selected < 0 ? tabs.length : selected;

    void select(int index) {
      final branch = index >= tabs.length
          ? moreBranchIndex
          : declared.indexOf(tabs[index]);
      navigationShell.goBranch(
        branch,
        // Tapping the active tab pops that tab back to its root — the
        // behaviour every messaging app has trained users to expect.
        initialLocation: branch == navigationShell.currentIndex,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 900;
        if (useRail) {
          return Scaffold(
            body: Row(
              children: [
                _ShellNavigationRail(
                  tabs: tabs,
                  selectedIndex: selectedIndex,
                  onSelected: select,
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Theme.of(context).colorScheme.outline,
                ),
                Expanded(child: navigationShell),
              ],
            ),
          );
        }

        return Scaffold(
          body: navigationShell,
          bottomNavigationBar: _ShellNavBar(
            tabs: tabs,
            selectedIndex: selectedIndex,
            onSelected: select,
          ),
        );
      },
    );
  }
}

class _ShellNavigationRail extends ConsumerWidget {
  const _ShellNavigationRail({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<ModuleDestination> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    Widget iconFor(ModuleDestination destination, {required bool selected}) {
      final badgeProvider = destination.badge;
      final count = badgeProvider == null ? 0 : ref.watch(badgeProvider);
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(selected ? destination.selectedIcon : destination.icon),
          if (count > 0)
            Positioned(
              right: -10,
              top: -7,
              child: OmniCountBadge(count: count, color: OmniColors.dangerText),
            ),
        ],
      );
    }

    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      labelType: NavigationRailLabelType.all,
      groupAlignment: -0.75,
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primary.withValues(alpha: 0.11),
      selectedIconTheme: IconThemeData(color: scheme.primary, size: 24),
      unselectedIconTheme: IconThemeData(
        color: scheme.onSurfaceVariant,
        size: OmniIconSize.xl,
      ),
      selectedLabelTextStyle: OmniType.micro.copyWith(
        color: scheme.primary,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelTextStyle: OmniType.micro.copyWith(
        color: scheme.onSurfaceVariant,
        fontWeight: FontWeight.w500,
      ),
      leading: Padding(
        padding: const EdgeInsets.only(top: OmniSpacing.lg),
        child: Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            gradient: OmniGradients.brand,
            borderRadius: OmniRadius.mdAll,
          ),
          child: const Icon(
            Icons.layers_rounded,
            color: Colors.white,
            size: OmniIconSize.xl,
          ),
        ),
      ),
      destinations: [
        for (final destination in tabs)
          NavigationRailDestination(
            icon: iconFor(destination, selected: false),
            selectedIcon: iconFor(destination, selected: true),
            label: Text(destination.label),
          ),
        const NavigationRailDestination(
          icon: Icon(Icons.more_horiz_rounded),
          selectedIcon: Icon(Icons.more_horiz_rounded),
          label: Text('Thêm'),
        ),
      ],
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
                  size: OmniIconSize.xl,
                  color: color,
                ),
                if (count > 0)
                  Positioned(
                    right: -10,
                    top: -6,
                    child: OmniCountBadge(
                      count: count,
                      color: OmniColors.dangerText,
                    ),
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
