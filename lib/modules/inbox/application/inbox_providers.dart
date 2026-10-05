import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/network/api_envelope.dart';
import '../../../security/session/session_controller.dart';
import '../data/inbox_api.dart';
import '../domain/conversation.dart';
import '../domain/inbox_filter.dart';
import '../domain/inbox_permissions.dart';
import 'inbox_realtime.dart';

/// Module notifications bấm tín hiệu FCM qua file này; nó đã dọn sang
/// `inbox_realtime.dart` cùng hai tín hiệu gộp nhịp, nhưng vẫn ở đúng chỗ cũ
/// đối với người import.
export 'inbox_realtime.dart' show inboxRealtimeSignalProvider;

final inboxAccessProvider = Provider<InboxAccess>((ref) {
  return InboxAccess.of(ref.watch(accessProvider));
});

final inboxFilterProvider =
    NotifierProvider<InboxFilterController, InboxFilter>(
      InboxFilterController.new,
    );

class InboxFilterController extends Notifier<InboxFilter> {
  @override
  InboxFilter build() => const InboxFilter();

  void setQuick(InboxQuickFilter quick) => state = state.copyWith(quick: quick);

  void setSearch(String search) => state = state.copyWith(search: search);

  void setChannel(Object? channel) => state = state.copyWith(
    channel: channel,
    // A specific account only makes sense within its own platform.
    connectionId: null,
  );

  void setConnection(String? connectionId) =>
      state = state.copyWith(connectionId: connectionId);

  void setLabel(String? label) => state = state.copyWith(label: label);

  void reset() => state = const InboxFilter();
}

/// Query the current filter resolves to, including the caller's user id for the
/// "Của tôi" filter.
final _inboxQueryProvider = Provider<Map<String, dynamic>>((ref) {
  final filter = ref.watch(inboxFilterProvider);
  final userId = ref.watch(sessionProvider).user?.id;
  return filter.toQuery(currentUserId: userId);
});

final inboxFacetsProvider = FutureProvider.autoDispose<InboxFacets>((
  ref,
) async {
  // Keep the counts alive briefly across tab switches so the pills don't blink.
  ref.keepAlive();
  return ref.watch(inboxApiProvider).facets(ref.watch(_inboxQueryProvider));
});

/// Unread count on the inbox tab. Falls back to 0 rather than throwing — a
/// failed badge fetch must never break the shell.
final inboxUnreadBadgeProvider = Provider<int>((ref) {
  return ref.watch(inboxFacetsProvider).valueOrNull?.unread ?? 0;
});

final inboxLabelsProvider = FutureProvider.autoDispose<List<String>>((ref) {
  return ref.watch(inboxApiProvider).labels();
});

final conversationAssetsProvider = FutureProvider.autoDispose
    .family<ConversationAssets, String>((ref, id) {
      return ref.watch(inboxApiProvider).assets(id);
    });

class ConversationListState {
  const ConversationListState({
    this.items = const [],
    this.cursor = const CursorPage.empty(),
    this.loadedBeyondFirstPage = false,
    this.loadingMore = false,
  });

  final List<Conversation> items;

  /// Con trỏ của trang CUỐI đã tải — `loadMore` đi tiếp từ đây.
  final CursorPage cursor;

  /// Đã cuộn quá trang 1: tin mới thì GỘP trang 1 lên đầu, không thay cả
  /// danh sách (APP-I3).
  final bool loadedBeyondFirstPage;
  final bool loadingMore;

  bool get hasMore => cursor.hasMore;

  ConversationListState copyWith({
    List<Conversation>? items,
    CursorPage? cursor,
    bool? loadedBeyondFirstPage,
    bool? loadingMore,
  }) => ConversationListState(
    items: items ?? this.items,
    cursor: cursor ?? this.cursor,
    loadedBeyondFirstPage: loadedBeyondFirstPage ?? this.loadedBeyondFirstPage,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

/// The conversation list. Rebuilds whenever the filter changes; exposes
/// `loadMore` for infinite scroll and `refresh` for pull-to-refresh.
class InboxListController
    extends AutoDisposeAsyncNotifier<ConversationListState> {
  /// Bumped by every (re)build; see [loadMore].
  int _generation = 0;

  @override
  Future<ConversationListState> build() async {
    _generation++;
    // `message.created` (đã gộp nhịp 400ms) KHÔNG dựng lại danh sách về trang
    // 1 — đang cuộn tới trang 3 mà nhảy về 30 dòng đầu là mất chỗ đang đọc
    // (APP-I3). Chỉ gộp trang 1 lên đầu. `listen` cũng giữ tín hiệu sống, nên
    // kênh tenant vẫn tự mở như khi `watch`.
    ref.listen<int>(inboxListSignalProvider, (previous, next) {
      if (previous != next) unawaited(_mergeFirstPage());
    });
    // `conversation.updated` KHÔNG dựng lại danh sách: chỉ vá đúng dòng đổi.
    ref.listen<ConversationUpdateBatch?>(inboxConversationUpdatesProvider, (
      _,
      batch,
    ) {
      if (batch != null) unawaited(_applyUpdates(batch));
    });
    final query = ref.watch(_inboxQueryProvider);
    final page = await ref.watch(inboxApiProvider).list(query: query);
    return ConversationListState(items: page.items, cursor: page.cursor);
  }

  /// Kéo để làm mới / quay lại app: về trang 1 như một lượt tải mới.
  ///
  /// Không gọi lại [build]: mỗi lần gọi `build` ngoài vòng dựng là thêm một
  /// bộ `ref.listen` nữa, và một tín hiệu sau đó chạy gộp trang hai lần.
  Future<void> refresh() async {
    ref.invalidate(inboxFacetsProvider);
    _generation++;
    state = await AsyncValue.guard(() async {
      final page = await ref
          .read(inboxApiProvider)
          .list(query: ref.read(_inboxQueryProvider));
      return ConversationListState(items: page.items, cursor: page.cursor);
    });
  }

  /// Nhịp poll dự phòng thấy có thay đổi: gộp trang 1 lên đầu, giữ các trang
  /// đã cuộn (cùng đường với tin mới qua realtime).
  Future<void> mergeLatest() {
    ref.invalidate(inboxFacetsProvider);
    return _mergeFirstPage();
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.loadingMore) return;
    final generation = _generation;

    state = AsyncData(current.copyWith(loadingMore: true));

    try {
      final next = await ref
          .read(inboxApiProvider)
          .list(
            query: ref.read(_inboxQueryProvider),
            before: current.cursor.nextBefore,
          );
      // The list was rebuilt while this page was in flight (filter change,
      // realtime signal, pull-to-refresh): its page 2 belongs to a list that
      // no longer exists. The fresh list wins.
      if (generation != _generation) return;
      // Append to what is on screen NOW — a [patch] may have landed meanwhile.
      final latest = state.valueOrNull ?? current;
      // Một hội thoại mới chèn lên đầu (vá theo `conversation.updated`) đẩy
      // các trang phía server lùi một dòng: bỏ dòng đã có thay vì hiện hai lần.
      final shown = {for (final c in latest.items) c.id};
      state = AsyncData(
        ConversationListState(
          items: [
            ...latest.items,
            for (final c in next.items)
              if (!shown.contains(c.id)) c,
          ],
          cursor: next.cursor,
          loadedBeyondFirstPage: true,
        ),
      );
    } catch (_) {
      if (generation != _generation) return;
      final latest = state.valueOrNull ?? current;
      // Keep what's on screen; the footer shows a retry.
      state = AsyncData(
        latest.copyWith(cursor: current.cursor, loadingMore: false),
      );
    }
  }

  /// Applies a locally-known change without a round trip — used after assign,
  /// mark-read and labelling so the row updates the moment the sheet closes.
  void patch(Conversation updated) {
    final current = state.valueOrNull;
    if (current == null) return;
    // copyWith: a page in flight stays in flight — dropping the flag would let
    // a second scroll request the same page again.
    state = AsyncData(
      current.copyWith(
        items: [
          for (final item in current.items)
            if (item.id == updated.id) updated else item,
        ],
      ),
    );
  }

  /// Vá theo id tối đa bấy nhiêu dòng mỗi loạt; nhiều hơn (gán hàng loạt)
  /// thì làm mới trang 1 kiểu gộp — một request thay vì hàng chục.
  static const _maxPatchIds = 10;

  /// Áp một loạt `conversation.updated` mà KHÔNG co danh sách về trang 1.
  ///
  /// Mỗi hội thoại liên quan được hỏi lại đúng một lần (GET theo id), rồi
  /// XÉT LẠI theo bộ lọc đang chọn ([InboxFilter.matches], cùng vị từ với
  /// server):
  /// - còn khớp: vá tại chỗ (đang hiện) hoặc chèn theo `last_message_at` (chưa
  ///   hiện — vd vừa được giao cho mình);
  /// - hết khớp: bỏ dòng — hội thoại vừa được giao rời tab "Chưa gán" ngay;
  /// - không tự xét được (đang tìm kiếm…): vá rồi gộp trang 1 từ server.
  ///
  /// 404/403 thì bỏ dòng (không còn thuộc về người xem). `deleted` bỏ dòng
  /// không hỏi. `read` của hội thoại không có trên màn thì bỏ qua — người
  /// khác mở hội thoại không thêm gì vào danh sách của mình.
  Future<void> _applyUpdates(ConversationUpdateBatch batch) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final generation = _generation;
    final filter = ref.read(inboxFilterProvider);
    final userId = ref.read(sessionProvider).user?.id;

    final loaded = {for (final c in current.items) c.id};
    final deleted = <String>{};
    var fetch = <String>[];
    var merge = batch.unscoped;
    batch.reasonsById.forEach((id, reasons) {
      if (reasons.contains('deleted')) {
        if (loaded.contains(id)) deleted.add(id);
      } else if (loaded.contains(id) || !reasons.every((r) => r == 'read')) {
        fetch.add(id);
      }
    });
    if (fetch.length > _maxPatchIds) {
      fetch = const [];
      merge = true;
    }
    if (!merge && deleted.isEmpty && fetch.isEmpty) return;

    ref.invalidate(inboxFacetsProvider);
    if (deleted.isNotEmpty) _remove(deleted);

    final api = ref.read(inboxApiProvider);
    final fresh = <Conversation>[];
    final gone = <String>{};
    await Future.wait(
      fetch.map((id) async {
        try {
          fresh.add(await api.get(id));
        } on NotFoundException {
          gone.add(id);
        } on ForbiddenException {
          gone.add(id);
        } catch (_) {
          // Dòng đang hiện thì giữ bản cũ (nhịp poll sẽ sửa); hội thoại chưa
          // hiện thì không biết có thuộc danh sách không — hỏi trang 1.
          if (!loaded.contains(id)) merge = true;
        }
      }),
    );
    if (generation != _generation) return;

    for (final c in fresh) {
      final matches = filter.matches(c, currentUserId: userId);
      if (matches == null) {
        if (loaded.contains(c.id)) patch(c);
        merge = true;
      } else if (!matches) {
        gone.add(c.id);
      } else if (loaded.contains(c.id)) {
        patch(c);
      } else {
        _insert(c);
      }
    }
    if (gone.isNotEmpty) _remove(gone);

    if (merge) await _mergeFirstPage();
  }

  /// Chèn một hội thoại vừa khớp bộ lọc vào đúng chỗ theo `last_message_at`
  /// (mới nhất trên cùng). Cũ hơn mọi dòng đã tải mà server còn trang sau thì
  /// không chèn: chỗ của nó ở trang chưa tải, cuộn tới sẽ gặp.
  void _insert(Conversation c) {
    final current = state.valueOrNull;
    if (current == null) return;
    if (current.items.any((x) => x.id == c.id)) {
      patch(c);
      return;
    }
    final at = c.lastMessageAt;
    var index = at == null
        ? -1
        : current.items.indexWhere(
            (x) => x.lastMessageAt == null || x.lastMessageAt!.isBefore(at),
          );
    if (index < 0) {
      if (current.hasMore) return;
      index = current.items.length;
    }
    state = AsyncData(
      current.copyWith(items: [...current.items]..insert(index, c)),
    );
  }

  /// Lấy trang 1 và đặt lên đầu, GIỮ các trang đã cuộn phía sau.
  Future<void> _mergeFirstPage() async {
    final generation = _generation;
    final CursorPaged<Conversation> page;
    try {
      page = await ref
          .read(inboxApiProvider)
          .list(query: ref.read(_inboxQueryProvider));
    } catch (_) {
      return;
    }
    if (generation != _generation) return;
    final latest = state.valueOrNull;
    if (latest == null) return;

    // Mới có trang 1 trên màn: thay hẳn, như một lượt tải lại thường.
    if (!latest.loadedBeyondFirstPage && !latest.loadingMore) {
      state = AsyncData(
        ConversationListState(items: page.items, cursor: page.cursor),
      );
      return;
    }

    // Giữ con trỏ của trang đã cuộn: `loadMore` đi tiếp từ chỗ cũ.
    final freshIds = {for (final c in page.items) c.id};
    state = AsyncData(
      latest.copyWith(
        items: [
          ...page.items,
          for (final c in latest.items)
            if (!freshIds.contains(c.id)) c,
        ],
      ),
    );
  }

  void _remove(Set<String> ids) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        items: [
          for (final c in current.items)
            if (!ids.contains(c.id)) c,
        ],
      ),
    );
  }
}

final inboxListProvider =
    AutoDisposeAsyncNotifierProvider<
      InboxListController,
      ConversationListState
    >(InboxListController.new);

final conversationProvider = FutureProvider.autoDispose
    .family<Conversation, String>((ref, id) {
      return ref.watch(inboxApiProvider).get(id);
    });

final conversationContextProvider = FutureProvider.autoDispose
    .family<ConversationContext, String>((ref, id) {
      return ref.watch(inboxApiProvider).context(id);
    });
