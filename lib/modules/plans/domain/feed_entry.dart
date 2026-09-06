import '../../../core/utils/formatters.dart';
import '../../../core/utils/json.dart';

/// Loại việc đã xảy ra trên một cây đàn.
///
/// Bốn loại API thật sự ghi (`TaskActivityService::TRACKED` cộng `created` và
/// `assignees`). Giá trị lạ rơi về [other] và vẫn hiện được — một client cũ
/// gặp loại mới phải nói "có thay đổi" chứ không được giấu cả dòng.
enum FeedKind {
  created,
  status,
  section,
  dueDate,
  assignees,
  other;

  static FeedKind parse(String? value) => switch (value?.trim()) {
    'created' => created,
    'status' => status,
    'section_id' => section,
    'due_date' => dueDate,
    'assignees' => assignees,
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
  );

  final String id;
  final FeedKind kind;
  final String taskId;
  final String taskTitle;
  final DateTime? at;
  final String? userName;

  /// Với [FeedKind.section] đây là ID công đoạn, không phải tên — tên công
  /// đoạn sống trên kế hoạch, và dòng thời gian không kéo theo kế hoạch nào.
  final String? from;
  final String? to;

  /// Câu mô tả, viết theo cách người xưởng nói.
  ///
  /// Không ghép tên công đoạn vào đây: `from`/`to` là ID, và in một ID ra màn
  /// hình còn tệ hơn không in gì. Màn hình biết cây đàn nào, và mở nó ra là
  /// thấy công đoạn hiện tại.
  String get summary => switch (kind) {
    FeedKind.created => 'đã nhận vào xưởng',
    FeedKind.section => 'đã chuyển công đoạn',
    FeedKind.status => 'đã đổi trạng thái',
    FeedKind.dueDate => 'đã đổi hạn',
    FeedKind.assignees => 'đã đổi người làm',
    FeedKind.other => 'đã có thay đổi',
  };
}
