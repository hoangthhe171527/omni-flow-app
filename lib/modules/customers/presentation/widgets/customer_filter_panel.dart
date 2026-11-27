import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/components/components.dart';
import '../../../../security/permissions/access_scope.dart';
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

  // Nút lọc chung của ô tìm (rà soát 26/11 mục 6): xám khi chưa lọc; đang
  // lọc thì thành viên mực/trắng kèm số — không còn icon xanh + huy hiệu đỏ.
  @override
  Widget build(BuildContext context) => OmniSearchFilterButton(
    onPressed: onTap,
    activeFilters: count,
    open: open,
    semanticsLabel: 'Bộ lọc',
    countKey: const Key('customer-filter-count'),
  );
}

/// Mở bộ lọc tại đúng nút đã chạm, cùng ngôn ngữ tương tác với menu avatar.
///
/// Bảng lọc thống nhất (duyệt 26/11/2026, rà soát mục 7): đầu "Lọc" + "Đặt
/// lại", thanh chọn "Khách hàng / Cơ hội" ([OmniSegmented]) ngay dưới, rồi
/// nhóm "HIỂN THỊ" với các chip viên mực đặc — bỏ danh sách dấu ✓ xanh. Đóng
/// bằng chạm ra ngoài.
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
      _FilterMenuHeader(segment: segment),
      if (segmentLabels.length > 1)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
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
      const OmniFilterGroupLabel(
        title: 'Hiển thị',
        padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
      ),
      filterContent,
      const SizedBox(height: 8),
    ],
  ),
);

/// Đầu bảng: "Lọc" + "Đặt lại". Đoạn Khách: đặt lại về mặc định của phạm vi
/// (`own` → "Của tôi", còn lại "Tất cả"); đoạn Cơ hội có bộ lọc riêng ở dải
/// giai đoạn nên nút mờ.
class _FilterMenuHeader extends ConsumerWidget {
  const _FilterMenuHeader({required this.segment});

  final int segment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(customerAccessProvider).readScope;
    final count = ref.watch(
      customerFilterProvider.select((f) => f.activeCountFor(scope)),
    );
    final canReset = segment == 0 && count > 0;
    return OmniFilterHeader(
      resetKey: const Key('customer-filter-reset'),
      onReset: canReset
          ? () => ref
                .read(customerFilterProvider.notifier)
                .setQuick(
                  scope == AccessScope.own
                      ? CustomerQuickFilter.mine
                      : CustomerQuickFilter.all,
                )
          : null,
    );
  }
}

/// Nội dung lọc riêng của danh sách khách, đặt trong popover chung của tab:
/// các chip viên mực đặc (chọn một).
class CustomerFilterMenuContent extends ConsumerWidget {
  const CustomerFilterMenuContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(customerFilterProvider);
    final controller = ref.read(customerFilterProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        children: [
          for (final quick in CustomerQuickFilter.values)
            OmniFilterPill(
              key: ValueKey('customer-filter-quick-${quick.name}'),
              label: quick.label,
              selected: filter.quick == quick,
              onTap: () => controller.setQuick(quick),
            ),
        ],
      ),
    );
  }
}
