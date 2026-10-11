import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/network/api_envelope.dart';
import '../../../security/permissions/access_scope.dart';
import '../../../security/permissions/resource_access.dart';
import '../../../security/session/session_controller.dart';
import '../data/opportunities_api.dart';
import '../domain/opportunity.dart';
import '../domain/opportunity_permissions.dart';
import '../domain/pipeline_catalog.dart';

final opportunityAccessProvider = Provider<ResourceAccess>((ref) {
  return OpportunityPermissions.of(ref.watch(accessProvider));
});

/// The tenant's pipelines and stages. Đọc lại mỗi lần mở bảng cơ hội và khi
/// đổi giai đoạn bị 422 `opportunity_stage` (APP-I12); giữa hai lần đó dùng
/// bản đã nạp (columns don't
/// change minute to minute); rebuilt on a workspace switch because
/// [opportunitiesApiProvider] follows the active tenant.
final pipelineCatalogProvider = FutureProvider<PipelineCatalog>((ref) {
  return ref.watch(opportunitiesApiProvider).pipelines();
});

/// The pipeline shown on the board; null = the tenant's default.
final selectedPipelineProvider = StateProvider<String?>((ref) {
  // A new workspace has other pipelines.
  ref.watch(opportunitiesApiProvider);
  return null;
});

final pipelineSearchProvider = StateProvider<String>((ref) => '');

/// "Của tôi": only deals the current user owns (`owner=me`). On by default
/// for a rep who can only read their own — "all" would return the same list
/// and read as broken (same rule as the customer list).
final pipelineMineProvider = StateProvider<bool>((ref) {
  return ref.watch(opportunityAccessProvider).readScope == AccessScope.own;
});

/// What every board request filters by.
typedef BoardQuery = ({String? pipeline, bool mine, String search});

final boardQueryProvider = FutureProvider<BoardQuery>((ref) async {
  final catalog = await ref.watch(pipelineCatalogProvider.future);
  final pipeline = catalog.pipelineOf(ref.watch(selectedPipelineProvider));
  return (
    // The fallback catalog doesn't know the tenant's real default pipeline;
    // sending `standard` could hide every deal of a custom default.
    pipeline: catalog.fromServer ? pipeline.code : null,
    mine: ref.watch(pipelineMineProvider),
    search: ref.watch(pipelineSearchProvider),
  );
});

/// The pipeline the board is showing, once the catalog is in.
final boardPipelineProvider = Provider<PipelineDef?>((ref) {
  final catalog = ref.watch(pipelineCatalogProvider).valueOrNull;
  return catalog?.pipelineOf(ref.watch(selectedPipelineProvider));
});

final pipelineSummaryProvider = FutureProvider<PipelineSummary>((ref) async {
  final query = await ref.watch(boardQueryProvider.future);
  return ref
      .watch(opportunitiesApiProvider)
      .summary(
        pipeline: query.pipeline,
        mine: query.mine,
        search: query.search.isEmpty ? null : query.search,
      );
});

class StageListState {
  const StageListState({
    this.items = const [],
    this.pagination = const ApiPagination.empty(),
    this.loadingMore = false,
  });

  final List<Opportunity> items;
  final ApiPagination pagination;
  final bool loadingMore;

  bool get hasMore => pagination.hasMore;
}

/// One board column (keyed on the stage code), loaded page by page. It used
/// to fetch page 1 only — the 31st deal in a stage never showed, and nothing
/// said there were more.
class StageOpportunitiesController
    extends AutoDisposeFamilyAsyncNotifier<StageListState, String> {
  /// Bumped by every (re)build. A page requested under an older generation
  /// belongs to a list that no longer exists — see [loadMore].
  int _generation = 0;

  @override
  Future<StageListState> build(String stageCode) async {
    _generation++;
    final query = await ref.watch(boardQueryProvider.future);
    final page = await ref
        .watch(opportunitiesApiProvider)
        .list(
          stageCode: stageCode,
          pipeline: query.pipeline,
          mine: query.mine,
          search: query.search.isEmpty ? null : query.search,
        );
    return StageListState(items: page.items, pagination: page.pagination);
  }

  Future<void> refresh() async {
    ref.invalidate(pipelineSummaryProvider);
    state = await AsyncValue.guard(() => build(arg));
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.loadingMore) return;
    final generation = _generation;

    state = AsyncData(
      StageListState(
        items: current.items,
        pagination: current.pagination,
        loadingMore: true,
      ),
    );

    try {
      final query = await ref.read(boardQueryProvider.future);
      final next = await ref
          .read(opportunitiesApiProvider)
          .list(
            stageCode: arg,
            pipeline: query.pipeline,
            mine: query.mine,
            search: query.search.isEmpty ? null : query.search,
            page: current.pagination.nextPage,
          );
      // The column was rebuilt while this page was in flight (a move
      // invalidated it, or pull-to-refresh): appending to the OLD rows would
      // bring back a deal that has left the column. The fresh list wins.
      if (generation != _generation) return;
      // Skip what is already on screen rather than list it twice (another
      // user's write can shift the server's page window).
      final seen = {for (final item in current.items) item.id};
      state = AsyncData(
        StageListState(
          items: [
            ...current.items,
            ...next.items.where((item) => !seen.contains(item.id)),
          ],
          pagination: next.pagination,
        ),
      );
    } catch (_) {
      if (generation != _generation) return;
      // Keep what's on screen; scrolling to the end again retries.
      state = AsyncData(
        StageListState(items: current.items, pagination: current.pagination),
      );
    }
  }
}

final stageOpportunitiesProvider = AsyncNotifierProvider.autoDispose
    .family<StageOpportunitiesController, StageListState, String>(
      StageOpportunitiesController.new,
    );

/// Đoạn "Cơ hội" đang xem cơ hội ĐÃ ĐÓNG (thắng/thua) thay vì đang mở. Về false
/// khi đổi quy trình.
final segmentClosedProvider = StateProvider<bool>((ref) {
  ref.watch(selectedPipelineProvider);
  return false;
});

/// Ô giai đoạn đang lọc ở đoạn "Cơ hội" của tab Khách; null = mọi giai đoạn
/// mở (hoặc, ở chế độ đã đóng, giai đoạn đóng đầu tiên). Về null khi đổi quy
/// trình hay đổi chế độ — mã của quy trình này vô nghĩa ở quy trình khác.
final segmentStageProvider = StateProvider<String?>((ref) {
  ref.watch(selectedPipelineProvider);
  ref.watch(segmentClosedProvider);
  return null;
});

/// Bộ lọc gửi đi của đoạn: `stage` và `status`. Không có `stage` thì máy chủ
/// trả MỌI trạng thái, nên "đang mở" phải gửi `status=OPEN`; chế độ đã đóng
/// luôn nhắm một giai đoạn đóng cụ thể (mặc định cái đầu tiên).
({String? stage, String? status}) _segmentFilter({
  required String? stage,
  required bool closed,
  required PipelineDef? pipeline,
}) {
  if (closed) {
    final closedStages = pipeline?.stages.where((s) => s.isClosed);
    return (stage: stage ?? closedStages?.firstOrNull?.code, status: null);
  }
  return (stage: stage, status: stage == null ? 'OPEN' : null);
}

/// Danh sách của đoạn "Cơ hội": như [StageOpportunitiesController] nhưng giai
/// đoạn lấy từ [segmentStageProvider]; null → gửi `status=OPEN` (xem
/// [_segmentFilter]).
class SegmentOpportunitiesController
    extends AutoDisposeAsyncNotifier<StageListState> {
  int _generation = 0;

  @override
  Future<StageListState> build() async {
    _generation++;
    final filter = _segmentFilter(
      stage: ref.watch(segmentStageProvider),
      closed: ref.watch(segmentClosedProvider),
      pipeline: ref.watch(boardPipelineProvider),
    );
    final query = await ref.watch(boardQueryProvider.future);
    final page = await ref
        .watch(opportunitiesApiProvider)
        .list(
          stageCode: filter.stage,
          status: filter.status,
          pipeline: query.pipeline,
          mine: query.mine,
          search: query.search.isEmpty ? null : query.search,
        );
    return StageListState(items: page.items, pagination: page.pagination);
  }

  Future<void> refresh() async {
    ref.invalidate(pipelineSummaryProvider);
    state = await AsyncValue.guard(build);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.loadingMore) return;
    final generation = _generation;
    final filter = _segmentFilter(
      stage: ref.read(segmentStageProvider),
      closed: ref.read(segmentClosedProvider),
      pipeline: ref.read(boardPipelineProvider),
    );

    state = AsyncData(
      StageListState(
        items: current.items,
        pagination: current.pagination,
        loadingMore: true,
      ),
    );

    try {
      final query = await ref.read(boardQueryProvider.future);
      final next = await ref
          .read(opportunitiesApiProvider)
          .list(
            stageCode: filter.stage,
            status: filter.status,
            pipeline: query.pipeline,
            mine: query.mine,
            search: query.search.isEmpty ? null : query.search,
            page: current.pagination.nextPage,
          );
      if (generation != _generation) return;
      final seen = {for (final item in current.items) item.id};
      state = AsyncData(
        StageListState(
          items: [
            ...current.items,
            ...next.items.where((item) => !seen.contains(item.id)),
          ],
          pagination: next.pagination,
        ),
      );
    } catch (_) {
      if (generation != _generation) return;
      state = AsyncData(
        StageListState(items: current.items, pagination: current.pagination),
      );
    }
  }
}

final segmentOpportunitiesProvider =
    AsyncNotifierProvider.autoDispose<
      SegmentOpportunitiesController,
      StageListState
    >(SegmentOpportunitiesController.new);

final opportunityProvider = FutureProvider.autoDispose
    .family<Opportunity, String>((ref, id) {
      return ref.watch(opportunitiesApiProvider).get(id);
    });

/// Writes that change what the board shows, and the refresh that follows.
class OpportunityActions {
  OpportunityActions(this._ref);

  final Ref _ref;

  /// Moves a deal to [stageCode] of its pipeline.
  ///
  /// The server answers 422 when the code is not in the pipeline. An API from
  /// before that check answered 200 and kept the old stage — so the answer is
  /// compared with what was asked, and a mismatch is an error, never "done".
  Future<Opportunity> moveStage(
    Opportunity opportunity,
    String stageCode,
  ) async {
    try {
      final updated = await _ref
          .read(opportunitiesApiProvider)
          .moveStage(opportunity.id, stageCode: stageCode);
      if (!_landedOn(updated, stageCode)) {
        throw const ServerException(
          'Máy chủ không chuyển được giai đoạn',
          code: 'stage_not_moved',
        );
      }
      return updated;
    } on ValidationException catch (error) {
      // Giai đoạn không còn trong quy trình: web vừa sửa quy trình mà app còn
      // giữ danh mục cũ — đọc lại để lần chọn sau đúng (APP-I12).
      if (error.errors.containsKey('opportunity_stage')) {
        _ref.invalidate(pipelineCatalogProvider);
      }
      rethrow;
    } finally {
      _refresh(opportunity.id);
    }
  }

  Future<WinResult> markWon(String id) async {
    final result = await _ref.read(opportunitiesApiProvider).markWon(id);
    _refresh(id);
    return result;
  }

  /// The old API maps `won`/`lost` onto a pipeline's own Win/Loss stage
  /// (`da_mua`) — that is a move, just under another code.
  static bool _landedOn(Opportunity updated, String asked) {
    if (updated.stageCode == asked) return true;
    if (asked == 'won') return updated.status == 'WON';
    if (asked == 'lost') return updated.status == 'LOST';
    return false;
  }

  void _refresh(String id) {
    _ref.invalidate(pipelineSummaryProvider);
    // Every column: the one it left and the one it joined.
    _ref.invalidate(stageOpportunitiesProvider);
    // Chưa dựng (đoạn Cơ hội chưa từng mở) thì invalidate sẽ dựng nó và gọi API.
    if (_ref.exists(segmentOpportunitiesProvider)) {
      _ref.invalidate(segmentOpportunitiesProvider);
    }
    _ref.invalidate(opportunityProvider(id));
    // Đoạn Cơ hội của hồ sơ khách — đổi giai đoạn được cả từ đó.
    _ref.invalidate(customerOpportunitiesProvider);
  }
}

final opportunityActionsProvider = Provider<OpportunityActions>(
  OpportunityActions.new,
);

/// Moves a deal and refreshes everything that shows a stage total.
Future<Opportunity> moveOpportunityStage(
  WidgetRef ref,
  Opportunity opportunity,
  String stageCode,
) => ref.read(opportunityActionsProvider).moveStage(opportunity, stageCode);

/// Cơ hội của một khách (`customer_id`), mọi trạng thái, tối đa 50.
final customerOpportunitiesProvider = FutureProvider.autoDispose
    .family<List<Opportunity>, String>((ref, customerId) async {
      final page = await ref
          .watch(opportunitiesApiProvider)
          .list(customerId: customerId, perPage: 50);
      return page.items;
    });
