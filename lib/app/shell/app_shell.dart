import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/module/module_registry.dart';
import '../../core/nav/pinned_tabs.dart';
import '../../core/module/nav_destination.dart';
import '../../design/components/components.dart';
import '../../design/platform/omni_motion_scope.dart';
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
    // Branch dựng từ danh sách KHÔNG lọc quyền, y như router — hai bên phải
    // đánh chỉ số giống hệt nhau, lệch một là bấm tab này ra màn kia.
    final branchEntries = ref.watch(branchNavEntriesProvider);
    final tabs = ref.watch(tabEntriesProvider).take(maxTabs).toList();
    final moreBranchIndex = branchEntries.length;

    // Branch index the shell is currently showing, expressed in tab terms.
    final currentBranch = navigationShell.currentIndex;
    final selected = currentBranch == moreBranchIndex
        ? tabs.length
        : tabs.indexWhere((tab) => branchEntries.indexOf(tab) == currentBranch);

    final selectedIndex = selected < 0 ? tabs.length : selected;

    void select(int index) {
      final branch = index >= tabs.length
          ? moreBranchIndex
          : branchEntries.indexOf(tabs[index]);
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

/// Huy hiệu số trên một mục điều hướng, đúng giọng của mục đó.
///
/// Chung cho thanh dưới và thanh bên để hai nơi không bao giờ tô cùng một số
/// bằng hai màu khác nhau.
class _NavBadge extends StatelessWidget {
  const _NavBadge({required this.count, required this.tone});

  final int count;
  final NavBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final ring = Theme.of(context).colorScheme.surface;

    return switch (tone) {
      NavBadgeTone.unread => OmniCountBadge.unread(
        count: count,
        ringColor: ring,
      ),
      NavBadgeTone.alert => OmniCountBadge.alert(count: count, ringColor: ring),
    };
  }
}

class _ShellNavigationRail extends ConsumerWidget {
  const _ShellNavigationRail({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<ModuleNavEntry> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    Widget iconFor(ModuleNavEntry destination, {required bool selected}) {
      final badgeProvider = destination.badge;
      final count = badgeProvider == null ? 0 : ref.watch(badgeProvider);
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(selected ? destination.selectedIcon : destination.icon),
          if (count > 0)
            Positioned(
              right: -12,
              top: -9,
              child: _NavBadge(count: count, tone: destination.badgeTone),
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
      indicatorColor: scheme.primaryContainer,
      selectedIconTheme: IconThemeData(
        color: scheme.onPrimaryContainer,
        size: OmniIconSize.xl,
      ),
      unselectedIconTheme: IconThemeData(
        color: scheme.onSurfaceVariant,
        size: OmniIconSize.xl,
      ),
      selectedLabelTextStyle: OmniType.micro.copyWith(
        color: scheme.onPrimaryContainer,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: OmniType.micro.copyWith(
        color: scheme.onSurfaceVariant,
        fontWeight: FontWeight.w500,
      ),
      leading: const Padding(
        padding: EdgeInsets.only(top: OmniSpacing.lg),
        child: OmniBrandMark(size: 44, semanticLabel: 'OmniCRM'),
      ),
      destinations: [
        for (final destination in tabs)
          NavigationRailDestination(
            icon: iconFor(destination, selected: false),
            selectedIcon: iconFor(destination, selected: true),
            label: Text(destination.label),
          ),
        const NavigationRailDestination(
          icon: Icon(Icons.grid_view_outlined),
          selectedIcon: Icon(Icons.grid_view_rounded),
          label: Text('Tất cả'),
        ),
      ],
    );
  }
}

/// Thanh dưới theo `MTabBar.dc.html`: nền thẻ, vạch trên mảnh, mục đang chọn
/// nằm trong viên nhạt 56×30 với icon và chữ màu chính đậm.
class _ShellNavBar extends StatelessWidget {
  const _ShellNavBar({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<ModuleNavEntry> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
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
      label = 'Tất cả',
      icon = Icons.grid_view_outlined,
      selectedIcon = Icons.grid_view_rounded;

  final ModuleNavEntry? destination;
  final String? label;
  final IconData? icon;
  final IconData? selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    // #075E59 trên viên #DDF5F2 ở chế độ sáng — cặp primaryContainer của
    // theme, nên chế độ tối tự có bản của nó.
    final color = selected
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;
    final badgeProvider = destination?.badge;
    final count = badgeProvider == null ? 0 : ref.watch(badgeProvider);
    final text = destination?.label ?? label!;

    return Semantics(
      selected: selected,
      button: true,
      label: count > 0 ? '$text, $count' : text,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: OmniMotion.of(context).base,
              curve: OmniCurves.standard,
              width: 56,
              height: 30,
              decoration: BoxDecoration(
                color: selected ? scheme.primaryContainer : Colors.transparent,
                borderRadius: OmniRadius.pillAll,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Icon(
                    selected
                        ? (destination?.selectedIcon ?? selectedIcon!)
                        : (destination?.icon ?? icon!),
                    size: 22,
                    color: color,
                  ),
                  if (count > 0)
                    Positioned(
                      right: 2,
                      top: -4,
                      child: _NavBadge(
                        count: count,
                        tone: destination!.badgeTone,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 3),
            Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: OmniType.micro.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                letterSpacing: -0.12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
