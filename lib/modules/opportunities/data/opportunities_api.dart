import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_envelope.dart';
import '../domain/opportunity.dart';
import '../domain/pipeline_catalog.dart';

/// `POST /{id}/win` → the won opportunity and its order: the one just created
/// ([orderCreated]) or the one it already had.
typedef WinResult = ({
  Opportunity opportunity,
  String? orderId,
  bool orderCreated,
});

class OpportunitiesApi {
  OpportunitiesApi(this._client);

  static const _base = '/sales-opportunities';

  final ApiClient _client;

  /// The tenant's pipelines and their stages. An API without the endpoint
  /// (before Đợt 4) answers 404 — the app then runs on the six built-in stages
  /// rather than not at all.
  Future<PipelineCatalog> pipelines() async {
    try {
      final response = await _client.get('$_base/pipelines');
      return PipelineCatalog.fromJson(response.object);
    } on NotFoundException {
      return PipelineCatalog.legacy;
    }
  }

  /// Query of `GET /sales-opportunities` (`SalesOpportunityController::index`):
  /// `opportunity_stage` is the raw code, `pipeline` scopes it (the default
  /// pipeline also matches records with no `pipeline`), `owner=me` is the
  /// current user.
  @visibleForTesting
  static Map<String, dynamic> listQuery({
    String? stageCode,
    String? pipeline,
    bool mine = false,
    String? search,
    int page = 1,
    int perPage = AppConfig.defaultPerPage,
  }) => {
    if (stageCode != null && stageCode.isNotEmpty)
      'opportunity_stage': stageCode,
    'pipeline': ?pipeline,
    if (mine) 'owner': 'me',
    if (search != null && search.isNotEmpty) 'search': search,
    'page': page,
    'per_page': perPage,
  };

  Future<Paged<Opportunity>> list({
    String? stageCode,
    String? pipeline,
    bool mine = false,
    String? search,
    int page = 1,
    int perPage = AppConfig.defaultPerPage,
  }) async {
    final response = await _client.get(
      _base,
      query: listQuery(
        stageCode: stageCode,
        pipeline: pipeline,
        mine: mine,
        search: search,
        page: page,
        perPage: perPage,
      ),
    );
    return Paged(
      items: response.list.map(Opportunity.fromJson).toList(),
      pagination: response.pagination ?? const ApiPagination.empty(),
    );
  }

  /// Per-stage counts and totals without pulling the records. Takes the same
  /// `pipeline`/`owner` filters as [list] (`applyListFilters`), so the tab
  /// counts match the columns.
  Future<PipelineSummary> summary({String? pipeline, bool mine = false}) async {
    final response = await _client.get(
      '$_base/summary',
      query: {'pipeline': ?pipeline, if (mine) 'owner': 'me'},
    );
    return PipelineSummary.fromJson(response.object);
  }

  Future<Opportunity> get(String id) async {
    final response = await _client.get('$_base/$id');
    return Opportunity.fromJson(response.object);
  }

  Future<Opportunity> create(Opportunity draft) async {
    final response = await _client.post(_base, body: draft.toPayload());
    return Opportunity.fromJson(response.object);
  }

  Future<Opportunity> update(String id, Opportunity draft) async {
    final response = await _client.put('$_base/$id', body: draft.toPayload());
    return Opportunity.fromJson(response.object);
  }

  /// Dedicated endpoint — moving a stage is not a general edit, and the server
  /// logs it to the customer timeline.
  ///
  /// Only `opportunity_stage` is sent: `UpdateOpportunityStageRequest` reads
  /// nothing else, and the server checks the code against the record's stored
  /// pipeline (422 when it is not one of its stages).
  Future<Opportunity> moveStage(String id, {required String stageCode}) async {
    final response = await _client.patch(
      '$_base/$id/stage',
      body: {'opportunity_stage': stageCode},
    );
    return Opportunity.fromJson(response.object);
  }

  Future<WinResult> markWon(String id) async {
    final response = await _client.post('$_base/$id/win');
    return parseWin(response.object);
  }

  /// `{opportunity, order_id, order_created, overrides_ignored}`.
  @visibleForTesting
  static WinResult parseWin(Map<String, dynamic> data) {
    final opportunity = data['opportunity'];
    final orderId = data['order_id'];
    return (
      opportunity: Opportunity.fromJson(
        opportunity is Map ? opportunity.cast<String, dynamic>() : const {},
      ),
      orderId: orderId is String && orderId.isNotEmpty ? orderId : null,
      orderCreated: data['order_created'] == true,
    );
  }

  Future<void> delete(String id) => _client.delete('$_base/$id');
}

final opportunitiesApiProvider = Provider<OpportunitiesApi>((ref) {
  return OpportunitiesApi(ref.watch(apiClientProvider));
});
