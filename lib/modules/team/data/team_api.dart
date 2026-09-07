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
  /// Liên kết (hoặc GỠ) tài khoản Zalo của một thành viên.
  ///
  /// Chuỗi rỗng là gỡ: `UpdateMembershipDTO` chỉ lọc bỏ null, nên rỗng đi qua
  /// được và ghi đè thành rỗng — đúng thứ cần khi một người nghỉ việc.
  ///
  /// Cần quyền `membership.members.update`, tức là quản đốc trở lên. Đó là cả
  /// điểm của cơ chế: bot không được tự nhận ra ai vừa nhắn, mà phải dựa vào
  /// một liên kết người có thẩm quyền đã tự tay tạo (§G4).
  Future<void> setZaloUserId(String membershipId, String zaloUserId) => _client
      .put('/memberships/$membershipId', body: {'zalo_user_id': zaloUserId});

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
