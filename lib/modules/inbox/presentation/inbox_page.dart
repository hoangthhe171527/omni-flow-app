import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/channel.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../../../security/permissions/access_scope.dart';
import '../application/inbox_providers.dart';
import '../domain/inbox_filter.dart';
import '../inbox_module.dart';
import 'widgets/conversation_row.dart';
import 'widgets/inbox_bulk_bar.dart';
import 'widgets/inbox_filter_bar.dart';

class InboxPage extends ConsumerStatefulWidget {
  const InboxPage({super.key});

  @override
  ConsumerState<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends ConsumerState<InboxPage> {
  final _scrollController = ScrollController();
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 400) {
      ref.read(inboxListProvider.notifier).loadMore();
    }
  }

  void _toggleSelection(String id) {
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(inboxAccessProvider);
    final list = ref.watch(inboxListProvider);
    final scheme = Theme.of(context).colorScheme;
    final selecting = _selected.isNotEmpty;

    return Scaffold(
      // Header and list on ONE plane. The AppBar was painted with `background`
      // (#F8F8FC) while the rows use `surface` (white), so the whole search area
      // read as a tinted panel framing itself — the "khung mờ" around the search
      // field was that seam, not a border on the field.
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        title: const Text('Hộp thư'),
        titleSpacing: OmniSpacing.lg,
        toolbarHeight: 56,
        actions: [
          IconButton(
            tooltip: 'Chọn nhiều',
            onPressed: access.canLabel
                ? () => setState(() {
                    final items = list.valueOrNull?.items ?? const [];
                    if (_selected.isEmpty && items.isNotEmpty) {
                      _selected.add(items.first.id);
                    } else {
                      _selected.clear();
                    }
                  })
                : null,
            // A bare icon. The filled circle behind it was a button drawn twice
            // — the icon already reads as tappable, and the disc only added a
            // grey blob to the corner of an otherwise clean bar.
            style: IconButton.styleFrom(
              foregroundColor: selecting
                  ? OmniColors.chatPrimary
                  : scheme.onSurfaceVariant,
            ),
            icon: Icon(
              selecting ? Icons.close_rounded : Icons.checklist_rounded,
            ),
          ),
          const SizedBox(width: OmniSpacing.sm),
        ],
        // Was 112 for three stacked filter bands; the header is now a search
        // line plus one pill row, and the stale number left a dead white gap.
        bottom: const PreferredSize(
          // Search line + pill row + the rule under them.
          preferredSize: Size.fromHeight(89),
          child: InboxFilterBar(),
        ),
      ),
      body: Column(
        children: [
          // A member scoped to `inbox.read.own` sees only threads assigned to
          // them — not the unassigned pool. Saying so up front stops "hộp thư
          // trống" being read as a sync failure.
          if (access.readScope == AccessScope.own)
            // A quiet line, not a coloured banner. It is a standing fact about
            // this rep's scope, not an alert — a filled strip gave it the weight
            // of a warning every single time the screen opened.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
              child: Text(
                'Bạn đang xem các hội thoại được gán cho mình.',
                style: OmniType.micro.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(inboxListProvider.notifier).refresh(),
              child: OmniAsyncView(
                value: list,
                onRetry: () => ref.invalidate(inboxListProvider),
                isEmpty: (state) => state.items.isEmpty,
                empty: _empty(),
                data: (state) => ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(
                    bottom: OmniSpacing.bottomSafe,
                  ),
                  itemCount: state.items.length + (state.hasMore ? 1 : 0),
                  // Zalo separates rows with a hairline indented past the
                  // avatar, not a gap. Gaps between bordered cards were what
                  // made the list read as a table of records.
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    thickness: 1,
                    indent: 80,
                    endIndent: 0,
                    color: OmniColors.chat(
                      context,
                      OmniColors.chatDivider,
                      OmniColors.chatDividerDark,
                    ),
                  ),
                  itemBuilder: (context, index) {
                    if (index >= state.items.length) {
                      return const Padding(
                        padding: EdgeInsets.all(OmniSpacing.lg),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }
                    final conversation = state.items[index];
                    return ConversationRow(
                      conversation: conversation,
                      selectionMode: selecting,
                      selected: _selected.contains(conversation.id),
                      onLongPress: access.canLabel
                          ? () => _toggleSelection(conversation.id)
                          : null,
                      onTap: () {
                        if (selecting) {
                          _toggleSelection(conversation.id);
                          return;
                        }
                        context.pushNamed(
                          InboxModule.thread,
                          pathParameters: {'id': conversation.id},
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
          if (selecting)
            InboxBulkBar(
              selectedIds: _selected.toList(),
              onDone: () => setState(_selected.clear),
            ),
        ],
      ),
    );
  }

  Widget _empty() {
    final filter = ref.read(inboxFilterProvider);
    final filtered =
        filter.quick != InboxQuickFilter.all ||
        filter.search.isNotEmpty ||
        filter.channel != null ||
        filter.label != null;

    return OmniEmptyState(
      icon: filtered ? Icons.filter_alt_off_rounded : Icons.forum_outlined,
      title: filtered ? 'Không có hội thoại khớp bộ lọc' : 'Hộp thư trống',
      message: filtered
          ? 'Thử bỏ bớt bộ lọc để xem thêm hội thoại.'
          : 'Tin nhắn từ Zalo, Facebook, TikTok và website sẽ hiện ở đây.',
      actionLabel: filtered ? 'Xoá bộ lọc' : null,
      onAction: () => ref.read(inboxFilterProvider.notifier).reset(),
    );
  }
}

/// Platform row used by the filter bar — kept here so the page and the bar agree
/// on which platforms are offered and in what order.
const inboxChannelOrder = <Channel>[
  Channel.zalo,
  Channel.zaloPersonal,
  Channel.facebook,
  Channel.facebookPersonal,
  Channel.tiktok,
  Channel.web,
  Channel.instagram,
  Channel.whatsapp,
];
