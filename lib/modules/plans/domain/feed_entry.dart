import '../../../core/utils/formatters.dart';
import '../../../core/utils/json.dart';

/// Loại việc đã xảy ra trên một cây đàn.
///
/// CHÍN loại `TaskActivityService` thật sự ghi. Bản đầu chỉ đọc năm, và bốn
/// loại còn lại rơi hết về [other] — trong đó có `subtask_completed` và
/// `attachment_added`, tức là **tick xong một việc con** và **gửi ảnh**: hai
/// việc thợ làm nhiều nhất trong ngày (§B2 "xong việc nào tick việc đó, kèm
/// ảnh nếu cần").
///
/// Hậu quả là dòng thời gian đọc lên toàn "đã có thay đổi" — đúng số dòng,
/// nhưng không nói được ai vừa làm gì, mà đó là toàn bộ lý do màn này tồn tại.
///
/// Giá trị lạ vẫn rơi về [other] và vẫn hiện: một client cũ gặp loại mới phải
/// nói "có thay đổi" chứ không được giấu cả dòng.
enum FeedKind {
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

  static FeedKind parse(String? value) => switch (value?.trim()) {
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

/// Một dòng trên dòng thời gian của xưởng.
class FeedEntry {
  const FeedEntry({
    required this.id,
    required this.kind,
    required this.taskId,
    required this.taskTitle,
    this.at,
    this.userName,
    this.from,
    this.to,
    this.detail,
    this.planName,
    this.imageUrl,
  });

  factory FeedEntry.fromJson(Map<String, dynamic> json) => FeedEntry(
    id: json.strOr('id', ''),
    kind: FeedKind.parse(json.str('type')),
    taskId: json.strOr('task_id', ''),
    // Một dòng không nói cây nào thì vô dụng, nhưng cũng không đáng để giấu.
    taskTitle: json.strOr('task_title', 'Công việc'),
    at: DateUtilsX.parse(json['created_at']),
    // API chỉ đặt `user_name` khi tra được. Không tra được thì để trống —
    // một UUID trên dòng thời gian nói ít hơn là không nói gì.
    userName: json.str('user_name'),
    from: json.str('from'),
    to: json.str('to'),
    // Hai khoá khác nhau cho cùng một vai trò: `subtask_completed` mang
    // `title` (tên việc con), `attachment_added` mang `name` (tên tệp). Đọc
    // cả hai ở đây thay vì bắt màn hình biết loại nào dùng khoá nào.
    detail: json.str('title') ?? json.str('name'),
    planName: json.str('project_name'),
    // Chỉ ẢNH mới hiện thumbnail. Một tệp PDF render ra ô vỡ thì tệ hơn là
    // không render gì.
    imageUrl: json.str('type') == 'image' ? json.str('url') : null,
  );

  final String id;
  final FeedKind kind;
  final String taskId;
  final String taskTitle;
  final DateTime? at;
  final String? userName;

  /// Với [FeedKind.section] đây là ID nhóm việc, không phải tên — tên nhóm
  /// việc sống trên dự án, và dòng thời gian không kéo theo dự án nào.
  final String? from;
  final String? to;

  /// Tên việc con (khi tick) hoặc tên tệp (khi đính kèm). Null khi loại
  /// hoạt động không mang theo gì để gọi tên.
  final String? detail;

  /// Dự án chứa công việc này. Một xưởng chạy hai dự án song song thì
  /// "cây nào" chưa đủ — còn phải biết "của tháng nào".
  final String? planName;

  /// Ảnh đính kèm, để hiện ngay trên dòng. §B2 nói ảnh CHÍNH LÀ bằng chứng
  /// của công đoạn, nên bắt mở từng cây ra để xem là bỏ mất lý do người ta
  /// lướt dòng thời gian.
  final String? imageUrl;

  /// Câu mô tả, viết theo cách người xưởng nói.
  ///
  /// Không ghép tên nhóm việc vào đây: `from`/`to` là ID, và in một ID ra màn
  /// hình còn tệ hơn không in gì. Màn hình biết cây đàn nào, và mở nó ra là
  /// thấy nhóm việc hiện tại.
  String get summary => switch (kind) {
    FeedKind.created => 'đã tạo việc',
    FeedKind.section => 'đã chuyển nhóm việc',
    FeedKind.status => 'đã đổi trạng thái',
    FeedKind.dueDate => 'đã đổi hạn',
    FeedKind.assignees => 'đã đổi người làm',
    // Gọi thẳng tên việc con khi biết. "đã xong Body ngoài" là một câu quản
    // đốc đọc lướt hiểu ngay; "đã hoàn thành việc con" thì phải mở cây đàn ra
    // mới biết việc con nào.
    FeedKind.subtaskCompleted => switch (detail) {
      final String s when s.isNotEmpty => 'đã xong $s',
      _ => 'đã xong một việc con',
    },
    FeedKind.subtaskAssigned => 'đã giao một việc con',
    // Ảnh là bằng chứng của §B2, nên nói rõ có tệp gì chứ không nói chung chung.
    FeedKind.attachmentAdded => switch (detail) {
      final String s when s.isNotEmpty => 'đã gửi $s',
      _ => 'đã gửi tệp đính kèm',
    },
    FeedKind.attachmentRemoved => 'đã gỡ tệp đính kèm',
    FeedKind.other => 'đã có thay đổi',
  };
}
