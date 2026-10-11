import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Hàng tìm kiếm của hộp thư: ô tìm, nút bộ lọc (có huy hiệu đếm) và các nút
/// riêng của màn (kết nối kênh, chọn nhiều) xếp sau.
///
/// Bộ lọc không còn là một dải chip luôn hiện; nó gom sau nút này và trượt
/// xuống thành [InboxFilterPanel] khi cần.
class InboxSearchRow extends ConsumerWidget implements PreferredSizeWidget {
  const InboxSearchRow({
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
    return Container(
      height: 36,
      padding: const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: scheme.outlineVariant),
      ),
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
              style: OmniType.input.copyWith(color: scheme.onSurface),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'Tìm khách, tin nhắn…',
                hintStyle: OmniType.input.copyWith(
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
              constraints: const BoxConstraints.tightFor(width: 32, height: 36),
              iconSize: OmniIconSize.md,
              color: scheme.onSurfaceVariant,
              icon: const Icon(Icons.close_rounded),
            )
          else
            const SizedBox(width: 10),
        ],
      ),
    );
  }
}

/// Nút lọc 36×36: nền ink khi panel mở, huy hiệu đỏ đếm số bộ lọc đang bật.
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
    // Mở: nền đảo màu (mực trên giao diện sáng, chữ sáng trên giao diện tối).
    final ink = scheme.onSurface;
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
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Material(
                  animationDuration: _fade(context),
                  color: open ? ink : scheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: BorderSide(color: open ? ink : scheme.outlineVariant),
                  ),
                  child: InkWell(
                    splashFactory: _splash(context),
                    highlightColor: _highlight(context),
                    onTap: onTap,
                    customBorder: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: SizedBox.square(
                      dimension: 36,
                      child: Icon(
                        Icons.tune_rounded,
                        size: OmniIconSize.md,
                        color: open ? scheme.surface : ink,
                      ),
                    ),
                  ),
                ),
                if (count > 0)
                  Positioned(
                    right: -4,
                    top: -4,
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
                          border: Border.all(color: scheme.surface, width: 1.5),
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
    );
  }
}

/// Panel bộ lọc trượt xuống dưới header: thanh chia đoạn theo người phụ trách,
/// chip kênh (chọn một) và chip trạng thái (Khẩn / Đã lưu trữ).
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
  const _PanelBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(inboxFilterProvider);
    final controller = ref.read(inboxFilterProvider.notifier);
    final facets = ref.watch(inboxFacetsProvider).valueOrNull;
    final access = ref.watch(inboxAccessProvider);

    final unread = facets?.unread ?? 0;
    final segments = <(InboxQuickFilter, String)>[
      (InboxQuickFilter.all, 'Tất cả'),
      (InboxQuickFilter.unread, unread > 0 ? 'Chưa đọc · $unread' : 'Chưa đọc'),
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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Segments(
            items: segments,
            selected: filter.quick,
            onPick: controller.setQuick,
          ),
          if (channels.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final channel in channels)
                  _Chip(
                    label: channel.meta.short,
                    selected: filter.channel == channel,
                    onTap: () => controller.setChannel(
                      filter.channel == channel ? null : channel,
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Chip(
                label: 'Khẩn',
                selected: filter.quick == InboxQuickFilter.urgent,
                onTap: () => controller.setQuick(
                  filter.quick == InboxQuickFilter.urgent
                      ? InboxQuickFilter.all
                      : InboxQuickFilter.urgent,
                ),
              ),
              _Chip(
                label: 'Đã lưu trữ',
                selected: filter.quick == InboxQuickFilter.closed,
                onTap: () => controller.setQuick(
                  filter.quick == InboxQuickFilter.closed
                      ? InboxQuickFilter.all
                      : InboxQuickFilter.closed,
                ),
              ),
              // Đường duy nhất tới "Bỏ chặn": hội thoại đã chặn ẩn khỏi mọi
              // danh sách khác. Không có số — facet không đếm hội thoại chặn.
              if (access.canBlock)
                _Chip(
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
          // Gỡ MỌI thứ huy hiệu đếm — cả tài khoản kênh và nhãn, vốn không có
          // chip riêng trong panel.
          if (filter.activeCount > 0)
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

class _Segments extends StatelessWidget {
  const _Segments({
    required this.items,
    required this.selected,
    required this.onPick,
  });

  final List<(InboxQuickFilter, String)> items;
  final InboxQuickFilter selected;
  final ValueChanged<InboxQuickFilter> onPick;

  @override
  Widget build(BuildContext context) {
    final motion = OmniMotion.of(context);
    final found = items.indexWhere((e) => e.$1 == selected);
    // Đang ở Khẩn / Đã lưu trữ thì không đoạn nào sáng: ẩn vệt trắng.
    final index = found < 0 ? 0 : found;
    final x = items.length == 1 ? 0.0 : -1 + 2 * index / (items.length - 1);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment: Alignment(x, 0),
            duration: motion.enabled
                ? const Duration(milliseconds: 350)
                : Duration.zero,
            curve: OmniCurves.standard,
            child: FractionallySizedBox(
              widthFactor: 1 / items.length,
              child: Opacity(
                opacity: found < 0 ? 0 : 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: OmniColors.byBrightness(
                          context,
                          OmniColors.ink.withAlpha(0x1F),
                          Colors.black.withAlpha(0x52),
                        ),
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final (filter, label) in items)
                Expanded(
                  child: InkWell(
                    splashFactory: _splash(context),
                    highlightColor: _highlight(context),
                    onTap: () => onPick(filter),
                    child: Center(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: OmniType.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: filter == selected
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
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
        color: selected ? scheme.primaryContainer : scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: InkWell(
          splashFactory: _splash(context),
          highlightColor: _highlight(context),
          onTap: onTap,
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          child: Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: OmniType.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? scheme.onPrimaryContainer
                      : OmniColors.byBrightness(
                          context,
                          OmniColors.secondaryForeground,
                          scheme.onSurface,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
