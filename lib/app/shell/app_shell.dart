import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/module/module_registry.dart';
import '../../core/nav/shell_bar_inset.dart';
import '../../core/nav/tab_order.dart';
import '../../core/module/nav_destination.dart';
import '../../design/components/components.dart';
import '../../design/platform/omni_motion_scope.dart';
import '../../design/tokens/tokens.dart';
import 'tab_bar_editor_sheet.dart';

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
      HapticFeedback.selectionClick();
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
        final useRail = constraints.maxWidth >= 600;
        if (useRail) {
          return Scaffold(
            body: Row(
              children: [
                _EditOnLongPress(
                  child: _ShellNavigationRail(
                    tabs: tabs,
                    selectedIndex: selectedIndex,
                    onSelected: select,
                  ),
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

        return ShellBarInset(
          height: ShellBarInset.barHeight,
          child: Scaffold(
            // Body vẽ dưới thanh kính mờ; màn danh sách tự chừa chỗ ở đáy.
            extendBody: true,
            body: navigationShell,
            bottomNavigationBar: _EditOnLongPress(
              child: _ShellNavBar(
                tabs: tabs,
                selectedIndex: selectedIndex,
                onSelected: select,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Nhấn giữ thanh điều hướng mở màn "Sửa menu". Lối vào thứ hai là nút ở
/// "Tất cả" — thanh không mang thêm nút nào ngoài các mục của nó. Mục tab
/// (InkWell) không bắt nhấn giữ nên cử chỉ này về tay thanh.
class _EditOnLongPress extends StatelessWidget {
  const _EditOnLongPress({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      onLongPressHint: 'Sửa menu',
      onLongPress: () => showTabBarEditor(context),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPress: () => showTabBarEditor(context),
        child: child,
      ),
    );
  }
}

/// Huy hiệu số trên một mục điều hướng, đúng giọng của mục đó.
///
/// Chung cho thanh dưới và thanh bên để hai nơi không bao giờ tô cùng một số
/// bằng hai màu khác nhau.
class _NavBadge extends StatelessWidget {
  const _NavBadge({
    required this.count,
    required this.tone,
    required this.display,
  });

  final int count;
  final NavBadgeTone tone;
  final NavBadgeDisplay display;

  @override
  Widget build(BuildContext context) {
    final ring = Theme.of(context).colorScheme.surface;

    if (display == NavBadgeDisplay.dot) {
      return const OmniUnreadDot(excludeSemantics: true);
    }

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
      final label = count <= 0
          ? destination.label
          : destination.badgeDisplay == NavBadgeDisplay.dot
          ? '${destination.label}, có tin chưa đọc'
          : '${destination.label}, $count';
      return Semantics(
        label: label,
        excludeSemantics: true,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(selected ? destination.selectedIcon : destination.icon),
            if (count > 0)
              Positioned(
                right: -12,
                top: -9,
                child: _NavBadge(
                  count: count,
                  tone: destination.badgeTone,
                  display: destination.badgeDisplay,
                ),
              ),
          ],
        ),
      );
    }

    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      labelType: NavigationRailLabelType.all,
      groupAlignment: -0.75,
      backgroundColor: scheme.surface,
      // Mục đang chọn: nền xám trung tính + chữ mực, icon màu chính — không
      // còn chữ teal nhỏ trên nền teal nhạt (`SPrinciples.dc.html` §6).
      indicatorColor: scheme.surfaceContainerHighest,
      indicatorShape: const RoundedRectangleBorder(
        borderRadius: OmniRadius.mdAll,
      ),
      selectedIconTheme: IconThemeData(
        color: scheme.primary,
        size: OmniIconSize.xl,
      ),
      unselectedIconTheme: IconThemeData(
        color: scheme.onSurfaceVariant,
        size: OmniIconSize.xl,
      ),
      selectedLabelTextStyle: OmniType.micro.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: OmniType.micro.copyWith(
        color: scheme.onSurfaceVariant,
        fontWeight: FontWeight.w500,
      ),
      leading: const Padding(
        padding: EdgeInsets.only(top: OmniSpacing.lg),
        child: OmniBrandMark(size: 44, semanticLabel: 'Viomni'),
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

/// Thanh dưới: nền thẻ, vạch trên mảnh; mục đang chọn là icon màu chính, vạch
/// 2px màu chính ở mép trên và chữ mực đậm (`SMProjectsTasks.dc.html`).
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
    // Viên kính nổi cách mép 12 (`liquid-glass-uiux.html`): nội dung cuộn
    // chạy bên dưới (Scaffold.extendBody). Đáy: vùng an toàn, tối thiểu 12.
    final bottom = MediaQuery.viewPaddingOf(context).bottom;

    // Dải mờ dần sau viên kính, lan 12 lên trên: nội dung chạy tới đáy nhoè
    // và nhạt dần (kể cả ở khe hai bên viên kính) như iOS.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned(
          left: 0,
          right: 0,
          top: -12,
          bottom: 0,
          child: OmniScrollEdge(atTop: false),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, bottom > 12 ? bottom : 12),
          child: OmniGlass(
            radius: ShellBarInset.pillHeight / 2,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: SizedBox(
              height: ShellBarInset.pillHeight,
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
        ),
      ],
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
    // Mục đang chọn: viên trắng mờ trong kính + icon và chữ màu chính.
    final iconColor = selected ? scheme.primary : scheme.onSurfaceVariant;
    final labelColor = selected ? scheme.primary : scheme.onSurfaceVariant;
    final badgeProvider = destination?.badge;
    final count = badgeProvider == null ? 0 : ref.watch(badgeProvider);
    final text = destination?.label ?? label!;

    final semanticsLabel = count <= 0
        ? text
        : destination?.badgeDisplay == NavBadgeDisplay.dot
        ? '$text, có tin chưa đọc'
        : '$text, $count';

    return Semantics(
      selected: selected,
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            // Mục đang chọn: viên trắng mờ trong kính, icon + chữ màu chính.
            child: AnimatedContainer(
              duration: OmniMotion.of(context).base,
              curve: OmniCurves.standard,
              decoration: ShapeDecoration(
                shape: const StadiumBorder(),
                color: selected
                    ? OmniGlass.selectionOf(context)
                    : Colors.transparent,
                shadows: selected
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : const [],
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 44,
                      height: 26,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            selected
                                ? (destination?.selectedIcon ?? selectedIcon!)
                                : (destination?.icon ?? icon!),
                            size: 21,
                            color: iconColor,
                          ),
                          if (count > 0)
                            Positioned(
                              right: -4,
                              top: -4,
                              child: _NavBadge(
                                count: count,
                                tone: destination!.badgeTone,
                                display: destination!.badgeDisplay,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: OmniType.micro.copyWith(
                          color: labelColor,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
