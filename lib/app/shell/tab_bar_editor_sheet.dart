import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/module/module_registry.dart';
import '../../core/module/nav_destination.dart';
import '../../core/nav/tab_order.dart';
import '../../design/components/components.dart';
import '../../design/platform/omni_motion_scope.dart';
import '../../design/tokens/tokens.dart';

/// Mở màn "Sửa menu": người dùng tự chọn tối đa [maxTabs] tính năng cho thanh
/// dưới. Mở từ nút viền ở "Tất cả" hoặc nhấn giữ thanh dưới — thanh dưới không
/// mang nút nào ngoài các mục của nó.
Future<void> showTabBarEditor(BuildContext context) {
  HapticFeedback.mediumImpact();

  return showOmniSheet<void>(
    context: context,
    expand: true,
    useRootNavigator: true,
    builder: (_) => const TabBarEditor(),
  );
}

/// Nhóm trong màn sửa — trùng tên nhóm ở danh bạ "Tất cả".
String _groupOf(NavArea area) => switch (area) {
  NavArea.communication || NavArea.sales => 'Bán hàng',
  NavArea.work => 'Công việc',
  NavArea.admin => 'Đội & quản trị',
  NavArea.finance => 'Tài chính',
  NavArea.account => 'Cá nhân',
};

/// Nội dung màn "Sửa menu" (`01-shell-finance-settings.html` #1).
///
/// Đổi là áp ngay và tự lưu; "Xong" chỉ đóng tấm. Luôn còn ít nhất một mục —
/// một thanh chỉ có "Tất cả" là thanh hỏng.
class TabBarEditor extends ConsumerWidget {
  const TabBarEditor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final allowed = ref.watch(pinnableNavEntriesProvider);
    final tabs = ref.watch(tabEntriesProvider);
    final customised = ref.watch(tabPinsProvider).valueOrNull != null;
    final routes = [for (final t in tabs) t.routeName];
    final full = routes.length >= maxTabs;
    final rest = [
      for (final e in allowed)
        if (!routes.contains(e.routeName)) e,
    ];
    final groups = <String, List<ModuleNavEntry>>{};
    for (final e in rest) {
      groups.putIfAbsent(_groupOf(e.area), () => []).add(e);
    }

    void save(List<String> next) {
      HapticFeedback.selectionClick();
      ref.read(tabPinsProvider.notifier).save(next);
    }

    void move(int from, int to) {
      final next = [...routes];
      next.insert(to, next.removeAt(from));
      save(next);
    }

    return SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OmniSheetHeader(
            title: 'Thanh menu',
            trailing: _DonePill(
              label: 'Xong',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: _BarPreview(tabs: tabs),
          ),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  sliver: SliverToBoxAdapter(
                    child: _GroupTitle(
                      'Trên thanh · kéo để đổi chỗ',
                      trailing: '${routes.length}/$maxTabs',
                      trailingStrong: full,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  sliver: SliverToBoxAdapter(
                    child: Material(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      clipBehavior: Clip.antiAlias,
                      child: ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        itemCount: tabs.length,
                        proxyDecorator: (child, _, _) => Material(
                          color: scheme.surface,
                          elevation: 6,
                          borderRadius: BorderRadius.circular(14),
                          child: child,
                        ),
                        onReorderItem: move,
                        itemBuilder: (context, i) {
                          final entry = tabs[i];
                          return _SelectedRow(
                            key: ValueKey(entry.routeName),
                            index: i,
                            entry: entry,
                            showDivider: i > 0,
                            onRemove: tabs.length > 1
                                ? () => save([...routes]..removeAt(i))
                                : null,
                            onUp: i > 0 ? () => move(i, i - 1) : null,
                            onDown: i < tabs.length - 1
                                ? () => move(i, i + 1)
                                : null,
                          );
                        },
                      ),
                    ),
                  ),
                ),
                for (final MapEntry(key: label, value: entries)
                    in groups.entries)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      10,
                      OmniGroupSection.sheetGap,
                      10,
                      0,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: OmniGroupSection(
                        title: label,
                        dividerIndent: 54,
                        children: [
                          for (final e in entries)
                            _AvailableRow(
                              entry: e,
                              onAdd: full
                                  ? null
                                  : () => save([...routes, e.routeName]),
                            ),
                        ],
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: OmniSpacing.md),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
            child: Center(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onPressed: customised
                    ? () {
                        HapticFeedback.selectionClick();
                        ref.read(tabPinsProvider.notifier).reset();
                      }
                    : null,
                icon: const Icon(Icons.restart_alt_rounded, size: 16),
                label: const Text('Về mặc định'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Viên thuốc kính 'Xong' ở đầu sheet.
class _DonePill extends StatelessWidget {
  const _DonePill({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onPressed();
      },
      borderRadius: OmniRadius.pillAll,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        child: Center(
          child: DecoratedBox(
            decoration: OmniGlass.buttonDecoration(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              child: Text(
                label,
                style: OmniType.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ảnh thu nhỏ của thanh kính nổi dưới đáy: 4 ô + "Tất cả" cố định; ô trống viền đứt.
class _BarPreview extends StatelessWidget {
  const _BarPreview({required this.tabs});

  final List<ModuleNavEntry> tabs;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget slot({
      IconData? icon,
      String? label,
      bool active = false,
      bool fixed = false,
    }) {
      final fg = active
          ? scheme.primary
          : fixed
          ? scheme.onSurfaceVariant
          : scheme.onSurface;
      return Expanded(
        child: AnimatedSwitcher(
          duration: OmniMotion.of(context).base,
          child: Container(
            key: ValueKey(label),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            decoration: active
                ? BoxDecoration(
                    color: OmniGlass.selectionOf(context),
                    borderRadius: OmniRadius.pillAll,
                  )
                : null,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null)
                  Icon(icon, size: 19, color: fg)
                else
                  OmniDashedBox(
                    radius: OmniRadius.lg,
                    color: scheme.outline,
                    child: SizedBox.square(
                      dimension: 26,
                      child: Icon(
                        Icons.add_rounded,
                        size: 15,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (label != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: OmniType.micro.copyWith(
                      color: fg,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return ExcludeSemantics(
      child: OmniGlass(
        radius: OmniRadius.pill,
        blur: false,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              for (var i = 0; i < maxTabs; i++)
                if (i < tabs.length)
                  slot(icon: tabs[i].icon, label: tabs[i].label, active: i == 0)
                else
                  slot(),
              slot(
                icon: Icons.grid_view_outlined,
                label: 'Tất cả',
                fixed: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.label, {this.trailing, this.trailingStrong = false});

  final String label;
  final String? trailing;
  final bool trailingStrong;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = OmniType.caption.copyWith(
      fontWeight: FontWeight.w600,
      color: scheme.onSurfaceVariant,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
      child: Semantics(
        header: true,
        child: Row(
          children: [
            Expanded(child: Text(label, style: style)),
            if (trailing != null)
              Text(
                trailing!,
                style: style.copyWith(
                  fontFeatures: OmniType.tabular,
                  color: trailingStrong ? scheme.primary : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Nút tròn một tông 26px trong vùng chạm IconButton 44dp: "+" màu chính, "−" đỏ dịu.
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.primary = true,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final danger = OmniColors.dangerTextOf(context);
    final fg = primary ? scheme.primary : danger;
    final bg = fg.withValues(alpha: 0.12);
    final enabled = onPressed != null;

    return IconButton(
      tooltip: tooltip,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      icon: Opacity(
        opacity: enabled ? 1 : 0.32,
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
          child: Icon(icon, size: 16, color: fg),
        ),
      ),
    );
  }
}

class _SelectedRow extends StatelessWidget {
  const _SelectedRow({
    super.key,
    required this.index,
    required this.entry,
    required this.showDivider,
    required this.onRemove,
    required this.onUp,
    required this.onDown,
  });

  final int index;
  final ModuleNavEntry entry;
  final bool showDivider;
  final VoidCallback? onRemove;
  final VoidCallback? onUp;
  final VoidCallback? onDown;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: '${entry.label}, vị trí ${index + 1}',
      customSemanticsActions: {
        const CustomSemanticsAction(label: 'Lên'): ?onUp,
        const CustomSemanticsAction(label: 'Xuống'): ?onDown,
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDivider)
            Divider(
              height: 1,
              thickness: 1,
              indent: 54,
              color: scheme.outlineVariant.withValues(alpha: .7),
            ),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 50),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
              child: Row(
                children: [
                  OmniIconTile(entry.icon),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ExcludeSemantics(
                      child: Text(
                        entry.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: OmniType.body.copyWith(
                          fontWeight: FontWeight.w500,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  _RoundButton(
                    icon: Icons.remove_rounded,
                    tooltip: 'Bỏ ${entry.label} khỏi thanh menu',
                    primary: false,
                    onPressed: onRemove,
                  ),
                  ReorderableDragStartListener(
                    index: index,
                    child: Tooltip(
                      message: 'Kéo để đổi vị trí',
                      child: SizedBox(
                        width: 36,
                        height: 44,
                        child: Icon(
                          Icons.drag_handle_rounded,
                          size: 20,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailableRow extends StatelessWidget {
  const _AvailableRow({required this.entry, required this.onAdd});

  final ModuleNavEntry entry;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onAdd != null;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 50),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        child: Row(
          children: [
            Opacity(
              opacity: enabled ? 1 : 0.48,
              child: OmniIconTile(entry.icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Opacity(
                opacity: enabled ? 1 : 0.52,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: OmniType.body.copyWith(
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurface,
                      ),
                    ),
                    if (entry.subtitle case final sub?)
                      Text(
                        sub,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: OmniType.caption.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            _RoundButton(
              icon: Icons.add_rounded,
              tooltip: 'Thêm ${entry.label} vào thanh menu',
              onPressed: onAdd,
            ),
          ],
        ),
      ),
    );
  }
}
