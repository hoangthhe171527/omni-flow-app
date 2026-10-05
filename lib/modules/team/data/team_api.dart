import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_envelope.dart';
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
  static const maxPages = 60;

  /// Số lượt gọi song song khi đọc các trang còn lại và các lô `ids=`: đủ để
  /// 6.000 người không thành 120 vòng mạng tuần tự, mà không dội cả trăm
  /// request vào server cùng lúc (review I2).
  static const parallelism = 4;

  /// Danh bạ ĐẦY ĐỦ của workspace — như `teamApi.listDirectory` của web
  /// (APP-I10, NT-I14, MS-I34).
  ///
  /// - Mọi trang `/memberships`, MỌI trạng thái: người đã nghỉ vẫn phải tra
  ///   được tên trong lịch sử (việc, hội thoại cũ). Danh sách và bộ chọn KHÔNG
  ///   đọc thẳng cái này — xem `teamMembersProvider` (chỉ người chọn được).
  /// - Trang 1 trước để biết `last_page`, rồi các trang còn lại song song
  ///   [parallelism] lượt một, tới trần [maxPages].
  /// - Tên tra theo ĐÚNG tập `user_id` bằng `/identity/users?ids=` từng lô
  ///   100, cũng song song có giới hạn. Tra tên lỗi thì vẫn trả thành viên
  ///   với tên dự phòng.
  /// - Một người có hai membership (dòng cũ đã nghỉ và dòng mới đang làm):
  ///   giữ MỘT dòng — dòng đang làm, không có thì dòng mới nhất.
  Future<List<TeamMember>> members({String? search}) async {
    Future<ApiEnvelope> page(int n) => _client.get(
      '/memberships',
      query: {
        'per_page': AppConfig.maxPerPage,
        'page': n,
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );

    final first = await page(1);
    final memberships = <Map<String, dynamic>>[...first.list];
    final lastPage = first.list.isEmpty
        ? 1
        : (first.pagination?.lastPage ?? 1).clamp(1, maxPages);
    final rest = await _bounded([
      for (var n = 2; n <= lastPage; n++) () => page(n),
    ]);
    for (final response in rest) {
      memberships.addAll(response.list);
    }

    final rows = _onePerUser(memberships);
    final users = await _usersByIds([
      for (final m in rows)
        if (m.str('user_id') case final id? when id.isNotEmpty) id,
    ]);

    return rows
        .map(
          (membership) => TeamMember.fromJson(
            membership,
            users[membership.strOr('user_id', '')],
          ),
        )
        .where((member) => member.userId.isNotEmpty)
        .toList();
  }

  /// Tên của MỘT người — cho chỗ chỉ cần một cái tên (người phụ trách cơ
  /// hội), khỏi kéo cả danh bạ. null khi không tra được.
  Future<String?> userName(String userId) async {
    final response = await _client.get(
      '/identity/users',
      query: {'ids': userId, 'per_page': 1},
    );
    for (final user in response.list) {
      if (user.str('id') == userId) return user.str('full_name');
    }
    return null;
  }

  /// Mỗi `user_id` một dòng: dòng `active` thắng; cùng hạng thì dòng có
  /// `created_at` mới hơn; không có mốc thì dòng gặp trước (API trả mới nhất
  /// trước). Thứ tự giữ theo lần đầu gặp người đó.
  static List<Map<String, dynamic>> _onePerUser(
    List<Map<String, dynamic>> memberships,
  ) {
    final byUser = <String, Map<String, dynamic>>{};
    final order = <String>[];
    for (final row in memberships) {
      final userId = row.strOr('user_id', '');
      final kept = byUser[userId];
      if (kept == null) {
        byUser[userId] = row;
        order.add(userId);
      } else if (_better(row, kept)) {
        byUser[userId] = row;
      }
    }
    return [for (final userId in order) byUser[userId]!];
  }

  static bool _better(Map<String, dynamic> a, Map<String, dynamic> b) {
    final aActive = a.strOr('status', 'active') == 'active';
    final bActive = b.strOr('status', 'active') == 'active';
    if (aActive != bActive) return aActive;
    final aAt = DateTime.tryParse(a.strOr('created_at', ''));
    final bAt = DateTime.tryParse(b.strOr('created_at', ''));
    if (aAt == null || bAt == null) return false;
    return aAt.isAfter(bAt);
  }

  /// `/identity/users?ids=` theo lô 100. Một lô lỗi thì bỏ lô đó (tên dự
  /// phòng), không làm hỏng cả danh bạ.
  Future<Map<String, Map<String, dynamic>>> _usersByIds(
    List<String> ids,
  ) async {
    final unique = ids.toSet().toList();
    const chunk = AppConfig.maxPerPage;
    final batches = [
      for (var start = 0; start < unique.length; start += chunk)
        unique.sublist(
          start,
          start + chunk > unique.length ? unique.length : start + chunk,
        ),
    ];
    final responses = await _bounded([
      for (final batch in batches)
        () async {
          try {
            return (await _client.get(
              '/identity/users',
              query: {'ids': batch.join(','), 'per_page': AppConfig.maxPerPage},
            )).list;
          } on AppException {
            return const <Map<String, dynamic>>[];
          }
        },
    ]);
    return {
      for (final list in responses)
        for (final user in list) user.strOr('id', ''): user,
    };
  }

  /// Chạy [tasks] tối đa [parallelism] lượt cùng lúc; kết quả giữ thứ tự.
  static Future<List<T>> _bounded<T>(List<Future<T> Function()> tasks) async {
    final results = <T>[];
    for (var start = 0; start < tasks.length; start += parallelism) {
      final end = start + parallelism > tasks.length
          ? tasks.length
          : start + parallelism;
      results.addAll(
        await Future.wait([
          for (final task in tasks.sublist(start, end)) task(),
        ]),
      );
    }
    return results;
  }
}

final teamApiProvider = Provider<TeamApi>(
  (ref) => TeamApi(ref.watch(apiClientProvider)),
);
