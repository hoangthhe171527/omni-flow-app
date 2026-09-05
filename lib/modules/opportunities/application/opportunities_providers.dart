import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../security/permissions/resource_access.dart';
import '../../../security/session/session_controller.dart';
import '../data/opportunities_api.dart';
import '../domain/opportunity.dart';
import '../domain/opportunity_permissions.dart';

final opportunityAccessProvider = Provider<ResourceAccess>((ref) {
  return OpportunityPermissions.of(ref.watch(accessProvider));
});

/// The stage tab currently shown on the pipeline board.
final selectedStageProvider = StateProvider<PipelineStage>(
  (ref) => PipelineStage.fresh,
);

final pipelineSearchProvider = StateProvider<String>((ref) => '');

final pipelineSummaryProvider = FutureProvider<PipelineSummary>((ref) {
  return ref.watch(opportunitiesApiProvider).summary();
});

/// Opportunities in the selected stage. Keyed on the stage so switching tabs
/// back and forth doesn't refetch what's already loaded.
final stageOpportunitiesProvider = FutureProvider.autoDispose
    .family<List<Opportunity>, PipelineStage>((ref, stage) async {
      final search = ref.watch(pipelineSearchProvider);
      final page = await ref
          .watch(opportunitiesApiProvider)
          .list(stage: stage, search: search.isEmpty ? null : search);
      return page.items;
    });

final opportunityProvider = FutureProvider.autoDispose
    .family<Opportunity, String>((ref, id) {
      return ref.watch(opportunitiesApiProvider).get(id);
    });

/// Moves a deal and refreshes everything that shows a stage total.
Future<Opportunity> moveOpportunityStage(
  WidgetRef ref,
  String id,
  PipelineStage stage,
) async {
  final updated = await ref.read(opportunitiesApiProvider).moveStage(id, stage);
  ref.invalidate(pipelineSummaryProvider);
  ref.invalidate(stageOpportunitiesProvider);
  ref.invalidate(opportunityProvider(id));
  return updated;
}
