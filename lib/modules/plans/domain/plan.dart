import '../../../core/utils/formatters.dart';
import '../../../core/utils/json.dart';

/// Vai của một người TRONG MỘT KẾ HOẠCH.
///
/// Khác với quyền toàn hệ thống (`tasks.read`, `tasks.projects.manage.all`):
/// một người có thể là quản đốc của kế hoạch "Đàn cơ" mà chỉ là người xem ở
/// kế hoạch "Đàn điện".
///
/// Bốn giá trị này do API định nghĩa — `member_roles` trong
/// `CreateProjectRequest.php` giới hạn đúng `owner|manager|member|viewer`.
/// Đây là chỗ duy nhất phía client được phép có enum vai, và nó hợp lệ vì
/// những vai này KHÔNG do tenant tự cấu hình như vai hệ thống.
enum PlanRole {
  owner,
  manager,
  member,
  viewer;

  /// Sửa được kế hoạch: đổi nhóm việc, thêm người, gán việc.
  ///
  /// Khớp với `ProjectAccessService` phía API — nó cũng chỉ cho owner và
  /// manager. Đây là bản sao để giao diện biết trước; API vẫn kiểm lại.
  bool get canManagePlan => this == owner || this == manager;

  /// Giá trị lạ rơi về [viewer].
  ///
  /// Hướng ít quyền nhất: một client cũ đọc phải một vai mới không được tự
  /// cho mình thêm quyền. Chiều ngược lại — đoán rộng ra — là cách một người
  /// xem bỗng thấy nút xoá.
  static PlanRole parse(String? value) => switch (value?.trim()) {
    'owner' => owner,
    'manager' => manager,
    'member' => member,
    _ => viewer,
  };
}

/// Một cột trên bảng: một công đoạn của xưởng.
///
/// "Nhập xưởng", "Đang phục chế", "Chờ QC", "Hoàn thiện", "Đã giao". Mỗi màn
/// lướt ngang là một nhóm việc.
class PlanSection {
  const PlanSection({required this.id, required this.name, this.order});

  factory PlanSection.fromJson(Map<String, dynamic> json) => PlanSection(
    id: json.strOr('id', ''),
    name: json.strOr('name', 'Nhóm chưa đặt tên'),
    // null chứ không 0: "chưa đặt thứ tự" khác "đứng đầu", và phân biệt được
    // hai cái đó là điều giữ cho thứ tự API trả về không bị xáo lại.
    order: json['order'] is num ? (json['order'] as num).toInt() : null,
  );

  final String id;
  final String name;
  final int? order;
}

/// Một kế hoạch — `project` phía API.
///
/// Với xưởng piano: "Đàn cơ" hoặc "Đàn điện". Bên trong là các nhóm việc
/// (công đoạn), và trong mỗi nhóm là các công việc (mỗi công việc là MỘT CÂY
/// ĐÀN).
class Plan {
  const Plan({
    required this.id,
    required this.name,
    this.description,
    this.color,
    this.status = 'active',
    this.teamId,
    this.sections = const [],
    this.memberIds = const [],
    this.memberRoles = const {},
    this.startDate,
    this.endDate,
    this.taskCount = 0,
    this.doneCount = 0,
    this.overdueCount = 0,
  });

  factory Plan.fromJson(Map<String, dynamic> json) {
    final sections = json.mapList('sections').map(PlanSection.fromJson).toList();

    // Chỉ sắp lại khi MỌI nhóm đều có order. Thiếu dù một cái thì API đã sắp
    // sẵn rồi, và tự sắp lại là bịa ra một thứ tự mà xưởng không hề chọn.
    if (sections.isNotEmpty && sections.every((s) => s.order != null)) {
      sections.sort((a, b) => a.order!.compareTo(b.order!));
    }

    return Plan(
      id: json.strOr('id', ''),
      name: json.strOr('name', 'Kế hoạch chưa đặt tên'),
      description: json.str('description'),
      color: json.str('color'),
      status: json.strOr('status', 'active'),
      // null với mọi kế hoạch tạo trước tầng Team — tức là gần như tất cả
      // những gì đang có trong cơ sở dữ liệu hôm nay.
      teamId: json.str('team_id'),
      sections: sections,
      memberIds: json.strList('member_ids'),
      memberRoles: json.child('member_roles').map(
        (userId, role) => MapEntry(userId, PlanRole.parse('$role')),
      ),
      startDate: DateUtilsX.parse(json['start_date']),
      endDate: DateUtilsX.parse(json['end_date']),
      taskCount: json.intOfAny(['tasks_count', 'task_count']),
      doneCount: json.intOfAny(['done_count', 'completed_count']),
      overdueCount: json.intOfAny(['overdue_count']),
    );
  }

  final String id;
  final String name;
  final String? description;
  final String? color;
  final String status;
  final String? teamId;
  final List<PlanSection> sections;
  final List<String> memberIds;
  final Map<String, PlanRole> memberRoles;
  final DateTime? startDate;
  final DateTime? endDate;

  final int taskCount;
  final int doneCount;
  final int overdueCount;

  /// Vai của một người trong kế hoạch này. Không có tên trong bảng thì là
  /// người xem — cùng lý do với [PlanRole.parse].
  PlanRole roleOf(String userId) => memberRoles[userId] ?? PlanRole.viewer;

  /// 0.0–1.0, và 0 chứ không phải NaN khi chưa có việc nào.
  double get progress => taskCount == 0 ? 0 : doneCount / taskCount;

  bool get isArchived => status == 'archived';
}
