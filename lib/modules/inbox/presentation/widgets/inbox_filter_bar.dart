import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/components/components.dart';
import '../../../../design/platform/omni_motion_scope.dart';
import '../../../../design/tokens/tokens.dart';
import '../../application/inbox_providers.dart';
import '../../domain/inbox_filter.dart';
import '../inbox_page.dart';

Duration _fade(BuildContext context) =>
    OmniMotion.enabled(context) ? kThemeChangeDuration : Duration.zero;

/// Giảm chuyển động: bỏ cả gợn mực lẫn lớp sáng khi chạm, không chỉ thời lượng.
InteractiveInkFeatureFactory? _splash(BuildContext context) =>
    OmniMotion.enabled(context) ? null : NoSplash.splashFactory;

Color? _highlight(BuildContext context) =>
    OmniMotion.enabled(context) ? null : Colors.transparent;

/// Hàng tìm kiếm của hộp thư: ô tìm và nút bộ lọc có huy hiệu đếm.
///
/// Bộ lọc không còn là một dải chip luôn hiện; tab Hộp thư mở nó thành menu
/// neo tại nút. [InboxFilterPanel] chỉ còn cho màn nhúng cũ tương thích.
class InboxSearchRow extends ConsumerWidget implements PreferredSizeWidget {
  const InboxSearchRow({
    super.key,
    required this.filtersOpen,
    this.onToggleFilters,
    this.onOpenFilters,
  }) : assert(onToggleFilters != null || onOpenFilters != null);

  final bool filtersOpen;
  final VoidCallback? onToggleFilters;
  final ValueChanged<Rect>? onOpenFilters;

  @override
  Size get preferredSize => const Size.fromHeight(46);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(inboxFilterProvider.select((f) => f.activeCount));

    return SizedBox(
      height: 46,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
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
  /// nghĩa là bị đặt từ nơi khác.
  late String _sent;

  @override
  void initState() {
    super.initState();
    _sent = ref.read(inboxFilterProvider).search;
    _controller = TextEditingController(text: _sent);
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
      ref.read(inboxFilterProvider.notifier).setSearch(value);
    });
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    setState(() {});
    _sent = '';
    ref.read(inboxFilterProvider.notifier).setSearch('');
  }

  /// Bộ lọc bị đặt từ nơi khác: huỷ lượt gõ đang chờ (không thì hẹn giờ cũ
  /// đặt lại chữ vừa bị xoá) và cho ô theo giá trị mới.
  void _external(String search) {
    _debounce?.cancel();
    _sent = search;
    if (_controller.text != search) {
      _controller.text = search;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(inboxFilterProvider.select((f) => f.search), (_, next) {
      if (next != _sent) _external(next);
    });
    // "Xoá bộ lọc" đặt lại cả khi `search` vốn rỗng — lúc đó listener trên
    // không chạy mà vẫn có thể còn lượt gõ đang chờ.
    ref.listen<int>(inboxFilterResetsProvider, (_, _) => _external(''));

    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      key: const Key('inbox-search-flat'),
      height: 44,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              size: OmniIconSize.md,
              color: scheme.onSurfaceVariant,
            ),
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
                  hintText: 'Tìm khách, tin nhắn…',
                  hintStyle: OmniType.searchHint.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
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
                color: scheme.onSurfaceVariant,
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Bộ lọc',
      expanded: open,
      excludeSemantics: true,
      onTap: onTap,
      // Hình 36, vùng chạm 44: lớp ngoài bắt chạm cả phần đệm.
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
                          key: const Key('inbox-filter-count'),
                          constraints: const BoxConstraints(minWidth: 16),
                          height: 16,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: OmniColors.destructive,
                            borderRadius: BorderRadius.circular(8),
                            // Vòng tách huy hiệu khỏi nút: cùng màu nền nút.
                            border: Border.all(
                              color: scheme.surface,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            '$count',
                            style: OmniType.micro.copyWith(
                              color: scheme.onError,
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

/// Bộ lọc Hộp thư mở cạnh nút giống bộ lọc Khách: không đẩy danh sách xuống,
/// không làm header đổi chiều cao và vẫn giữ toàn bộ tiêu chí tại chỗ.
Future<void> showInboxFilterMenu({
  required BuildContext context,
  required Rect anchor,
}) => showOmniAnchoredMenu<void>(
  context: context,
  anchor: anchor,
  width: 344,
  menuKey: const Key('inbox-filter-menu'),
  semanticsLabel: 'Bộ lọc hộp thư',
  builder: (menuContext) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _InboxFilterMenuHeader(onClose: () => Navigator.of(menuContext).pop()),
      const _PanelBody(inMenu: true),
    ],
  ),
);

class _InboxFilterMenuHeader extends ConsumerWidget {
  const _InboxFilterMenuHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final count = ref.watch(inboxFilterProvider.select((f) => f.activeCount));
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
              'Lọc hội thoại',
              style: OmniType.bodyStrong.copyWith(color: scheme.onSurface),
            ),
          ),
          if (count > 0)
            TextButton(
              key: const Key('inbox-filter-clear'),
              onPressed: ref.read(inboxFilterProvider.notifier).clearFilters,
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Đặt lại'),
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

/// Panel bộ lọc trượt xuống dưới header. Các lựa chọn được chia thành ba nhóm
/// theo đúng mô hình người dùng: phạm vi hiển thị, kênh và tình trạng đặc biệt.
///
/// Đóng thì không dựng nội dung nên cao 0; mở/đóng chạy `AnimatedSize`, và
/// "giảm chuyển động" của hệ điều hành đưa mọi thời lượng về 0.
class InboxFilterPanel extends ConsumerWidget {
  const InboxFilterPanel({super.key, required this.open});

  final bool open;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Giảm chuyển động: dựng thẳng, không qua AnimatedSize. Thời lượng 0 vẫn
    // chạy một lượt controller ngay trong lúc bố cục và RenderAnimatedSize
    // ném lỗi "mutated in its own performLayout".
    if (!OmniMotion.enabled(context)) {
      return open ? const _PanelBody() : const SizedBox(width: double.infinity);
    }

    // Mở: trượt xuống 400ms và nội dung hiện dần 300ms. Đóng: nội dung gỡ ngay,
    // chiều cao co lại theo AnimatedSize.
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
  const _PanelBody({this.inMenu = false});

  final bool inMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(inboxFilterProvider);
    final controller = ref.read(inboxFilterProvider.notifier);
    final facets = ref.watch(inboxFacetsProvider).valueOrNull;
    final access = ref.watch(inboxAccessProvider);

    final segments = <(InboxQuickFilter, String)>[
      (InboxQuickFilter.all, 'Tất cả'),
      (InboxQuickFilter.unread, 'Chưa đọc'),
      if (access.showsAssigneeFilter) (InboxQuickFilter.mine, 'Của tôi'),
      if (access.showsAssigneeFilter) (InboxQuickFilter.unassigned, 'Chưa gán'),
    ];

    final hasChannelList = facets != null && facets.channels.isNotEmpty;
    final channels = [
      for (final channel in inboxChannelOrder)
        if (!hasChannelList ||
            facets.channels[channel.slug] != null ||
            filter.channel == channel)
          channel,
    ];

    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, inMenu ? 0 : 4, 16, 12),
      decoration: inMenu
          ? null
          : BoxDecoration(
              color: scheme.surface,
              border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
            ),
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
                runSpacing: 8,
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
              runSpacing: 8,
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
          // Gỡ MỌI thứ huy hiệu đếm — cả tài khoản kênh và nhãn, vốn không có
          // chip riêng trong panel. Menu đặt hành động này trên header để gọn;
          // panel nhúng cũ vẫn giữ nó ở cuối.
          if (!inMenu && filter.activeCount > 0)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('inbox-filter-clear'),
                onPressed: controller.clearFilters,
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                child: const Text('Xoá bộ lọc'),
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
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            label,
            style: OmniType.overline.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        child,
      ],
    ),
  );
}

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
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final itemWidth = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final (filter, label) in items)
              SizedBox(
                key: ValueKey('inbox-filter-quick-${filter.name}'),
                width: itemWidth,
                child: _QuickFilterChoice(
                  label: label,
                  selected: filter == selected,
                  onTap: () => onPick(filter),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _QuickFilterChoice extends StatelessWidget {
  const _QuickFilterChoice({
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
      child: Material(
        animationDuration: _fade(context),
        color: selected
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: OmniRadius.mdAll,
        child: InkWell(
          splashFactory: _splash(context),
          highlightColor: _highlight(context),
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
                      maxLines: 1,
                      style: OmniType.caption.copyWith(
                        color: scheme.onSurface,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    size: 18,
                    color: selected ? scheme.primary : scheme.onSurfaceVariant,
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
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        animationDuration: _fade(context),
        color: selected ? scheme.primaryContainer : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: OmniRadius.chipAll,
          side: BorderSide(color: selected ? scheme.primary : scheme.outline),
        ),
        child: InkWell(
          splashFactory: _splash(context),
          highlightColor: _highlight(context),
          onTap: onTap,
          customBorder: RoundedRectangleBorder(
            borderRadius: OmniRadius.chipAll,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected) ...[
                    Icon(Icons.check_rounded, size: 16, color: scheme.primary),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: OmniType.caption.copyWith(
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? scheme.primary : scheme.onSurface,
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
