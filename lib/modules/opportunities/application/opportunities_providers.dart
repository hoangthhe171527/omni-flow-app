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

/// The tenant's pipelines and stages. Kept for the session (columns don't
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

/// The stage tab shown on the board, as a raw code; null = the first open
/// stage of the pipeline. Reset whenever the pipeline changes — `tu_van` of
/// one pipeline means nothing in another.
final selectedStageProvider = StateProvider<String?>((ref) {
  ref.watch(selectedPipelineProvider);
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
      .summary(pipeline: query.pipeline, mine: query.mine);
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
  @override
  Future<StageListState> build(String stageCode) async {
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
      // A deal moved between the two requests shifts the window: skip what
      // is already on screen rather than list it twice.
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
    _ref.invalidate(opportunityProvider(id));
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
