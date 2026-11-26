import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/module/module_registry.dart';
import '../../security/session/session_controller.dart';
import '../apps/app_shell_layout.dart';
import '../apps/app_title_leading.dart';
import '../router/shell_routes.dart';
import '../../core/nav/search_mode.dart';
import '../../core/nav/shell_bar_inset.dart';
import '../../core/nav/shell_tab_routes.dart';
import '../../core/nav/tab_order.dart';
import '../../core/module/nav_destination.dart';
import '../../design/components/components.dart';
import '../../design/platform/omni_motion_scope.dart';
import '../../design/tokens/tokens.dart';
import 'tab_bar_editor_sheet.dart';
import 'tab_icons.dart';

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
    final moreBranchIndex = branchEntries.length;
    final searching = ref.watch(searchModeProvider);
    final currentBranch = navigationShell.currentIndex;

    // Khung ứng dụng (cờ `app_shell`): thanh dưới là mục của ứng dụng đang mở.
    final layout = ref.watch(appShellLayoutProvider);
    final clones = ref.watch(appTabCloneRoutesProvider);
    int branchOf(String routeName) {
      final i = branchEntries.indexWhere((e) => e.routeName == routeName);
      if (i >= 0) return i;
      final c = clones.indexOf(routeName);
      return c < 0 ? -1 : moreBranchIndex + 1 + c;
    }

    final currentRoute = currentBranch < moreBranchIndex
        ? branchEntries[currentBranch].routeName
        : currentBranch > moreBranchIndex
        ? clones[currentBranch - moreBranchIndex - 1]
        : null;
    final app = layout?.resolve(
      currentKey: ref.watch(currentAppKeyProvider),
      routeName: currentRoute,
    );

    void goBranch(int branch) {
      if (branch < 0) return;
      navigationShell.goBranch(
        branch,
        // Tapping the active tab pops that tab back to its root — the
        // behaviour every messaging app has trained users to expect.
        initialLocation: branch == navigationShell.currentIndex,
      );
    }

    final List<ModuleNavEntry> tabs;
    final _MoreSlot? more;
    final int selectedIndex;
    final ValueChanged<int> select;
    if (layout != null && app != null) {
      tabs = [for (final item in app.tabs) item.entry];
      more = app.hasMore ? _MoreSlot.app : null;
      final selected = tabs.indexWhere((t) => t.routeName == currentRoute);
      selectedIndex = selected >= 0
          ? selected
          : (more != null ? tabs.length : 0);
      select = (index) {
        HapticFeedback.selectionClick();
        if (index < tabs.length) {
          goBranch(branchOf(tabs[index].routeName));
          return;
        }
        _showAppMore(
          context,
          app: app,
          currentRoute: currentRoute,
          onPick: (item) => goBranch(branchOf(item.entry.routeName)),
        );
      };
    } else {
      tabs = ref.watch(tabEntriesProvider).take(maxTabs).toList();
      more = _MoreSlot.directory;
      // Branch index the shell is currently showing, expressed in tab terms.
      final selected = currentBranch == moreBranchIndex
          ? tabs.length
          : tabs.indexWhere(
              (tab) => branchEntries.indexOf(tab) == currentBranch,
            );
      selectedIndex = selected < 0 ? tabs.length : selected;
      select = (index) {
        HapticFeedback.selectionClick();
        goBranch(
          index >= tabs.length
              ? moreBranchIndex
              : branchEntries.indexOf(tabs[index]),
        );
      };
    }
    final appMode = layout != null && app != null;
    // Đầu thanh trên của màn gốc: nút ô lưới + tên ứng dụng về màn Chọn ứng
    // dụng. Chỉ một ô thì không có nút (không có gì để chọn).
    final Widget body = !appMode
        ? navigationShell
        : ShellTabRoutes(
            // Màn của module hỏi qua đây để không lặp lối vào trên header.
            routes: {for (final item in app.all) item.entry.routeName},
            child: OmniTopBarLeading(
              builder: (context, title) => AppTitleLeading(
                appName: layout.entries.length > 1
                    ? app.name
                    : (ref.read(sessionProvider).tenant?.name ?? app.name),
                title: title,
                onSwitch: layout.entries.length > 1
                    ? () => context.go(ShellRoutes.appsPath)
                    : null,
              ),
              child: navigationShell,
            ),
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 600;
        if (useRail) {
          return Scaffold(
            body: Row(
              children: [
                _EditOnLongPress(
                  enabled: !appMode,
                  child: _ShellNavigationRail(
                    tabs: tabs,
                    more: more,
                    selectedIndex: selectedIndex,
                    onSelected: select,
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Theme.of(context).colorScheme.outline,
                ),
                Expanded(child: body),
              ],
            ),
          );
        }

        return ShellBarInset(
          height: ShellBarInset.barHeight,
          child: Scaffold(
            // Body vẽ dưới thanh kính mờ; màn danh sách tự chừa chỗ ở đáy.
            extendBody: true,
            body: body,
            // Đang tìm (ô tìm của thanh trên có focus): thanh tab trượt xuống
            // ẩn, chỉ còn ô tìm và kết quả — như Thư viện ứng dụng iOS.
            bottomNavigationBar: IgnorePointer(
              ignoring: searching,
              // Chỉ trượt, không mờ dần: AnimatedOpacity bọc viên kính làm
              // mờ = thêm một lớp vẽ (saveLayer) chứa BackdropFilter suốt lúc
              // ẩn/hiện; thanh trượt hẳn khỏi màn nên mờ dần là thừa.
              // RepaintBoundary: thấu kính trượt khi đổi tab chỉ vẽ lại thanh.
              child: AnimatedSlide(
                offset: searching ? const Offset(0, 1.4) : Offset.zero,
                duration: OmniMotion.of(context).base,
                curve: OmniCurves.standard,
                child: RepaintBoundary(
                  child: _EditOnLongPress(
                    enabled: !appMode,
                    child: _ShellNavBar(
                      tabs: tabs,
                      more: more,
                      selectedIndex: selectedIndex,
                      onSelected: select,
                    ),
                  ),
                ),
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
  const _EditOnLongPress({required this.child, this.enabled = true});

  final Widget child;

  /// Tắt trong khung ứng dụng: thanh dưới theo ứng dụng, không tự chọn.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
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
    required this.more,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<ModuleNavEntry> tabs;

  /// Ô cuối ("Tất cả" / "Thêm"); null = không có ô cuối.
  final _MoreSlot? more;
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
            Icon(
              selected ? tabIconOf(destination) : tabIconLineOf(destination),
            ),
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
      // Hướng "iOS chuẩn" (26/11/2026), như thanh dưới: không ô nền; mục đang
      // chọn icon đặc + chữ mực navy, mục chưa chọn icon nét + chữ xám.
      useIndicator: false,
      selectedIconTheme: IconThemeData(
        color: scheme.onSurface,
        size: OmniIconSize.xl,
      ),
      unselectedIconTheme: IconThemeData(
        color: _tabInactiveIcon(context),
        size: OmniIconSize.xl,
      ),
      selectedLabelTextStyle: OmniType.micro.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: OmniType.micro.copyWith(
        color: _tabInactiveLabel(context),
        fontWeight: FontWeight.w500,
      ),
      // Logo chỉ ở đăng nhập và màn khởi động (spec iOS Q4) → rail không còn
      // logo ở đầu, chỉ chừa khoảng trống trên.
      leading: const SizedBox(height: OmniSpacing.lg),
      destinations: [
        for (final destination in tabs)
          NavigationRailDestination(
            icon: iconFor(destination, selected: false),
            selectedIcon: iconFor(destination, selected: true),
            label: Text(destination.label),
          ),
        if (more case final more?)
          NavigationRailDestination(
            icon: Icon(more.lineIcon),
            selectedIcon: Icon(more.icon),
            label: Text(more.label),
          ),
      ],
    );
  }
}

/// Thanh tab: viên kính nổi (một trong số ít chỗ còn giữ kính, spec phong
/// cách iOS 25/11/2026 §3.3). Hướng "iOS chuẩn" (duyệt 26/11/2026): icon +
/// nhãn ngắn; mục chưa chọn icon NÉT xám, mục đang chọn icon ĐẶC màu chính —
/// không viên nền (viên chọn màu nhạt từng làm thanh nặng và sát chữ).
class _ShellNavBar extends StatelessWidget {
  const _ShellNavBar({
    required this.tabs,
    required this.more,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<ModuleNavEntry> tabs;

  /// Ô cuối ("Tất cả" / "Thêm"); null = không có ô cuối.
  final _MoreSlot? more;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    // Viên kính nổi cách mép 16 (`liquid-glass-uiux.html`): nội dung cuộn
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
          padding: EdgeInsets.fromLTRB(16, 0, 16, bottom > 12 ? bottom : 12),
          child: OmniGlass(
            radius: ShellBarInset.pillHeight / 2,
            padding: const EdgeInsets.symmetric(horizontal: 8),
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
                  if (more case final more?)
                    Expanded(
                      child: _ShellNavItem.more(
                        slot: more,
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
       lineIcon = null;

  _ShellNavItem.more({
    required _MoreSlot slot,
    required this.selected,
    required this.onTap,
  }) : destination = null,
       label = slot.label,
       icon = slot.icon,
       lineIcon = slot.lineIcon;

  final ModuleNavEntry? destination;
  final String? label;
  final IconData? icon;
  final IconData? lineIcon;
  final bool selected;
  final VoidCallback onTap;

  static const double _iconBoxHeight = 30;
  static const double _labelGap = 4;
  static const double _labelHeight = 14;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    // iOS: mục đang chọn icon ĐẶC + nhãn màu MỰC NAVY (người dùng chọn
    // 26/11/2026 thay xanh: xanh để dành cho hành động); mục chưa chọn icon
    // NÉT xám, nhãn xám đậm hơn icon một bậc để chữ 11 vẫn đọc được. Đổi ngay,
    // không chuyển màu dần — như thanh tab iOS. Tối: mực sáng (onSurface).
    final iconColor = selected ? scheme.onSurface : _tabInactiveIcon(context);
    final labelColor = selected ? scheme.onSurface : _tabInactiveLabel(context);
    final destination = this.destination;
    final glyph = destination == null
        ? (selected ? icon! : lineIcon!)
        : (selected ? tabIconOf(destination) : tabIconLineOf(destination));
    final badgeProvider = destination?.badge;
    final count = badgeProvider == null ? 0 : ref.watch(badgeProvider);
    final text = destination == null ? label! : tabLabelOf(destination);
    // Đọc màn hình đọc tên đầy đủ ("Nhà cung cấp"), không phải nhãn ngắn.
    final fullName = destination?.label ?? text;

    final semanticsLabel = count <= 0
        ? fullName
        : destination?.badgeDisplay == NavBadgeDisplay.dot
        ? '$fullName, có tin chưa đọc'
        : '$fullName, $count';

    return Semantics(
      selected: selected,
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      // Không gợn, không tô khi rê chuột: iOS không có, và lớp tô hover của
      // Material trên web làm một mục trông "đậm" hơn các mục khác.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // Icon + nhãn ngắn (≤ 9 ký tự, `tabLabels`) — không thu nhỏ, không "…".
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 44,
              height: _iconBoxHeight,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Icon(glyph, size: 26, color: iconColor),
                  if (count > 0)
                    Positioned(
                      right: -2,
                      top: -3,
                      child: _NavBadge(
                        count: count,
                        tone: destination!.badgeTone,
                        display: destination.badgeDisplay,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: _labelGap),
            SizedBox(
              height: _labelHeight,
              child: Text(
                text,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                textScaler: TextScaler.noScaling,
                style: OmniType.micro.copyWith(
                  color: labelColor,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _tabInactiveIcon(BuildContext context) => OmniColors.byBrightness(
  context,
  OmniColors.tabInactiveIcon,
  OmniColors.darkTabInactiveIcon,
);

Color _tabInactiveLabel(BuildContext context) => OmniColors.byBrightness(
  context,
  OmniColors.tabInactiveLabel,
  OmniColors.darkTabInactiveLabel,
);

/// Ô cuối của thanh dưới: "Tất cả" (danh bạ, khi không có khung ứng dụng)
/// hoặc "Thêm" (sheet mục còn lại của ứng dụng đang mở).
class _MoreSlot {
  const _MoreSlot(this.label, this.icon, this.lineIcon);

  static const directory = _MoreSlot('Tất cả', tabIconAll, tabIconAllLine);

  static const app = _MoreSlot('Thêm', tabIconMore, tabIconMoreLine);

  final String label;

  /// Đặc khi đang chọn, nét khi chưa chọn.
  final IconData icon;
  final IconData lineIcon;
}

/// "Thêm" của một ứng dụng: mục chính ngoài 4 mục trên thanh dưới, rồi báo
/// cáo dưới nhãn nhỏ — một sheet nhóm lồng, chạm một lần là tới màn.
Future<void> _showAppMore(
  BuildContext context, {
  required ShellApp app,
  required String? currentRoute,
  required ValueChanged<ShellItem> onPick,
}) async {
  Widget row(BuildContext sheet, ShellItem item) => _AppMoreRow(
    item: item,
    selected: item.entry.routeName == currentRoute,
    onTap: () => Navigator.of(sheet).pop(item),
  );

  final picked = await showOmniSheet<ShellItem>(
    context: context,
    builder: (sheet) => OmniSheetBody(
      semanticsLabel: app.name,
      header: OmniSheetHeader(title: app.name),
      children: [
        if (app.more.isNotEmpty)
          OmniGroupSection(
            children: [for (final item in app.more) row(sheet, item)],
          ),
        if (app.reports.isNotEmpty)
          OmniGroupSection(
            title: 'Báo cáo',
            children: [for (final item in app.reports) row(sheet, item)],
          ),
      ],
    ),
  );
  if (picked != null) onPick(picked);
}

class _AppMoreRow extends ConsumerWidget {
  const _AppMoreRow({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final ShellItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = item.entry;
    final badge = entry.badge;
    final count = badge == null ? 0 : ref.watch(badge);
    return OmniGroupRow(
      key: ValueKey('app-more-${item.key}'),
      title: entry.label,
      icon: entry.icon,
      selected: selected,
      trailing: count > 0 && !selected
          ? _NavBadge(
              count: count,
              tone: entry.badgeTone,
              display: entry.badgeDisplay,
            )
          : null,
      onTap: onTap,
    );
  }
}
