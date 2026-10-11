import '../../../security/permissions/access_policy.dart';
import '../../../security/permissions/access_scope.dart';
import '../../../security/permissions/resource_access.dart';

/// The task module's permission vocabulary, owned by the task module.
///
/// Mirrors `modules/Tasks/Interfaces/routes.php` on the API, which gates reads
/// behind `tasks.read` and every mutation behind `tasks.write`. Unlike the
/// inbox there is no `.own` variant: per-project roles do the narrowing
/// server-side, so the client has one read permission and one write permission.
abstract final class TaskPermissions {
  static const read = 'tasks.read';

  static const write = 'tasks.write';

  /// Quản lý được MỌI dự án, không chỉ dự án mình là thành viên.
  ///
  /// Đây là ranh giới giữa người GIAO việc và người NHẬN việc. Bốn vai hệ
  /// thống của API chia đúng ở đây: `admin` và `manager` giữ nó, `sales` và
  /// `support` thì không — trong khi cả bốn đều giữ [read] và [write]. Nghĩa
  /// là ranh giới này quan sát được ngay với tài khoản đang có, không cần
  /// thêm vai mới.
  ///
  /// Khớp với `ProjectAccessService::MANAGE_ALL_PERMISSION` bên API.
  static const manageAllProjects = 'tasks.projects.manage.all';

  /// Đọc bộ nhãn công ty (`GET /system-options?group_key=TASK_LABEL`).
  ///
  /// Không phải quyền của module tasks mà của `system_options`: API chưa mở
  /// đường đọc nhãn cho `tasks.read`, nên người thợ thiếu quyền này thấy mã
  /// nhãn mà không có tên và màu.
  static const readLabels = 'system_options.read';

  /// Tạo và sửa nhãn (`POST`/`PUT /system-options`).
  static const writeLabels = 'system_options.write';

  static const all = [read, write];

  static const anyRead = [read];
}

class TaskAccess extends ResourceAccess {
  TaskAccess._({
    required super.readScope,
    required bool canWrite,
    required this.isAssigner,
    this.canReadLabels = false,
    this.canEditLabels = false,
  }) : super(
         canCreate: canWrite,
         canUpdate: canWrite,
         canDelete: canWrite,
         capabilities: canWrite
             ? const {'complete', 'comment', 'attach'}
             : const {},
       );

  /// Người này GIAO việc, chứ không chỉ nhận việc.
  ///
  /// Mở thêm màn tổng quan dự án, nút tạo dự án, gán người, đổi hạn và
  /// xếp thứ tự hàng đợi. Đây là quyền CỘNG THÊM, không phải một vai thay
  /// thế: quản đốc cũng tick công đoạn như thợ.
  ///
  /// Suy từ quyền, không từ tên vai trò — vai trò do từng tenant tự cấu hình,
  /// nên `session.dart` cấm enum vai trò phía client.
  final bool isAssigner;

  factory TaskAccess.of(AccessPolicy policy) {
    final canRead = policy.can(TaskPermissions.read);

    return TaskAccess._(
      // Người có `tasks.read` thấy mọi việc; xem hàng việc của người khác theo
      // `assignee_id` cần `tasks.projects.manage.all` (API trả 403).
      readScope: canRead ? AccessScope.all : AccessScope.none,
      canWrite: policy.can(TaskPermissions.write),
      isAssigner: policy.can(TaskPermissions.manageAllProjects),
      canReadLabels: policy.can(TaskPermissions.readLabels),
      canEditLabels: policy.can(TaskPermissions.writeLabels),
    );
  }

  /// Đọc được danh mục nhãn (tên, màu). Thiếu thì app không gọi mạng và chỉ
  /// có mã nhãn.
  final bool canReadLabels;

  /// Tạo / sửa nhãn trong sheet Nhãn màu. Thiếu thì ẩn bút sửa và "Nhãn mới".
  final bool canEditLabels;

  /// Ticking a stage, changing status — the whole point of the app for a worker.
  bool get canComplete => can('complete');

  bool get canComment => can('comment');

  bool get canAttach => can('attach');
}
