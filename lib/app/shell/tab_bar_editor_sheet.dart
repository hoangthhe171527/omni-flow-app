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
import 'directory_page.dart' show hueOfArea;

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
  NavArea.account => 'Cá nhân',
};

/// Nội dung màn "Sửa menu" (`menu-tuy-chon-uiux.html`, đã duyệt 06/11).
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
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              OmniSpacing.lg,
              OmniSpacing.md,
              OmniSpacing.lg,
              OmniSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      'Thanh menu',
                      style: OmniType.title.copyWith(color: scheme.onSurface),
                    ),
                  ),
                ),
                _OutlineButton(
                  label: 'Xong',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: OmniSpacing.lg),
            child: _BarPreview(tabs: tabs),
          ),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: OmniSpacing.lg,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _SectionLabel(
                      'Trên thanh',
                      trailing: '${routes.length}/$maxTabs',
                      trailingStrong: full,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: OmniSpacing.lg,
                  ),
                  sliver: SliverReorderableList(
                    itemCount: tabs.length,
                    proxyDecorator: (child, _, _) => Material(
                      color: scheme.surface,
                      elevation: 6,
                      borderRadius: OmniRadius.lgAll,
                      child: child,
                    ),
                    onReorderItem: move,
                    itemBuilder: (context, i) {
                      final entry = tabs[i];
                      return _SelectedRow(
                        key: ValueKey(entry.routeName),
                        index: i,
                        entry: entry,
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
                for (final MapEntry(key: label, value: entries)
                    in groups.entries)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: OmniSpacing.lg,
                    ),
                    sliver: SliverList.list(
                      children: [
                        _SectionLabel(label),
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
                const SliverToBoxAdapter(
                  child: SizedBox(height: OmniSpacing.lg),
                ),
              ],
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: scheme.outlineVariant)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: OmniSpacing.xs),
              child: Center(
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.onSurfaceVariant,
                  ),
                  onPressed: customised
                      ? () {
                          HapticFeedback.selectionClick();
                          ref.read(tabPinsProvider.notifier).reset();
                        }
                      : null,
                  child: const Text('Về mặc định'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nút viền màu chính, không tô đặc (gu đã duyệt); cao 36, vùng chạm 48.
class _OutlineButton extends StatelessWidget {
  const _OutlineButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: OmniSpacing.lg),
        side: BorderSide(color: primary, width: 1.5),
        shape: const StadiumBorder(),
        tapTargetSize: MaterialTapTargetSize.padded,
        textStyle: OmniType.bodyStrong,
      ),
      child: Text(label),
    );
  }
}

/// Ảnh thu nhỏ của thanh dưới: 4 ô + "Tất cả" cố định; ô trống viền đứt.
class _BarPreview extends StatelessWidget {
  const _BarPreview({required this.tabs});

  final List<ModuleNavEntry> tabs;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget slot({IconData? icon, String? label, bool fixed = false}) {
      final color = fixed ? scheme.onSurfaceVariant : scheme.primary;
      return Expanded(
        child: AnimatedSwitcher(
          duration: OmniMotion.of(context).base,
          child: Column(
            key: ValueKey(label),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null)
                Icon(icon, size: 20, color: color)
              else
                OmniDashedBox(
                  radius: OmniRadius.lg,
                  color: scheme.outline,
                  child: SizedBox.square(
                    dimension: 28,
                    child: Icon(
                      Icons.add_rounded,
                      size: 16,
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
                    color: fixed ? scheme.onSurfaceVariant : scheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ExcludeSemantics(
      child: Container(
        height: 62,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: OmniRadius.xxlAll,
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            for (var i = 0; i < maxTabs; i++)
              if (i < tabs.length)
                slot(icon: tabs[i].icon, label: tabs[i].label)
              else
                slot(),
            slot(icon: Icons.grid_view_outlined, label: 'Tất cả', fixed: true),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, {this.trailing, this.trailingStrong = false});

  final String label;
  final String? trailing;
  final bool trailingStrong;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = OmniType.overline.copyWith(color: scheme.onSurfaceVariant);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 6),
      child: Semantics(
        header: true,
        child: Row(
          children: [
            Expanded(child: Text(label.toUpperCase(), style: style)),
            if (trailing != null)
              Text(
                trailing!,
                style: style.copyWith(
                  letterSpacing: 0,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: trailingStrong ? scheme.primary : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FeatureIcon extends StatelessWidget {
  const _FeatureIcon({required this.entry});

  final ModuleNavEntry entry;

  @override
  Widget build(BuildContext context) {
    final tone = OmniFeatureTones.of(context, hueOfArea(entry.area));

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: OmniRadius.xlAll,
      ),
      child: Icon(entry.icon, size: 19, color: tone.foreground),
    );
  }
}

/// Nút tròn viền 32 (vùng chạm 48): "+" màu chính, "−" xám.
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
    final color = primary ? scheme.primary : scheme.onSurfaceVariant;
    final border = primary ? scheme.primary : scheme.outline;
    final enabled = onPressed != null;

    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Opacity(
        opacity: enabled ? 1 : 0.32,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: border, width: 1.5),
          ),
          child: Icon(icon, size: 20, color: color),
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
    required this.onRemove,
    required this.onUp,
    required this.onDown,
  });

  final int index;
  final ModuleNavEntry entry;
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
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: Tooltip(
                message: 'Kéo để đổi vị trí',
                child: SizedBox(
                  width: 36,
                  height: 48,
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            _FeatureIcon(entry: entry),
            const SizedBox(width: OmniSpacing.md),
            Expanded(
              child: ExcludeSemantics(
                child: Text(
                  entry.label,
                  maxLines: 1,
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
          ],
        ),
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

    return SizedBox(
      height: 60,
      child: Row(
        children: [
          Opacity(
            opacity: enabled ? 1 : 0.45,
            child: _FeatureIcon(entry: entry),
          ),
          const SizedBox(width: OmniSpacing.md),
          Expanded(
            child: Opacity(
              opacity: enabled ? 1 : 0.45,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: OmniType.body.copyWith(
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurface,
                    ),
                  ),
                  if (entry.subtitle case final sub?)
                    Text(
                      sub,
                      maxLines: 1,
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
    );
  }
}
