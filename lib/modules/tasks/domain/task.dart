import '../../../core/utils/formatters.dart';
import '../../../core/utils/json.dart';

/// One step of a task, owned by one person.
///
/// In the workshop a task is a piano and these are its stages — "Nắp phím
/// (Hằng Ni)", "Bộ máy (Luận)" — worked in order by different people. That is
/// why an item carries an owner and a date of its own rather than being a bare
/// line of text.
class Subtask {
  const Subtask({
    required this.id,
    required this.title,
    required this.done,
    this.assigneeId,
    this.assigneeName,
    this.dueDate,
  });

  factory Subtask.fromJson(Map<String, dynamic> json) => Subtask(
    id: json.strOr('id', ''),
    title: json.strOr('title', ''),
    done: json.flag('done'),
    assigneeId: json.str('assignee_id'),
    assigneeName: json.str('assignee_name'),
    dueDate: DateUtilsX.parse(json['due_date']),
  );

  final String id;
  final String title;
  final bool done;
  final String? assigneeId;
  final String? assigneeName;
  final DateTime? dueDate;

  Subtask copyWith({bool? done}) => Subtask(
    id: id,
    title: title,
    done: done ?? this.done,
    assigneeId: assigneeId,
    assigneeName: assigneeName,
    dueDate: dueDate,
  );
}

/// Somebody who has opened this task, and when they last did.
///
/// A seen-list, not an audit log: the manager's question is "did they get it",
/// which one row per person answers and a row per open buries.
class TaskViewer {
  const TaskViewer({required this.userId, this.name, this.viewedAt});

  factory TaskViewer.fromJson(Map<String, dynamic> json) => TaskViewer(
    userId: json.strOr('user_id', ''),
    name: json.str('name'),
    viewedAt: DateUtilsX.parse(json['viewed_at']),
  );

  final String userId;
  final String? name;
  final DateTime? viewedAt;

  /// Falls back to the id rather than showing nothing: the API fills the name
  /// only when it can resolve the membership, and a blank chip is unreadable.
  String get label => (name ?? '').trim().isEmpty ? userId : name!.trim();
}

/// Một bình luận trên công việc.
///
/// §B3: QC không đạt thì bình luận @mention người phụ trách công đoạn lỗi rồi
/// kéo cây về. Đó là chỗ duy nhất trong cả luồng ghi lại LÝ DO một cây bị trả
/// về — nhật ký hoạt động chỉ biết nó đã bị chuyển cột.
class TaskComment {
  const TaskComment({
    required this.id,
    required this.body,
    this.userId,
    this.userName,
    this.mentionedUserNames = const [],
    this.createdAt,
  });

  factory TaskComment.fromJson(Map<String, dynamic> json) => TaskComment(
    id: json.strOr('id', ''),
    body: json.strOr('body', ''),
    userId: json.str('user_id'),
    // API tra tên ra từ danh sách thành viên ở mỗi lần đọc, chứ không lưu tên
    // vào bình luận — để tên không cũ đi trong những bình luận cũ.
    userName: json.str('user_name'),
    // Tên, không phải id: vai thợ không có quyền nhân sự, app không có danh
    // sách nào để tự tra một UUID ra tên người.
    mentionedUserNames: json.strList('mentioned_user_names'),
    createdAt: DateUtilsX.parse(json['created_at']),
  );

  final String id;
  final String body;
  final String? userId;
  final String? userName;
  final List<String> mentionedUserNames;
  final DateTime? createdAt;

  /// Không bao giờ hiện UUID: nó không nói cho ai điều gì.
  String get author {
    final name = (userName ?? '').trim();

    return name.isEmpty ? 'Người đã rời' : name;
  }
}

/// Một tệp đã đính trên công việc — phần lớn là ảnh chụp công đoạn.
///
/// App gửi ảnh lên được từ lâu (nút máy ảnh ở thanh dưới màn chi tiết), và
/// API vẫn trả mảng `attachments` về trong mỗi lần đọc việc. Nhưng `Task`
/// trước đây chỉ đọc `attachments_count` — một khoá API KHÔNG BAO GIỜ gửi —
/// nên mảng bị vứt ngay lúc parse: ảnh gửi xong là mất khỏi điện thoại, muốn
/// xem lại phải mở web. Một con số cũng không thay được chỗ này: nó không cho
/// ai nhìn lại vết xước trên body.
class TaskAttachment {
  const TaskAttachment({
    required this.id,
    required this.url,
    required this.name,
    required this.type,
  });

  factory TaskAttachment.fromJson(Map<String, dynamic> json) => TaskAttachment(
    id: json.strOr('id', ''),
    url: json.strOr('url', ''),
    name: json.strOr('name', 'Tệp'),
    // API đặt 'image' hoặc 'file' theo MIME lúc tải lên. Tài liệu cũ thiếu
    // khoá này thì coi là tệp: hiện cái tên còn hơn hiện một ô ảnh vỡ.
    type: json.strOr('type', 'file'),
  );

  final String id;
  final String url;
  final String name;
  final String type;

  bool get isImage => type == 'image';
}

/// Một công đoạn của kế hoạch, như công việc nhìn thấy nó.
///
/// Bản sao nhỏ của `PlanSection` bên module plans, và CỐ Ý là bản sao: nếu
/// module tasks import kiểu của module plans thì hai module tham chiếu vòng
/// vào nhau, và tới module thứ mười hai thì không ai gỡ ra được nữa.
///
/// Cái được sao chép ở đây là hai chuỗi. Cái tránh được là một cạnh trong đồ
/// thị phụ thuộc.
class TaskSection {
  const TaskSection({required this.id, required this.name});

  factory TaskSection.fromJson(Map<String, dynamic> json) => TaskSection(
    id: json.strOr('id', ''),
    name: json.strOr('name', 'Nhóm chưa đặt tên'),
  );

  final String id;
  final String name;
}

/// A unit of work somebody is responsible for.
class Task {
  const Task({
    required this.id,
    required this.title,
    this.description,
    this.status = 'todo',
    this.priority = 'med',
    this.projectId,
    this.projectName,
    this.sectionId,
    this.sectionName,
    this.planSections = const [],
    this.assigneeIds = const [],
    this.assigneeNames = const [],
    this.dueDate,
    this.startDate,
    this.subtasks = const [],
    this.customFields = const {},
    this.attachments = const [],
    this.attachmentCount = 0,
    this.commentCount = 0,
    this.rating = 0,
    this.viewers = const [],
    this.comments = const [],
  });

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    id: json.strOr('id', ''),
    title: json.strOr('title', ''),
    description: json.str('description'),
    status: json.strOr('status', 'todo'),
    priority: json.strOr('priority', 'med'),
    projectId: json.str('project_id'),
    projectName: json.str('project_name'),
    sectionId: json.str('section_id'),
    sectionName: json.str('section_name'),
    planSections: json
        .mapList('plan_sections')
        .map(TaskSection.fromJson)
        .toList(),
    assigneeIds: json.strList('assignee_ids'),
    assigneeNames: json.strList('assignee_names'),
    // The API writes the deadline as due_date; older documents used deadline.
    // Reading only one of them is how a whole column silently shows "no date".
    dueDate:
        DateUtilsX.parse(json['due_date']) ??
        DateUtilsX.parse(json['deadline']),
    startDate: DateUtilsX.parse(json['start_date']),
    subtasks: json.mapList('checklist').map(Subtask.fromJson).toList(),
    customFields: json.child('custom_fields'),
    attachments: json
        .mapList('attachments')
        .map(TaskAttachment.fromJson)
        .toList(),
    attachmentCount: json.intOr('attachments_count'),
    commentCount: json.intOr('comments_count'),
    rating: json.intOr('rating'),
    viewers: json.mapList('viewers').map(TaskViewer.fromJson).toList(),
    comments: json.mapList('comments').map(TaskComment.fromJson).toList(),
  );

  final String id;
  final String title;
  final String? description;
  final String status;
  final String priority;
  final String? projectId;
  final String? projectName;

  /// Nhóm việc (công đoạn) công việc này đang nằm trong — một cột trên bảng.
  ///
  /// null nghĩa là chưa xếp vào công đoạn nào; bảng dồn chúng vào cột đầu
  /// chứ không giấu đi. Một cây đàn không ai thấy là một cây đàn không ai làm.
  final String? sectionId;

  /// Tên công đoạn, do API giải sẵn.
  ///
  /// Trước đây màn chi tiết phải gọi thêm `/projects/{id}` chỉ để dịch MỘT id
  /// thành MỘT tên — và chính lượt gọi ấy bắt module `tasks` phải import
  /// module `plans`, tạo ra phụ thuộc VÒNG giữa hai module.
  ///
  /// null cả khi chưa xếp công đoạn lẫn khi nhóm đã bị xoá khỏi kế hoạch: hai
  /// chuyện khác nhau với cơ sở dữ liệu, cùng một câu trả lời với người dùng.
  final String? sectionName;

  /// Các công đoạn của kế hoạch chứa việc này.
  ///
  /// Chỉ có mặt ở phản hồi CHI TIẾT, nơi sheet "Chuyển công đoạn" cần nó.
  /// Dòng danh sách không mang theo: 50 việc × 5 công đoạn là 250 bản sao của
  /// cùng một mảng trên mỗi trang, mà thẻ trên bảng không dùng tới.
  final List<TaskSection> planSections;
  final List<String> assigneeIds;
  final List<String> assigneeNames;
  final DateTime? dueDate;
  final DateTime? startDate;
  final List<Subtask> subtasks;
  final Map<String, dynamic> customFields;

  /// Tệp đã đính, đọc thẳng từ mảng `attachments` của API.
  ///
  /// Có ở CẢ dòng danh sách lẫn phản hồi chi tiết: `TaskController::listRow`
  /// bên API chỉ cắt `comments` và `activity` khỏi dòng danh sách.
  final List<TaskAttachment> attachments;

  final int attachmentCount;
  final int commentCount;

  /// Điểm QC, 0–5 sao. 0 = chưa chấm (§4, §B3).
  ///
  /// Chấm điểm là việc của người kiểm, không phải của người làm — ai cũng
  /// tự chấm được thì con số thôi là một đánh giá.
  final int rating;

  /// Who has opened this task. Empty on a list row — the API sends it only on
  /// the detail response, where it is worth the bytes.
  final List<TaskViewer> viewers;

  /// Bình luận, cũ nhất trước. Chỉ có ở phản hồi chi tiết, và API cắt bớt
  /// phần cũ — [commentCount] mới là tổng thật.
  final List<TaskComment> comments;

  /// Only `done` is terminal; every other status id is defined by the project.
  bool get isDone => status == 'done';

  int get doneCount => subtasks.where((s) => s.done).length;

  int get totalCount => subtasks.length;

  /// 0.0–1.0, and 0 rather than NaN when there are no stages at all.
  ///
  /// This is the number the card leads with, because "how far along is this
  /// piano" is the only question a worker opens the app to answer.
  double get progress => totalCount == 0 ? 0 : doneCount / totalCount;

  bool get hasSubtasks => subtasks.isNotEmpty;

  /// Days past the deadline, or null when it is not overdue.
  ///
  /// Compared by calendar day, not by instant: a task due today at 09:00 is not
  /// "overdue" at 10:00 to somebody standing at a workbench.
  int? get daysOverdue {
    final due = dueDate;
    if (due == null || isDone) return null;
    final today = DateTime.now();
    final dueDay = DateTime(due.year, due.month, due.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    final difference = todayDay.difference(dueDay).inDays;

    return difference > 0 ? difference : null;
  }

  bool get isOverdue => daysOverdue != null;

  bool get isDueToday {
    final due = dueDate;
    if (due == null || isDone) return false;
    final today = DateTime.now();

    return due.year == today.year &&
        due.month == today.month &&
        due.day == today.day;
  }

  /// Bản sao có sửa vài trường.
  ///
  /// Viết tay, nên nó CHỈ đúng khi mọi trường đều được chép lại — và bản trước
  /// bỏ sót đúng ba trường thêm vào lúc làm tầng nhóm việc: `sectionId`,
  /// `sectionName`, `planSections`.
  ///
  /// Hậu quả không nằm ở chỗ dễ đoán. Tick một việc con là đi qua đây (cập
  /// nhật lạc quan), nên chỉ cần tick một cái là `planSections` biến mất —
  /// và sheet "Chuyển nhóm việc" từ đó báo "kế hoạch này chưa khai báo nhóm
  /// việc nào". Tức là: tick xong công đoạn thì hết kéo được cây đàn sang cột
  /// kế tiếp, đúng hai thao tác đi liền nhau ở §B2 → §B3.
  ///
  /// `task_copy_with_test.dart` so từng trường, để lần thêm trường sau không
  /// lặp lại chuyện này.
  Task copyWith({List<Subtask>? subtasks, String? status}) => Task(
    id: id,
    title: title,
    description: description,
    status: status ?? this.status,
    priority: priority,
    projectId: projectId,
    projectName: projectName,
    sectionId: sectionId,
    sectionName: sectionName,
    planSections: planSections,
    assigneeIds: assigneeIds,
    assigneeNames: assigneeNames,
    dueDate: dueDate,
    startDate: startDate,
    subtasks: subtasks ?? this.subtasks,
    customFields: customFields,
    attachments: attachments,
    attachmentCount: attachmentCount,
    commentCount: commentCount,
    rating: rating,
    viewers: viewers,
    comments: comments,
  );
}
