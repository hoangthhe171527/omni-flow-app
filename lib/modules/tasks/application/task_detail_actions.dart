import '../domain/task.dart';
import 'task_controller.dart';

/// Các thao tác điều phối của màn chi tiết, tách khỏi widget.
///
/// Mỗi hàm nhận công việc đang hiện và LỰA CHỌN vừa lấy từ sheet, quyết định
/// "có gì để ghi không", rồi gọi [TaskController]. Không context, không sheet,
/// không snackbar: UI mở hộp thoại rồi gọi vào đây. Lỗi API NÉM RA để UI hiện
/// — lớp này không được quyết định thay UI rằng "không sao". Cổng QC từ chối
/// bằng 422 kèm TÊN các công đoạn còn thiếu; nuốt ở đây là quản đốc bấm lại
/// mà không hiểu vì sao thẻ không nhúc nhích.
///
/// Vì sao tách: bảy hàm này từng nằm trong `_Loaded` của một file 1200 dòng,
/// và dựng cả màn rồi mở sheet là cách duy nhất kiểm được "chọn lại đúng danh
/// sách cũ thì KHÔNG gọi API". Ở đây chúng là hàm thuần trên Task + lựa chọn.
class TaskDetailActions {
  const TaskDetailActions(this._controller);

  final TaskController _controller;

  /// Tự nhận việc: THÊM mình vào danh sách người làm.
  ///
  /// Gửi lại CẢ danh sách kèm id của mình, chứ không gửi mỗi id của mình:
  /// `PUT /tasks/{id}` ghi đè `assignee_ids`, nên gửi một mình là lặng lẽ gỡ
  /// những người đang cùng làm ra khỏi việc — họ mất luôn việc trong danh
  /// sách của mình và không có gì báo cho ai biết.
  ///
  /// Không hỏi lại: nhận nhầm thì quản đốc gỡ ra trong một giây, còn thêm một
  /// hộp thoại giữa người thợ và việc họ định làm thì ngày nào cũng tốn.
  Future<void> claim(Task task, String userId) async {
    if (task.assigneeIds.contains(userId)) return;

    await _controller.setAssignees([...task.assigneeIds, userId]);
  }

  /// Giao việc cho ai. [chosen] null = đóng sheet mà không lưu.
  ///
  /// Lưu lại đúng danh sách cũ (bỏ qua thứ tự) cũng không ghi: một lượt ghi
  /// rỗng vẫn chạm `updated_at` lẫn nhật ký hoạt động.
  Future<void> assign(Task task, List<String>? chosen) async {
    if (chosen == null || _sameIds(chosen, task.assigneeIds)) return;

    await _controller.setAssignees(chosen);
  }

  /// Đặt hoặc XOÁ hạn. [value] null = xoá.
  ///
  /// Xoá được là điều kiện đủ để chức năng này dùng thật: đặt nhầm ngày rồi
  /// kẹt luôn thì lần sau người ta không dám đặt nữa. So theo NGÀY, không theo
  /// thời điểm: lịch trả về nửa đêm, còn hạn server có thể mang giờ.
  Future<void> editDueDate(Task task, DateTime? value) async {
    if (_sameDay(value, task.dueDate)) return;

    await _controller.setDueDate(value);
  }

  Future<void> editPriority(Task task, String? chosen) async {
    if (chosen == null || chosen == task.priority) return;

    await _controller.setPriority(chosen);
  }

  Future<void> editTitle(Task task, String? chosen) async {
    if (chosen == null || chosen == task.title) return;

    await _controller.setTitle(chosen);
  }

  /// Chuỗi rỗng là xoá mô tả — một lựa chọn hợp lệ, khác với tên việc.
  Future<void> editDescription(Task task, String? chosen) async {
    if (chosen == null || chosen == (task.description ?? '')) return;

    await _controller.setDescription(chosen);
  }

  /// Chuyển công đoạn. [chosen] null = đóng sheet mà không chọn.
  Future<void> moveSection(Task task, String? chosen) async {
    if (chosen == null || chosen == task.sectionId) return;

    await _controller.moveToSection(chosen);
  }

  /// So hai danh sách người làm mà không quan tâm thứ tự.
  static bool _sameIds(List<String> a, List<String> b) =>
      a.length == b.length && a.toSet().containsAll(b);

  static bool _sameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a == b;

    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
