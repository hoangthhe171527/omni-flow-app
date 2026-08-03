import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/team_api.dart';
import '../domain/team_member.dart';

/// Cached for the session: the roster changes rarely and every assign sheet
/// needs it. Invalidate after inviting or deactivating someone.
final teamMembersProvider = FutureProvider<List<TeamMember>>((ref) {
  return ref.watch(teamApiProvider).members();
});

/// Name lookup by user id — turns an `assignee` id on a conversation into a
/// person without each screen refetching the roster.
final teamMemberByIdProvider = Provider<Map<String, TeamMember>>((ref) {
  final members = ref.watch(teamMembersProvider).valueOrNull ?? const [];
  return {for (final member in members) member.userId: member};
});
