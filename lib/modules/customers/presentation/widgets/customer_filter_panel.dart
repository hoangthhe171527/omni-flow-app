import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/components/components.dart';
import '../../../../design/platform/omni_motion_scope.dart';
import '../../../../design/tokens/tokens.dart';
import '../../application/customers_providers.dart';

/// Hàng tìm của danh sách khách: ô tìm, nút lọc (huy hiệu đếm) và các nút riêng
/// của màn (Thêm khách) xếp sau. Mẫu của `InboxSearchRow`.
class CustomerSearchRow extends ConsumerWidget implements PreferredSizeWidget {
  const CustomerSearchRow({
    super.key,
    required this.filtersOpen,
    required this.onToggleFilters,
    this.trailing = const [],
  });

  final bool filtersOpen;
  final VoidCallback onToggleFilters;
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
            _FilterButton(
              open: filtersOpen,
              count: count,
              onTap: onToggleFilters,
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

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(customerFilterProvider).search,
    );
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
      if (mounted) ref.read(customerFilterProvider.notifier).setSearch(value);
    });
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    setState(() {});
    ref.read(customerFilterProvider.notifier).setSearch('');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final meta = scheme.onSurfaceVariant;

    return Container(
      height: 44,
      padding: const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: OmniIconSize.md, color: meta),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: _changed,
              textInputAction: TextInputAction.search,
              style: OmniType.input.copyWith(color: scheme.onSurface),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'Tìm tên, số điện thoại',
                hintStyle: OmniType.input.copyWith(color: meta),
              ),
            ),
          ),
          if (_controller.text.isNotEmpty)
            IconButton(
              tooltip: 'Xoá tìm kiếm',
              onPressed: _clear,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              iconSize: OmniIconSize.md,
              color: meta,
              icon: const Icon(Icons.close_rounded),
            )
          else
            const SizedBox(width: 10),
        ],
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
    final motion = OmniMotion.enabled(context);

    return Semantics(
      button: true,
      label: 'Bộ lọc',
      expanded: open,
      excludeSemantics: true,
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            animationDuration: motion ? kThemeChangeDuration : Duration.zero,
            color: open ? scheme.onSurface : scheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              side: BorderSide(
                color: open ? scheme.onSurface : scheme.outlineVariant,
              ),
            ),
            child: InkWell(
              splashFactory: motion ? null : NoSplash.splashFactory,
              highlightColor: motion ? null : Colors.transparent,
              onTap: onTap,
              customBorder: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              child: SizedBox.square(
                dimension: 36,
                child: Icon(
                  Icons.tune_rounded,
                  size: OmniIconSize.md,
                  color: open ? scheme.surface : scheme.onSurface,
                ),
              ),
            ),
          ),
          // Số luôn hiện (kể cả 0) để người dùng thấy bộ lọc đang ở mặc định.
          Positioned(
            right: -4,
            top: -4,
            child: IgnorePointer(
              child: Container(
                key: const Key('customer-filter-count'),
                constraints: const BoxConstraints(minWidth: 16),
                height: 16,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: count > 0
                      ? OmniColors.destructive
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: scheme.surface, width: 1.5),
                ),
                child: Text(
                  '$count',
                  style: OmniType.micro.copyWith(
                    color: count > 0 ? Colors.white : scheme.onSurfaceVariant,
                    height: 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Panel bộ lọc trượt xuống dưới header: các viên lọc nhanh của
/// [CustomerQuickFilter]. Đóng thì cao 0.
class CustomerFilterPanel extends ConsumerWidget {
  const CustomerFilterPanel({super.key, required this.open});

  final bool open;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!OmniMotion.enabled(context)) {
      return open ? const _PanelBody() : const SizedBox(width: double.infinity);
    }
    return AnimatedSize(
      duration: const Duration(milliseconds: 400),
      curve: OmniCurves.standard,
      alignment: Alignment.topCenter,
      child: open
          ? TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 300),
              builder: (context, value, child) =>
                  Opacity(opacity: value, child: child),
              child: const _PanelBody(),
            )
          : const SizedBox(width: double.infinity),
    );
  }
}

class _PanelBody extends ConsumerWidget {
  const _PanelBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final filter = ref.watch(customerFilterProvider);
    final controller = ref.read(customerFilterProvider.notifier);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final quick in CustomerQuickFilter.values)
            OmniFilterPill(
              label: quick.label,
              selected: filter.quick == quick,
              onTap: () => controller.setQuick(quick),
            ),
        ],
      ),
    );
  }
}
