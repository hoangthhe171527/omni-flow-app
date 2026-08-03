import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_envelope.dart';
import '../domain/opportunity.dart';

class OpportunitiesApi {
  OpportunitiesApi(this._client);

  static const _base = '/sales-opportunities';

  final ApiClient _client;

  Future<Paged<Opportunity>> list({
    PipelineStage? stage,
    String? search,
    String? ownerId,
    int page = 1,
    int perPage = AppConfig.defaultPerPage,
  }) async {
    final response = await _client.get(
      _base,
      query: {
        if (stage case final selected?) 'opportunity_stage': selected.slug,
        if (search != null && search.isNotEmpty) 'search': search,
        'owner_user_id': ?ownerId,
        'page': page,
        'per_page': perPage,
      },
    );
    return Paged(
      items: response.list.map(Opportunity.fromJson).toList(),
      pagination: response.pagination ?? const ApiPagination.empty(),
    );
  }

  /// Per-stage counts and totals without pulling the records.
  Future<PipelineSummary> summary() async {
    final response = await _client.get('$_base/summary');
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
  Future<Opportunity> moveStage(String id, PipelineStage stage) async {
    final response = await _client.patch(
      '$_base/$id/stage',
      body: {'opportunity_stage': stage.slug},
    );
    return Opportunity.fromJson(response.object);
  }

  Future<Opportunity> markWon(String id) async {
    final response = await _client.post('$_base/$id/win');
    return Opportunity.fromJson(response.object);
  }

  Future<void> delete(String id) => _client.delete('$_base/$id');
}

final opportunitiesApiProvider = Provider<OpportunitiesApi>((ref) {
  return OpportunitiesApi(ref.watch(apiClientProvider));
});
