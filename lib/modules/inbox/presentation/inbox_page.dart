import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/channel.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../../../security/session/session_controller.dart';
import '../../../security/permissions/access_scope.dart';
import '../../channels/channels_module.dart';
import '../../channels/domain/channel_permissions.dart';
import '../../../core/realtime/realtime_client.dart';
import '../application/inbox_providers.dart';
import '../application/inbox_realtime.dart';
import '../data/inbox_api.dart';
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

class _InboxPageState extends ConsumerState<InboxPage>
    with WidgetsBindingObserver {
  final _scrollController = ScrollController();
  final Set<String> _selected = {};
  bool _selectionMode = false;
  bool _filtersOpen = false;
  Timer? _syncTimer;

  /// Nhịp poll dự phòng theo trạng thái socket thật (MS-I38).
  final _realtime = InboxRealtime.inbox();
  String? _syncCursor;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addObserver(this);
    _startRealtimeFallback();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _syncTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(inboxListProvider.notifier).refresh();
      _startRealtimeFallback();
    } else {
      _syncTimer?.cancel();
      _syncTimer = null;
    }
  }

  /// The catch-up poll, at whichever interval the socket's health calls for.
  ///
  /// Hẹn giờ MỘT lượt rồi tự đặt lại, không `Timer.periodic`: chu kỳ của một
  /// `Timer` là cố định lúc tạo, mà nhịp ở đây giãn dần sau mỗi lượt và mang
  /// nhiễu riêng từng lượt. Kênh còn sống thì không có lượt nào cả.
  void _startRealtimeFallback() {
    _syncTimer?.cancel();
    _syncTimer = null;
    final period = _realtime.pollInterval;
    if (period == null) return;
    _syncTimer = Timer(period, _pollTick);
  }

  Future<void> _pollTick() async {
    _syncTimer = null;
    await _catchUpChanges();
    if (!mounted) return;
    // Vẫn chưa có socket sau lượt này: lượt sau giãn ra.
    _realtime.tickBackoff();
    _startRealtimeFallback();
  }

  Future<void> _catchUpChanges() async {
    if (!mounted || _syncing) return;
    _syncing = true;
    try {
      final changes = await ref.read(inboxApiProvider).changes(_syncCursor);
      if (!mounted) return;
      _syncCursor = changes.cursor.isEmpty ? _syncCursor : changes.cursor;
      if (changes.count > 0) {
        // Gộp trang 1, không dựng lại: đang cuộn thì không nhảy về đầu
        // (APP-I3). `mergeLatest` cũng làm mới số đếm.
        await ref.read(inboxListProvider.notifier).mergeLatest();
      }
    } catch (_) {
      // The next interval retries; a temporary network failure must not blank
      // the cached inbox or make the app look disconnected.
    } finally {
      _syncing = false;
    }
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 400) {
      ref.read(inboxListProvider.notifier).loadMore();
    }
  }

  void _toggleSelection(String id) {
    setState(() {
      _selectionMode = true;
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  void _clearSelection() {
    setState(() {
      _selected.clear();
      _selectionMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Một tín hiệu gộp nhịp cho cả danh sách lẫn số đếm. Danh sách tự gộp
    // trang 1 vì `InboxListController` nghe tín hiệu này; ở đây chỉ còn số đếm.
    // Trước đây chỗ này gọi thêm `refresh()` trong khi controller cũng đang
    // dựng lại — hai lượt tải cho một sự kiện.
    ref.listen<int>(inboxListSignalProvider, (previous, next) {
      if (previous == next || !mounted) return;
      ref.invalidate(inboxFacetsProvider);
    });

    // A socket that drops has to put the poll back on its tight interval, and a
    // socket that comes up has to stop it again.
    final status =
        ref.watch(realtimeStatusProvider).valueOrNull ??
        RealtimeStatus.disabled;
    if (_realtime.setState(status)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startRealtimeFallback();
      });
    }
    final access = ref.watch(inboxAccessProvider);
    final list = ref.watch(inboxListProvider);
    final scheme = Theme.of(context).colorScheme;
    final selecting = _selectionMode;
    final canConnectChannels = ref
        .watch(accessProvider)
        .can(ChannelPermissions.write);

    return Scaffold(
      // Header and list on ONE plane. The AppBar was painted with `background`
      // (#F8F8FC) while the rows use `surface` (white), so the whole search area
      // read as a tinted panel framing itself — the "khung mờ" around the search
      // field was that seam, not a border on the field.
      backgroundColor: OmniColors.background,
      appBar: OmniTopBar(
        // Search line + pill row + the rule under them. "Kết nối kênh" and
        // "Chọn nhiều" moved here from the old AppBar actions, on the search
        // row after the filter button.
        bottom: InboxSearchRow(
          filtersOpen: _filtersOpen,
          onToggleFilters: () => setState(() => _filtersOpen = !_filtersOpen),
          trailing: [
            if (canConnectChannels)
              IconButton(
                tooltip: 'Kết nối kênh',
                onPressed: () => context.pushNamed(ChannelsModule.list),
                style: IconButton.styleFrom(
                  fixedSize: const Size(36, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: scheme.onSurfaceVariant,
                ),
                icon: const Icon(Icons.hub_outlined),
              ),
            IconButton(
              tooltip: 'Chọn nhiều',
              onPressed: access.canLabel
                  ? () => setState(() {
                      _selectionMode = !_selectionMode;
                      if (!_selectionMode) _selected.clear();
                    })
                  : null,
              style: IconButton.styleFrom(
                fixedSize: const Size(36, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: selecting
                    ? OmniColors.chatPrimary
                    : scheme.onSurfaceVariant,
              ),
              icon: Icon(
                selecting ? Icons.close_rounded : Icons.checklist_rounded,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          InboxFilterPanel(open: _filtersOpen),
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
            // Danh sách nằm trong một thẻ trắng viền mảnh trên nền xám nhạt
            // (`main` của bản mẫu: padding 12 16).
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: OmniColors.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: RefreshIndicator(
                    onRefresh: () =>
                        ref.read(inboxListProvider.notifier).refresh(),
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
                        separatorBuilder: (_, _) => const Divider(
                          height: 1,
                          thickness: 1,
                          indent: 0,
                          endIndent: 0,
                          color: OmniColors.divider,
                        ),
                        itemBuilder: (context, index) {
                          if (index >= state.items.length) {
                            return const Padding(
                              padding: EdgeInsets.all(OmniSpacing.lg),
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
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
              ),
            ),
          ),
          if (selecting)
            InboxBulkBar(
              selectedIds: _selected.toList(),
              allIds:
                  list.valueOrNull?.items.map((item) => item.id).toList() ??
                  const [],
              onSelectAll: (ids) => setState(() {
                _selected
                  ..clear()
                  ..addAll(ids);
              }),
              onDone: _clearSelection,
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
