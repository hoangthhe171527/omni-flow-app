import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../application/customers_providers.dart';

/// Hàng tìm của danh sách khách: ô tìm, nút lọc (huy hiệu đếm) và các nút riêng
/// của màn (Thêm khách) xếp sau. Mẫu của `InboxSearchRow`.
class CustomerSearchRow extends ConsumerWidget implements PreferredSizeWidget {
  const CustomerSearchRow({
    super.key,
    required this.filtersOpen,
    required this.onOpenFilters,
    this.trailing = const [],
  });

  final bool filtersOpen;

  /// Nhận khung của nút lọc để menu lọc neo đúng vào nút.
  final ValueChanged<Rect> onOpenFilters;
  final List<Widget> trailing;

  @override
  // Nằm trong viên kính của OmniTopBar: cao 44, lề ngang nhỏ.
  Size get preferredSize => const Size.fromHeight(44);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(customerAccessProvider).readScope;
    final count = ref.watch(
      customerFilterProvider.select((f) => f.activeCountFor(scope)),
    );

    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 0, 2, 0),
        child: Row(
          children: [
            const Expanded(child: _SearchField()),
            const SizedBox(width: 8),
            Builder(
              builder: (buttonContext) => _FilterButton(
                open: filtersOpen,
                count: count,
                onTap: () {
                  HapticFeedback.selectionClick();
                  final box = buttonContext.findRenderObject() as RenderBox?;
                  if (box == null || !box.hasSize) return;
                  onOpenFilters(box.localToGlobal(Offset.zero) & box.size);
                },
              ),
            ),
            ...trailing,
          ],
        ),
      ),
    );
  }
}

/// Ô tìm chuẩn (Chuẩn Mobile UI — SearchBar) theo bộ lọc khách: bộ lọc bị đặt
/// lại / quyền đổi thì ô theo giá trị mới, huỷ lượt gõ đang chờ.
class _SearchField extends ConsumerWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context, WidgetRef ref) => OmniSearchField(
    key: const Key('customer-search-flat'),
    hint: 'Tìm tên, số điện thoại',
    flat: true,
    dense: true,
    debounce: const Duration(milliseconds: 300),
    value: ref.watch(customerFilterProvider.select((f) => f.search)),
    onChanged: ref.read(customerFilterProvider.notifier).setSearch,
  );
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.open,
    required this.count,
    required this.onTap,
  });

  final bool open;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Icon phẳng, vùng chạm 44. Trạng thái mở được thể hiện bằng màu thay vì
    // dựng thêm một ô vuông quanh hành động.
    return Semantics(
      button: true,
      label: 'Bộ lọc',
      expanded: open,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: 44,
          child: Material(
            color: Colors.transparent,
            child: InkResponse(
              onTap: onTap,
              radius: 22,
              containedInkWell: true,
              highlightShape: BoxShape.circle,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    LucideIcons.slidersHorizontal,
                    size: OmniIconSize.md,
                    color: open ? scheme.primary : scheme.onSurface,
                  ),
                  if (count > 0)
                    Positioned(
                      right: 2,
                      top: 2,
                      child: IgnorePointer(
                        child: Container(
                          key: const Key('customer-filter-count'),
                          constraints: const BoxConstraints(minWidth: 16),
                          height: 16,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: OmniColors.destructive,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: scheme.surface,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            '$count',
                            style: OmniType.micro.copyWith(
                              color: Colors.white,
                              height: 1,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Mở bộ lọc tại đúng nút đã chạm, cùng ngôn ngữ tương tác với menu avatar.
/// Loại dữ liệu và tiêu chí lọc nằm chung một nơi nhưng được chia section để
/// không lẫn hai cấp quyết định.
Future<void> showCustomerFilterMenu({
  required BuildContext context,
  required Rect anchor,
  required int segment,
  required List<String> segmentLabels,
  required ValueChanged<int> onSegmentChanged,
  required Widget filterContent,
}) => showOmniAnchoredMenu<void>(
  context: context,
  anchor: anchor,
  width: 320,
  menuKey: const Key('customer-filter-menu'),
  semanticsLabel: 'Bộ lọc khách hàng',
  builder: (menuContext) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _FilterMenuHeader(onClose: () => Navigator.of(menuContext).pop()),
      if (segmentLabels.length > 1) ...[
        const _MenuSectionLabel(label: 'Loại dữ liệu'),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: OmniSegmented(
            labels: segmentLabels,
            index: segment,
            onChanged: (i) {
              if (i == segment) return;
              Navigator.of(menuContext).pop();
              onSegmentChanged(i);
            },
          ),
        ),
      ],
      const _MenuSectionLabel(label: 'Hiển thị'),
      filterContent,
      const SizedBox(height: 8),
    ],
  ),
);

class _FilterMenuHeader extends StatelessWidget {
  const _FilterMenuHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.only(left: 16, right: 8, top: 8, bottom: 4),
      child: Row(
        children: [
          Icon(
            LucideIcons.slidersHorizontal,
            size: OmniIconSize.md,
            color: scheme.onSurface,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Bộ lọc',
              style: OmniType.bodyStrong.copyWith(color: scheme.onSurface),
            ),
          ),
          // Nút đóng của menu (icon trơn, spec phong cách iOS §3.1).
          OmniGlassCircle(
            child: IconButton(
              tooltip: 'Đóng bộ lọc',
              onPressed: onClose,
              icon: const Icon(LucideIcons.x),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuSectionLabel extends StatelessWidget {
  const _MenuSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: Text(
      label,
      style: OmniType.overline.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

/// Nội dung lọc riêng của danh sách khách, đặt trong popover chung của tab.
class CustomerFilterMenuContent extends ConsumerWidget {
  const CustomerFilterMenuContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(customerFilterProvider);
    final controller = ref.read(customerFilterProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final quick in CustomerQuickFilter.values)
            _FilterMenuRow(
              label: quick.label,
              selected: filter.quick == quick,
              onTap: () {
                HapticFeedback.selectionClick();
                controller.setQuick(quick);
              },
            ),
        ],
      ),
    );
  }
}

/// Dòng "Hiển thị" (chọn một): chọn = ✓ xanh cuối dòng, không tô cả dòng,
/// không vòng radio (spec phong cách iOS §3.4).
class _FilterMenuRow extends StatelessWidget {
  const _FilterMenuRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            customBorder: RoundedRectangleBorder(
              borderRadius: OmniRadius.mdAll,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: OmniType.body.copyWith(
                          color: scheme.onSurface,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (selected)
                      Icon(
                        LucideIcons.check,
                        size: OmniIconSize.md,
                        color: scheme.primary,
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
