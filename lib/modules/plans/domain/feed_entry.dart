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

  /// Cả cây đàn đã xong.
  ///
  /// KHÔNG có loại này trong nhật ký: server gắn nhãn lúc đọc, cho những lần
  /// chuyển vào một nhóm việc mang cờ `counts_for_kpi` — đúng thứ thẻ KPI đếm.
  /// Suy ở server vì client không có bảng nhóm việc trong tay, và hai client
  /// đoán riêng sẽ đoán khác nhau.
  pianoDone,
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
    'piano_done' => pianoDone,
    // Dạng CŨ. Server từng để loại TỆP ('image'/'file') ghi đè loại HOẠT ĐỘNG
    // trong `TaskActivityService::entry()`, nên những dòng ghi trước bản sửa
    // nằm trong Mongo với `type: 'image'`. Chúng không được backfill và sẽ ở
    // đó mãi; đọc chúng ở đây rẻ hơn một migration, và không có cửa sổ nào
    // dữ liệu hiện sai.
    'image' || 'file' => attachmentAdded,
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
    this.photos = const [],
    this.day = '',
    this.userId,
    this.userAvatar,
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
    //
    // Hai khoá vì hai thời kỳ dữ liệu: `file_type` là dạng mới, `type ==
    // 'image'` là dạng cũ — xem ghi chú ở [FeedKind.parse].
    imageUrl: (json.str('file_type') == 'image' || json.str('type') == 'image')
        ? json.str('url')
        : null,
    // Ảnh server đã gộp sẵn vào dòng này: những `attachment_added` cùng cây
    // đàn, cùng người gửi, trong vòng 15 phút (`FeedPhotoMerge`).
    photos: json.strList('photos'),
    // Ngày lịch theo giờ xưởng, do SERVER tính. Không suy lại từ `at`: máy chủ
    // chạy UTC và ca chiều của xưởng rơi sang ngày hôm sau theo giờ đó.
    day: json.strOr('day', ''),
    userId: json.str('user_id'),
    // Server giải sẵn (`PeopleDirectory`), client không tự tra id ra ảnh —
    // cùng lập luận với `user_name`, và mỗi dòng tự đi hỏi là mỗi dòng một
    // lượt gọi mạng.
    userAvatar: json.str('user_avatar'),
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

  /// Ảnh bằng chứng của chính công đoạn này, server đã gộp sẵn.
  ///
  /// Khác [imageUrl]: cái kia là ảnh của một dòng `attachment_added` đứng
  /// riêng, cái này là ảnh thuộc về một dòng việc xong.
  final List<String> photos;

  /// `YYYY-MM-DD` theo giờ xưởng, do server tính. Rỗng nghĩa là không xếp được
  /// vào ngày nào — [DayGroup] bỏ qua chứ không đoán.
  final String day;

  /// Ai làm. Để widget dòng dựng được ô người.
  final String? userId;

  /// Ảnh đại diện của người làm, server giải sẵn. Null khi họ chưa đặt ảnh —
  /// `OmniAvatar` rơi về chữ cái đầu.
  final String? userAvatar;

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
    FeedKind.pianoDone => 'đã xong toàn bộ',
    FeedKind.other => 'đã có thay đổi',
  };
}
