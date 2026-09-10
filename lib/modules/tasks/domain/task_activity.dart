import '../../../core/utils/formatters.dart';
import '../../../core/utils/json.dart';
import 'task.dart' show TaskSection;

/// Loại việc đã xảy ra trên một cây đàn.
///
/// Chín loại `TaskActivityService` bên API thật sự ghi. Giá trị lạ rơi về
/// [other] và VẪN hiện: một client cũ gặp loại mới phải nói "có thay đổi" chứ
/// không được giấu cả dòng.
///
/// Trùng tên với `FeedKind` bên module `plans`, và trùng cố ý: `tasks` không
/// được import `plans` (vòng phụ thuộc — xem `module_cycle_test.dart`), và cái
/// được sao chép ở đây là một enum chín giá trị. Cái tránh được là một cạnh
/// trong đồ thị, đúng lập luận đã dùng cho [TaskSection].
enum TaskActivityKind {
  created,
  status,
  section,
  dueDate,
  assignees,
  subtaskCompleted,
  subtaskAssigned,
  attachmentAdded,
  attachmentRemoved,
  other;

  static TaskActivityKind parse(String? value) => switch (value?.trim()) {
    'created' => created,
    'status' => status,
    'section_id' => section,
    'due_date' => dueDate,
    'assignees' => assignees,
    'subtask_completed' => subtaskCompleted,
    'subtask_assigned' => subtaskAssigned,
    'attachment_added' => attachmentAdded,
    'attachment_removed' => attachmentRemoved,
    _ => other,
  };
}

/// Một dòng nhật ký của MỘT công việc.
///
/// Khác dòng thời gian toàn xưởng ở đúng một chỗ, và chỗ đó là lý do màn này
/// đáng tồn tại: ở đây app biết công việc thuộc kế hoạch nào, nên nó dịch được
/// `from`/`to` — vốn là ID nhóm việc — thành TÊN. Dòng thời gian toàn xưởng
/// không kéo theo kế hoạch nào nên nó chỉ nói được "đã chuyển nhóm việc"; ở
/// đây nói được "đã chuyển Nhập xưởng → Chờ QC", và đó chính là câu trả lời
/// cho "ai đã kéo cây này về lại".
class TaskActivityEntry {
  const TaskActivityEntry({
    required this.id,
    required this.kind,
    this.at,
    this.userName,
    this.from,
    this.to,
    this.detail,
  });

  factory TaskActivityEntry.fromJson(Map<String, dynamic> json) =>
      TaskActivityEntry(
        id: json.strOr('id', ''),
        kind: TaskActivityKind.parse(json.str('type')),
        at: DateUtilsX.parse(json['created_at']),
        // API chỉ đặt `user_name` khi tra được. Không tra được thì để trống —
        // một UUID trên nhật ký nói ít hơn là không nói gì.
        userName: json.str('user_name'),
        from: json.str('from'),
        to: json.str('to'),
        // Hai khoá khác nhau cho cùng một vai trò: `subtask_completed` mang
        // `title` (tên việc con), `attachment_added` mang `name` (tên tệp).
        detail: json.str('title') ?? json.str('name'),
      );

  final String id;
  final TaskActivityKind kind;
  final DateTime? at;
  final String? userName;

  /// Với [TaskActivityKind.section] đây là ID nhóm việc; [summary] dịch nó ra
  /// tên bằng danh sách nhóm việc của kế hoạch.
  final String? from;
  final String? to;

  /// Tên việc con (khi tick) hoặc tên tệp (khi đính kèm).
  final String? detail;

  /// Câu mô tả, viết theo cách người xưởng nói.
  ///
  /// [sections] là các nhóm việc của kế hoạch chứa công việc này —
  /// `Task.planSections`, thứ API gửi kèm ở phản hồi CHI TIẾT. Rỗng thì câu
  /// vẫn đọc được, chỉ mất phần tên cột: một id in ra màn hình còn tệ hơn
  /// không in gì.
  String summary(List<TaskSection> sections) => switch (kind) {
    TaskActivityKind.created => 'đã tạo việc',
    TaskActivityKind.section => switch (_move(sections)) {
      final String s => 'đã chuyển $s',
      _ => 'đã chuyển nhóm việc',
    },
    TaskActivityKind.status => 'đã đổi trạng thái',
    TaskActivityKind.dueDate => 'đã đổi hạn',
    TaskActivityKind.assignees => 'đã đổi người làm',
    TaskActivityKind.subtaskCompleted => switch (detail) {
      final String s when s.isNotEmpty => 'đã xong $s',
      _ => 'đã xong một việc con',
    },
    TaskActivityKind.subtaskAssigned => 'đã giao một việc con',
    TaskActivityKind.attachmentAdded => switch (detail) {
      final String s when s.isNotEmpty => 'đã gửi $s',
      _ => 'đã gửi tệp đính kèm',
    },
    TaskActivityKind.attachmentRemoved => 'đã gỡ tệp đính kèm',
    TaskActivityKind.other => 'đã có thay đổi',
  };

  /// "Nhập xưởng → Chờ QC", hoặc null khi không dựng nổi câu đó.
  ///
  /// Cần TÊN đích để câu có nghĩa. Thiếu tên nguồn thì vẫn nói được "sang Chờ
  /// QC"; thiếu tên đích thì không — "từ Nhập xưởng sang đâu đó" là một câu
  /// không trả lời gì.
  String? _move(List<TaskSection> sections) {
    final target = _nameOf(to, sections);
    if (target == null) return null;

    final source = _nameOf(from, sections);

    return source == null ? 'sang $target' : '$source → $target';
  }

  static String? _nameOf(String? id, List<TaskSection> sections) {
    if (id == null || id.isEmpty) return null;
    for (final section in sections) {
      if (section.id == id) return section.name;
    }

    // Nhóm việc đã bị xoá khỏi kế hoạch. Dòng nhật ký thì vẫn đúng — nó ghi
    // chuyện đã xảy ra — nên trả về null để câu lùi về dạng chung, chứ không
    // in ra một id.
    return null;
  }
}
