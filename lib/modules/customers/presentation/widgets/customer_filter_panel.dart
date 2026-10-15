import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../application/customers_providers.dart';

/// Hàng tìm của danh sách khách: ô tìm, nút lọc (huy hiệu đếm) và các nút riêng
/// của màn (Thêm khách) xếp sau. Mẫu của `InboxSearchRow`.
class CustomerSearchRow extends ConsumerWidget implements PreferredSizeWidget {
  const CustomerSearchRow({
    super.key,
    required this.filtersOpen,
    this.onToggleFilters,
    this.onOpenFilters,
    this.trailing = const [],
  }) : assert(onToggleFilters != null || onOpenFilters != null);

  final bool filtersOpen;

  /// Callback cũ vẫn được giữ cho các màn độc lập. Tab Khách truyền
  /// [onOpenFilters] để menu có thể neo chính xác vào nút.
  final VoidCallback? onToggleFilters;
  final ValueChanged<Rect>? onOpenFilters;
  final List<Widget> trailing;

  @override
  Size get preferredSize => const Size.fromHeight(46);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(customerAccessProvider).readScope;
    final count = ref.watch(
      customerFilterProvider.select((f) => f.activeCountFor(scope)),
    );

    return SizedBox(
      height: 46,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
        child: Row(
          children: [
            const Expanded(child: _SearchField()),
            const SizedBox(width: 8),
            Builder(
              builder: (buttonContext) => _FilterButton(
                open: filtersOpen,
                count: count,
                onTap: () {
                  final anchored = onOpenFilters;
                  if (anchored == null) {
                    onToggleFilters?.call();
                    return;
                  }
                  final box = buttonContext.findRenderObject() as RenderBox?;
                  if (box == null || !box.hasSize) return;
                  anchored(box.localToGlobal(Offset.zero) & box.size);
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

class _SearchField extends ConsumerStatefulWidget {
  const _SearchField();

  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
  late final TextEditingController _controller;
  Timer? _debounce;

  /// Giá trị ô này đã đẩy lên bộ lọc gần nhất. `search` đổi thành giá trị khác
  /// nghĩa là bị đặt từ nơi khác (bộ lọc dựng lại khi quyền đổi).
  late String _sent;

  @override
  void initState() {
    super.initState();
    _sent = ref.read(customerFilterProvider).search;
    _controller = TextEditingController(text: _sent);
  }

  /// Huỷ lượt gõ đang chờ (không thì hẹn giờ cũ đặt lại chữ vừa bị xoá) và
  /// cho ô theo giá trị mới.
  void _external(String search) {
    _debounce?.cancel();
    _sent = search;
    if (_controller.text != search) {
      _controller.text = search;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _changed(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _sent = value;
      ref.read(customerFilterProvider.notifier).setSearch(value);
    });
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    setState(() {});
    _sent = '';
    ref.read(customerFilterProvider.notifier).setSearch('');
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(customerFilterProvider.select((f) => f.search), (
      _,
      next,
    ) {
      if (next != _sent) _external(next);
    });
    final scheme = Theme.of(context).colorScheme;
    final meta = scheme.onSurfaceVariant;

    return SizedBox(
      key: const Key('customer-search-flat'),
      height: 44,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: OmniIconSize.md, color: meta),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _controller,
                onChanged: _changed,
                textInputAction: TextInputAction.search,
                style: OmniType.search.copyWith(
                  color: scheme.onSurface,
                  fontStyle: FontStyle.normal,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintText: 'Tìm tên, số điện thoại',
                  hintStyle: OmniType.searchHint.copyWith(color: meta),
                ),
              ),
            ),
            if (_controller.text.isNotEmpty)
              IconButton(
                tooltip: 'Xoá tìm kiếm',
                onPressed: _clear,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 44,
                  height: 44,
                ),
                iconSize: OmniIconSize.md,
                color: meta,
                icon: const Icon(Icons.close_rounded),
              )
            else
              const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }
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
                    Icons.tune_rounded,
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
                            borderRadius: BorderRadius.circular(8),
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
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Row(
            children: [
              for (var i = 0; i < segmentLabels.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _SegmentChoice(
                    label: segmentLabels[i],
                    selected: segment == i,
                    onTap: () {
                      if (i == segment) return;
                      Navigator.of(menuContext).pop();
                      onSegmentChanged(i);
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
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
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.only(left: 16, right: 6),
      color: scheme.surfaceContainerLow.withValues(alpha: .7),
      child: Row(
        children: [
          Icon(
            Icons.tune_rounded,
            size: OmniIconSize.md,
            color: scheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Bộ lọc',
              style: OmniType.bodyStrong.copyWith(color: scheme.onSurface),
            ),
          ),
          IconButton(
            tooltip: 'Đóng bộ lọc',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
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

class _SegmentChoice extends StatelessWidget {
  const _SegmentChoice({
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
    return Material(
      color: selected ? scheme.primaryContainer : scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: OmniRadius.mdAll,
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: OmniRadius.mdAll,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: OmniType.caption.copyWith(
                      color: selected
                          ? scheme.onPrimaryContainer
                          : scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
              onTap: () => controller.setQuick(quick),
            ),
        ],
      ),
    );
  }
}

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
    return Material(
      color: selected
          ? scheme.primary.withValues(alpha: .08)
          : Colors.transparent,
      borderRadius: OmniRadius.mdAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: OmniRadius.mdAll,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: OmniType.body.copyWith(
                      color: scheme.onSurface,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: OmniIconSize.md,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
