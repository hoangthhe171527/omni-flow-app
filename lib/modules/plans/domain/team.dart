import '../../../core/utils/json.dart';

/// Một nhóm người, và là chỗ chứa các dự án.
///
/// Tầng trên cùng của cây myXteam: Team → Dự án → Nhóm việc → Công việc.
/// Với xưởng piano thường chỉ có một team ("Xưởng TNP") chứa hai dự án —
/// đàn cơ và đàn điện. Tầng này tồn tại để khi xưởng mở tổ thứ hai thì không
/// phải dựng lại gì.
class Team {
  const Team({
    required this.id,
    required this.name,
    this.description,
    this.color,
    this.memberIds = const [],
  });

  factory Team.fromJson(Map<String, dynamic> json) => Team(
    id: json.strOr('id', ''),
    // Một team không tên vẫn phải bấm được, nếu không nó thành một hàng trống
    // không ai mở ra được để sửa.
    name: json.strOr('name', 'Team chưa đặt tên'),
    description: json.str('description'),
    color: json.str('color'),
    memberIds: json.strList('member_ids'),
  );

  final String id;
  final String name;
  final String? description;
  final String? color;
  final List<String> memberIds;

  int get memberCount => memberIds.length;
}
