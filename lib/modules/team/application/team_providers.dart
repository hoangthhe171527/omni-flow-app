import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/team_api.dart';
import '../domain/team_member.dart';

/// Danh bạ ĐẦY ĐỦ, giữ suốt phiên: MỌI trạng thái, kể cả người đã nghỉ và lời
/// mời chưa nhận — để tên trong lịch sử (việc, hội thoại cũ) vẫn tra được.
///
/// Chỉ dùng để TRA TÊN ([teamMemberByIdProvider]) và cho màn Nhân viên (tự
/// lọc). Danh sách để CHỌN người thì đọc [teamMembersProvider]. Làm mới (sau
/// khi mời, ngừng hoạt động, liên kết Zalo, bấm "Thử lại") thì invalidate
/// provider NÀY — hai provider kia dựng lại theo.
final teamDirectoryProvider = FutureProvider<List<TeamMember>>((ref) {
  return ref.watch(teamApiProvider).members();
});

/// Người CHỌN ĐƯỢC: đang làm và đã nhận lời mời ([TeamMember.isSelectable]).
///
/// Mặc định an toàn: bộ chọn nào đọc provider này thì không thể quên lọc —
/// giao việc cho người đã nghỉ hay lời mời chưa nhận là 422 "phải là thành
/// viên đang làm" (review I1).
final teamMembersProvider = FutureProvider<List<TeamMember>>((ref) async {
  final all = await ref.watch(teamDirectoryProvider.future);
  return [
    for (final member in all)
      if (member.isSelectable) member,
  ];
});

/// Name lookup by user id — turns an `assignee` id on a conversation into a
/// person without each screen refetching the roster. Có cả người đã nghỉ.
final teamMemberByIdProvider = Provider<Map<String, TeamMember>>((ref) {
  final members = ref.watch(teamDirectoryProvider).valueOrNull ?? const [];
  return {for (final member in members) member.userId: member};
});

/// Tên của MỘT người, cho chỗ chỉ cần một cái tên (người phụ trách cơ hội):
/// danh bạ đã nạp thì tra trong đó; chưa thì hỏi đúng một người qua
/// `/identity/users?ids=`, không kéo cả danh bạ (review I2). null = không
/// tra được (thiếu quyền, người không còn trong workspace).
final teamUserNameProvider = FutureProvider.autoDispose.family<String?, String>(
  (ref, userId) async {
    if (ref.exists(teamDirectoryProvider)) {
      try {
        final all = await ref.watch(teamDirectoryProvider.future);
        for (final member in all) {
          if (member.userId == userId) return member.name;
        }
        return null;
      } on Object {
        // Danh bạ tải hỏng: vẫn thử hỏi riêng một người.
      }
    }
    return ref.watch(teamApiProvider).userName(userId);
  },
);

/// [selectable] cộng những người ĐANG được chọn mà không còn chọn được (đã
/// nghỉ, lời mời chưa nhận) — tra trong danh bạ [byId] — để bộ chọn vẫn cho
/// gỡ họ ra. Không ai bị lặp.
List<TeamMember> withPickedMembers(
  List<TeamMember> selectable,
  Iterable<String> picked,
  Map<String, TeamMember> byId,
) {
  final shown = {for (final member in selectable) member.userId};
  return [
    ...selectable,
    for (final userId in picked)
      if (!shown.contains(userId)) ?byId[userId],
  ];
}
