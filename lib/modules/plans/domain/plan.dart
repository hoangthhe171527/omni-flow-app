import '../../../core/utils/formatters.dart';
import '../../../core/utils/json.dart';

/// Vai của một người TRONG MỘT KẾ HOẠCH.
///
/// Khác với quyền toàn hệ thống (`tasks.read`, `tasks.projects.manage.all`):
/// một người có thể là quản đốc của dự án "Đàn cơ" mà chỉ là người xem ở
/// dự án "Đàn điện".
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

  /// Sửa được dự án: đổi nhóm việc, thêm người, gán việc.
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
  const PlanSection({
    required this.id,
    required this.name,
    this.order,
    this.requiresChecklist = false,
    this.countsForKpi = false,
  });

  factory PlanSection.fromJson(Map<String, dynamic> json) => PlanSection(
    id: json.strOr('id', ''),
    name: json.strOr('name', 'Nhóm chưa đặt tên'),
    // null chứ không 0: "chưa đặt thứ tự" khác "đứng đầu", và phân biệt được
    // hai cái đó là điều giữ cho thứ tự API trả về không bị xáo lại.
    order: json['order'] is num ? (json['order'] as num).toInt() : null,
    requiresChecklist: json.flag('requires_checklist'),
    countsForKpi: json.flag('counts_for_kpi'),
  );

  final String id;
  final String name;
  final int? order;

  /// Cổng: vào nhóm này thì mọi việc con phải xong trước (§B3).
  ///
  /// App không tự đặt cờ này ở đâu ngoài lúc tạo dự án, nhưng nó PHẢI đọc
  /// được: `PUT /projects/{id}` thay cả mảng `sections`, nên sửa tên một nhóm
  /// mà không mang cờ theo là xoá sạch cổng QC của cả dự án — im lặng.
  final bool requiresChecklist;

  /// Nhóm này là ĐÍCH đếm KPI tháng (§B4). Mất nó thì thẻ KPI về 0 và trông
  /// hệt như một tháng chưa ai làm được gì.
  final bool countsForKpi;
}

/// Một dự án — `project` phía API.
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
    this.teamName,
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
    final sections = json
        .mapList('sections')
        .map(PlanSection.fromJson)
        .toList();
    final stats = json.child('stats');

    // Chỉ sắp lại khi MỌI nhóm đều có order. Thiếu dù một cái thì API đã sắp
    // sẵn rồi, và tự sắp lại là bịa ra một thứ tự mà xưởng không hề chọn.
    if (sections.isNotEmpty && sections.every((s) => s.order != null)) {
      sections.sort((a, b) => a.order!.compareTo(b.order!));
    }

    return Plan(
      id: json.strOr('id', ''),
      name: json.strOr('name', 'Dự án chưa đặt tên'),
      description: json.str('description'),
      color: json.str('color'),
      status: json.strOr('status', 'active'),
      // null với mọi dự án tạo trước tầng Team — tức là gần như tất cả
      // những gì đang có trong cơ sở dữ liệu hôm nay.
      teamId: json.str('team_id'),
      teamName: json.str('team_name'),
      sections: sections,
      memberIds: json.strList('member_ids'),
      memberRoles: json
          .child('member_roles')
          .map((userId, role) => MapEntry(userId, PlanRole.parse('$role'))),
      startDate: DateUtilsX.parse(json['start_date']),
      endDate: DateUtilsX.parse(json['end_date']),
      // API gói ba con số này trong `stats`, không rải phẳng ra ngoài — xem
      // `MongoProjectRepository::attachStats()`. Bản đầu của file này đoán
      // `tasks_count`/`done_count`/`overdue_count` và mọi dự án hiện "Chưa
      // có việc nào" dù có 5 cây đàn. Đúng cái bẫy đã bắt `assignee=me`:
      // một cái tên đoán ra không báo lỗi, nó chỉ trả về 0 mãi mãi.
      taskCount: stats.intOr('total'),
      doneCount: stats.intOr('done'),
      overdueCount: stats.intOr('overdue'),
    );
  }

  final String id;
  final String name;
  final String? description;
  final String? color;
  final String status;
  final String? teamId;

  /// Tên tổ, do API giải sẵn.
  ///
  /// Đây là mảnh chữa tận gốc cho một lỗi im lặng: `team_id` từng được app tra
  /// trong `GET /teams` còn web tra trong `GET /org-units` — hai bảng khác
  /// nhau — nên mỗi dự án tạo ở bên này hiện "chưa xếp nhóm" ở bên kia. Chừng
  /// nào client còn phải tự tra id ra tên thì còn chỗ để tra nhầm bảng.
  ///
  /// null nghĩa là dự án thật sự chưa xếp tổ, hoặc tổ đã bị xoá. Hai chuyện
  /// khác nhau với cơ sở dữ liệu, cùng một câu trả lời với người dùng.
  final String? teamName;

  final List<PlanSection> sections;
  final List<String> memberIds;
  final Map<String, PlanRole> memberRoles;
  final DateTime? startDate;
  final DateTime? endDate;

  final int taskCount;
  final int doneCount;
  final int overdueCount;

  /// Vai của một người trong dự án này. Không có tên trong bảng thì là
  /// người xem — cùng lý do với [PlanRole.parse].
  PlanRole roleOf(String userId) => memberRoles[userId] ?? PlanRole.viewer;

  /// 0.0–1.0, và 0 chứ không phải NaN khi chưa có việc nào.
  double get progress => taskCount == 0 ? 0 : doneCount / taskCount;

  bool get isArchived => status == 'archived';
}
