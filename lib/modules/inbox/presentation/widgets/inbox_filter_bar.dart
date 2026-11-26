import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/components/components.dart';
import '../../application/inbox_providers.dart';
import '../../domain/inbox_filter.dart';
import '../inbox_page.dart';

/// Hàng tìm kiếm của hộp thư: ô tìm và nút bộ lọc có huy hiệu đếm.
///
/// Bộ lọc không còn là một dải chip luôn hiện; nút mở nó thành menu neo tại
/// nút ([showInboxFilterMenu]).
class InboxSearchRow extends ConsumerWidget implements PreferredSizeWidget {
  const InboxSearchRow({
    super.key,
    required this.filtersOpen,
    required this.onOpenFilters,
  });

  final bool filtersOpen;
  final ValueChanged<Rect> onOpenFilters;

  @override
  // Nằm trong viên kính của OmniTopBar: cao 44, lề ngang nhỏ.
  Size get preferredSize => const Size.fromHeight(44);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(inboxFilterProvider.select((f) => f.activeCount));

    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 0, 2, 0),
        child: Row(
          children: [
            const Expanded(child: _SearchField()),
            // Ô lọc rộng 44 mà vẽ 36: 4 mỗi bên đã nằm trong ô.
            const SizedBox(width: 4),
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
          ],
        ),
      ),
    );
  }
}

/// Ô tìm chuẩn (Chuẩn Mobile UI — SearchBar) theo bộ lọc hộp thư. "Xoá bộ
/// lọc" đặt lại cả khi `search` vốn rỗng (còn lượt gõ đang chờ) — ô được dựng
/// lại theo mỗi lần đặt lại để không giữ chữ cũ.
class _SearchField extends ConsumerWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context, WidgetRef ref) => KeyedSubtree(
    key: ValueKey(ref.watch(inboxFilterResetsProvider)),
    child: OmniSearchField(
      key: const Key('inbox-search-flat'),
      hint: 'Tìm khách, tin nhắn…',
      flat: true,
      dense: true,
      debounce: const Duration(milliseconds: 300),
      value: ref.watch(inboxFilterProvider.select((f) => f.search)),
      onChanged: ref.read(inboxFilterProvider.notifier).setSearch,
    ),
  );
}

/// Nút lọc phẳng 44×44, huy hiệu đỏ đếm số bộ lọc đang bật.
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
    countKey: const Key('inbox-filter-count'),
  );
}

/// Bộ lọc Hộp thư mở cạnh nút giống bộ lọc Khách: không đẩy danh sách xuống,
/// không làm header đổi chiều cao và vẫn giữ toàn bộ tiêu chí tại chỗ.
///
/// Bảng lọc thống nhất (duyệt 26/11/2026): đầu "Lọc" + "Đặt lại", nhãn nhóm
/// chữ HOA, lựa chọn là chip viên mực đặc. Đóng bằng chạm ra ngoài.
Future<void> showInboxFilterMenu({
  required BuildContext context,
  required Rect anchor,
}) => showOmniAnchoredMenu<void>(
  context: context,
  anchor: anchor,
  width: 344,
  menuKey: const Key('inbox-filter-menu'),
  semanticsLabel: 'Bộ lọc hộp thư',
  builder: (_) => const Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [_InboxFilterMenuHeader(), _PanelBody()],
  ),
);

class _InboxFilterMenuHeader extends ConsumerWidget {
  const _InboxFilterMenuHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(inboxFilterProvider.select((f) => f.activeCount));
    // "Đặt lại" luôn ở chỗ cũ, mờ khi chưa bật bộ lọc nào.
    return OmniFilterHeader(
      resetKey: const Key('inbox-filter-clear'),
      onReset: count > 0
          ? ref.read(inboxFilterProvider.notifier).clearFilters
          : null,
    );
  }
}

/// Các lựa chọn "Hiển thị" của Hộp thư theo quyền xem người phụ trách.
List<(InboxQuickFilter, String)> inboxQuickSegments(bool showsAssignee) => [
  (InboxQuickFilter.all, 'Tất cả'),
  (InboxQuickFilter.unread, 'Chưa đọc'),
  if (showsAssignee) (InboxQuickFilter.mine, 'Của tôi'),
  if (showsAssignee) (InboxQuickFilter.unassigned, 'Chưa gán'),
];

class _PanelBody extends ConsumerWidget {
  const _PanelBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(inboxFilterProvider);
    final controller = ref.read(inboxFilterProvider.notifier);
    final facets = ref.watch(inboxFacetsProvider).valueOrNull;
    final access = ref.watch(inboxAccessProvider);

    final segments = inboxQuickSegments(access.showsAssigneeFilter);

    final hasChannelList = facets != null && facets.channels.isNotEmpty;
    final channels = [
      for (final channel in inboxChannelOrder)
        if (!hasChannelList ||
            facets.channels[channel.slug] != null ||
            filter.channel == channel)
          channel,
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FilterSection(
            key: const Key('inbox-filter-section-scope'),
            label: 'Hiển thị',
            child: _QuickFilterGrid(
              items: segments,
              selected: filter.quick,
              onPick: controller.setQuick,
            ),
          ),
          if (channels.isNotEmpty) ...[
            _FilterSection(
              key: const Key('inbox-filter-section-channel'),
              label: 'Kênh',
              child: Wrap(
                spacing: 8,
                children: [
                  for (final channel in channels)
                    _ChoiceChip(
                      label: channel.meta.short,
                      selected: filter.channel == channel,
                      onTap: () => controller.setChannel(
                        filter.channel == channel ? null : channel,
                      ),
                    ),
                ],
              ),
            ),
          ],
          _FilterSection(
            key: const Key('inbox-filter-section-state'),
            label: 'Tình trạng',
            child: Wrap(
              spacing: 8,
              children: [
                _ChoiceChip(
                  label: 'Khẩn',
                  selected: filter.quick == InboxQuickFilter.urgent,
                  onTap: () => controller.setQuick(
                    filter.quick == InboxQuickFilter.urgent
                        ? InboxQuickFilter.all
                        : InboxQuickFilter.urgent,
                  ),
                ),
                _ChoiceChip(
                  label: 'Đã lưu trữ',
                  selected: filter.quick == InboxQuickFilter.closed,
                  onTap: () => controller.setQuick(
                    filter.quick == InboxQuickFilter.closed
                        ? InboxQuickFilter.all
                        : InboxQuickFilter.closed,
                  ),
                ),
                // Đường duy nhất tới "Bỏ chặn": hội thoại đã chặn ẩn khỏi
                // mọi danh sách khác. Không có số vì facet không đếm mục chặn.
                if (access.canBlock)
                  _ChoiceChip(
                    label: InboxQuickFilter.blocked.label,
                    selected: filter.quick == InboxQuickFilter.blocked,
                    onTap: () => controller.setQuick(
                      filter.quick == InboxQuickFilter.blocked
                          ? InboxQuickFilter.all
                          : InboxQuickFilter.blocked,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Nhãn nhóm chữ HOA 12/700 xám (bảng lọc thống nhất).
        OmniFilterGroupLabel(title: label),
        child,
      ],
    ),
  );
}

/// "Hiển thị" (chọn một): hàng chip chọn, không còn lưới radio nền xanh.
class _QuickFilterGrid extends StatelessWidget {
  const _QuickFilterGrid({
    required this.items,
    required this.selected,
    required this.onPick,
  });

  final List<(InboxQuickFilter, String)> items;
  final InboxQuickFilter selected;
  final ValueChanged<InboxQuickFilter> onPick;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    children: [
      for (final (filter, label) in items)
        KeyedSubtree(
          key: ValueKey('inbox-filter-quick-${filter.name}'),
          child: _ChoiceChip(
            label: label,
            selected: filter == selected,
            onTap: () => onPick(filter),
          ),
        ),
    ],
  );
}

/// Chip lựa chọn: viên mực đặc [OmniFilterPill] (duyệt 26/11/2026) — chọn =
/// nền mực chữ trắng (tối: nền trắng chữ đen), chưa chọn = nền xám nhạt. Viên
/// tự có vùng chạm 44.
class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) =>
      OmniFilterPill(label: label, selected: selected, onTap: onTap);
}
