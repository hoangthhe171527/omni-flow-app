import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/json.dart';
import '../domain/team_member.dart';

class TeamApi {
  TeamApi(this._client);

  final ApiClient _client;

  /// Memberships carry the tenant role; the user record carries the name and
  /// avatar. The API keeps them apart, so they're joined here rather than in
  /// every screen that needs a person's name.
  Future<List<TeamMember>> members({String? search}) async {
    final responses = await Future.wait([
      _client.get(
        '/memberships',
        query: {
          'per_page': AppConfig.maxPerPage,
          'status': 'active',
          if (search != null && search.isNotEmpty) 'search': search,
        },
      ),
      _client.get('/identity/users', query: {'per_page': AppConfig.maxPerPage}),
    ]);

    final users = {
      for (final user in responses[1].list) user.strOr('id', ''): user,
    };

    return responses[0].list
        .map(
          (membership) => TeamMember.fromJson(
            membership,
            users[membership.strOr('user_id', '')],
          ),
        )
        .where((member) => member.userId.isNotEmpty)
        .toList();
  }
}

final teamApiProvider = Provider<TeamApi>(
  (ref) => TeamApi(ref.watch(apiClientProvider)),
);
