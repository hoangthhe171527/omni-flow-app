import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/error/app_exception.dart';
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
  /// Chuỗi rỗng là gỡ. Cái làm nên chuyện là GỬI khoá đó lên: server phân
  /// biệt "có gửi khoá" với "không gửi khoá", vì middleware của Laravel đã
  /// biến chuỗi rỗng thành null trước khi tới controller.
  ///
  /// Chú thích cũ nói ngược lại, và suốt thời gian đó GỠ LIÊN KẾT KHÔNG CHẠY:
  /// API trả 200 với dữ liệu y nguyên, nên người thợ đã nghỉ việc vẫn được bot
  /// xưởng ghi công. Xem `ClearFieldWithEmptyStringTest` bên API.
  ///
  /// Cần quyền `membership.members.update`, tức là quản đốc trở lên. Đó là cả
  /// điểm của cơ chế: bot không được tự nhận ra ai vừa nhắn, mà phải dựa vào
  /// một liên kết người có thẩm quyền đã tự tay tạo (§G4).
  Future<void> setZaloUserId(String membershipId, String zaloUserId) => _client
      .put('/memberships/$membershipId', body: {'zalo_user_id': zaloUserId});

  /// Trần đọc danh bạ: 60 trang × 100 = 6.000 người, như `fetchAllPages` của
  /// web. Hiện không tenant nào gần mức này (TK-20).
  static const _maxPages = 60;

  /// Danh bạ ĐẦY ĐỦ của workspace — như `teamApi.listDirectory` của web
  /// (APP-I10, NT-I14, MS-I34).
  ///
  /// - Mọi trang `/memberships`, MỌI trạng thái: người đã nghỉ vẫn phải tra
  ///   được tên trong lịch sử (việc, hội thoại cũ). Màn danh sách và bộ chọn
  ///   tự lọc ([TeamMember.isActive], [TeamMember.isSelectable]).
  /// - Tên tra theo ĐÚNG tập `user_id` bằng `/identity/users?ids=` từng lô
  ///   100, tuần tự. Bản cũ lấy một trang users không cùng tập với trang
  ///   memberships: người thứ 101 mất khỏi bộ chọn, người lệch trang mang tên
  ///   "Thành viên".
  /// - Tra tên lỗi thì vẫn trả thành viên với tên dự phòng.
  Future<List<TeamMember>> members({String? search}) async {
    final memberships = <Map<String, dynamic>>[];
    for (var page = 1; page <= _maxPages; page++) {
      final response = await _client.get(
        '/memberships',
        query: {
          'per_page': AppConfig.maxPerPage,
          'page': page,
          if (search != null && search.isNotEmpty) 'search': search,
        },
      );
      memberships.addAll(response.list);
      final pagination = response.pagination;
      if (pagination == null ||
          response.list.isEmpty ||
          pagination.currentPage >= pagination.lastPage) {
        break;
      }
    }

    final users = await _usersByIds([
      for (final m in memberships)
        if (m.str('user_id') case final id? when id.isNotEmpty) id,
    ]);

    return memberships
        .map(
          (membership) => TeamMember.fromJson(
            membership,
            users[membership.strOr('user_id', '')],
          ),
        )
        .where((member) => member.userId.isNotEmpty)
        .toList();
  }

  /// `/identity/users?ids=` theo lô 100. Một lô lỗi thì bỏ lô đó (tên dự
  /// phòng), không làm hỏng cả danh bạ.
  Future<Map<String, Map<String, dynamic>>> _usersByIds(
    List<String> ids,
  ) async {
    final unique = ids.toSet().toList();
    final users = <String, Map<String, dynamic>>{};
    const chunk = AppConfig.maxPerPage;
    for (var start = 0; start < unique.length; start += chunk) {
      final batch = unique.sublist(
        start,
        start + chunk > unique.length ? unique.length : start + chunk,
      );
      try {
        final response = await _client.get(
          '/identity/users',
          query: {'ids': batch.join(','), 'per_page': AppConfig.maxPerPage},
        );
        for (final user in response.list) {
          users[user.strOr('id', '')] = user;
        }
      } on AppException {
        // Tên dự phòng cho lô này.
      }
    }
    return users;
  }
}

final teamApiProvider = Provider<TeamApi>(
  (ref) => TeamApi(ref.watch(apiClientProvider)),
);
