import '../../../core/utils/json.dart';
import 'custom_field.dart';

/// Kế hoạch chứa một việc, như module tasks cần: chủ, thành viên, vai, định
/// nghĩa trường tuỳ chỉnh — đọc thẳng `GET /projects/{id}`.
///
/// Bản sao nhỏ CÓ CHỦ Ý của `Plan` bên module plans: tasks không import plans
/// (`module_cycle_test`). Luật vai chép từ `ProjectAccessService` bên API, KHÔNG
/// từ `Plan.roleOf` của app: server coi người ngoài danh sách là "không vai"
/// (vẫn sửa việc được), chỉ `viewer` ghi rõ mới bị chặn.
class TaskProject {
  const TaskProject({
    this.ownerId,
    this.memberIds = const [],
    this.memberRoles = const {},
    this.customFields = const [],
  });

  factory TaskProject.fromJson(Map<String, dynamic> json) => TaskProject(
    ownerId: json.str('owner_id'),
    memberIds: json.strList('member_ids'),
    // Như `roleFromAttributes` (`isset && !== ''`): vai null hoặc rỗng là
    // KHÔNG có vai ghi rõ — rơi về `member_ids`.
    memberRoles: {
      for (final e in json.child('member_roles').entries)
        if (e.value != null && '${e.value}'.isNotEmpty) e.key: '${e.value}',
    },
    customFields: json
        .mapList('custom_fields')
        .map(CustomFieldDef.fromJson)
        .toList(),
  );

  final String? ownerId;
  final List<String> memberIds;
  final Map<String, String> memberRoles;
  final List<CustomFieldDef> customFields;

  /// `ProjectAccessService::roleFromAttributes`: chủ, rồi vai ghi rõ, rồi
  /// `member` nếu có trong `member_ids`, còn lại null.
  String? roleOf(String? userId) {
    if (userId == null) return null;
    if (ownerId == userId) return 'owner';
    final role = memberRoles[userId];
    if (role != null) return role;

    return memberIds.contains(userId) ? 'member' : null;
  }

  /// `assertCanManage`: `manage.all`, kế hoạch legacy (không chủ), hoặc vai
  /// owner / manager.
  bool canManage(String? userId, {required bool manageAll}) =>
      manageAll ||
      ownerId == null ||
      const {'owner', 'manager'}.contains(roleOf(userId));

  /// `assertCanEditTasks`: chỉ vai `viewer` ghi rõ là chỉ xem.
  bool isViewer(String? userId) => roleOf(userId) == 'viewer';

  /// `member_ids` ∪ chủ.
  List<String> get memberIdsWithOwner => [
    ...memberIds,
    if (ownerId case final owner? when owner.isNotEmpty)
      if (!memberIds.contains(owner)) owner,
  ];
}
