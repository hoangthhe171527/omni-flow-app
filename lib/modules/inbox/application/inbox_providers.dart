import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_envelope.dart';
import '../../../security/session/session_controller.dart';
import '../data/inbox_api.dart';
import '../domain/conversation.dart';
import '../domain/inbox_filter.dart';
import '../domain/inbox_permissions.dart';

final inboxAccessProvider = Provider<InboxAccess>((ref) {
  return InboxAccess.of(ref.watch(accessProvider));
});

final inboxFilterProvider =
    NotifierProvider<InboxFilterController, InboxFilter>(InboxFilterController.new);

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

final inboxFacetsProvider = FutureProvider.autoDispose<InboxFacets>((ref) async {
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

class ConversationListState {
  const ConversationListState({
    this.items = const [],
    this.pagination = const ApiPagination.empty(),
    this.loadingMore = false,
  });

  final List<Conversation> items;
  final ApiPagination pagination;
  final bool loadingMore;

  bool get hasMore => pagination.hasMore;
}

/// The conversation list. Rebuilds whenever the filter changes; exposes
/// `loadMore` for infinite scroll and `refresh` for pull-to-refresh.
class InboxListController extends AutoDisposeAsyncNotifier<ConversationListState> {
  @override
  Future<ConversationListState> build() async {
    final query = ref.watch(_inboxQueryProvider);
    final page = await ref.watch(inboxApiProvider).list(query: query);
    return ConversationListState(items: page.items, pagination: page.pagination);
  }

  Future<void> refresh() async {
    ref.invalidate(inboxFacetsProvider);
    state = await AsyncValue.guard(build);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.loadingMore) return;

    state = AsyncData(
      ConversationListState(
        items: current.items,
        pagination: current.pagination,
        loadingMore: true,
      ),
    );

    try {
      final next = await ref.read(inboxApiProvider).list(
            query: ref.read(_inboxQueryProvider),
            page: current.pagination.nextPage,
          );
      state = AsyncData(
        ConversationListState(
          items: [...current.items, ...next.items],
          pagination: next.pagination,
        ),
      );
    } catch (_) {
      // Keep what's on screen; the footer shows a retry.
      state = AsyncData(
        ConversationListState(
          items: current.items,
          pagination: current.pagination,
        ),
      );
    }
  }

  /// Applies a locally-known change without a round trip — used after assign,
  /// mark-read and labelling so the row updates the moment the sheet closes.
  void patch(Conversation updated) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      ConversationListState(
        items: [
          for (final item in current.items)
            if (item.id == updated.id) updated else item,
        ],
        pagination: current.pagination,
      ),
    );
  }
}

final inboxListProvider = AutoDisposeAsyncNotifierProvider<InboxListController,
    ConversationListState>(InboxListController.new);

final conversationProvider =
    FutureProvider.autoDispose.family<Conversation, String>((ref, id) {
  return ref.watch(inboxApiProvider).get(id);
});

final conversationContextProvider =
    FutureProvider.autoDispose.family<ConversationContext, String>((ref, id) {
  return ref.watch(inboxApiProvider).context(id);
});
