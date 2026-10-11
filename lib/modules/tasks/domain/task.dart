import '../../../core/utils/avatar_url.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/json.dart';
import 'task_activity.dart';

// URL ảnh người được chuẩn hoá NGAY LÚC PARSE (`resolveAvatarUrl`), ở cả bốn
// chỗ API gửi nó: người làm, việc con, bình luận, đã xem. Ảnh được vẽ ở hàng
// chục chỗ, và mỗi chỗ tự chuẩn hoá trong build là mỗi khung hình parse lại
// cùng những URL đó — còn một chỗ quên là một vòng tròn trống trên Android.

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
    this.assigneeAvatar,
    this.dueDate,
  });

  factory Subtask.fromJson(Map<String, dynamic> json) => Subtask(
    id: json.strOr('id', ''),
    title: json.strOr('title', ''),
    done: json.flag('done'),
    assigneeId: json.str('assignee_id'),
    assigneeName: json.str('assignee_name'),
    // Server chỉ đặt khoá khi người đó có ảnh (cùng quy ước `user_avatar`).
    assigneeAvatar: resolveAvatarUrl(json.str('assignee_avatar')),
    dueDate: DateUtilsX.parse(json['due_date']),
  );

  final String id;
  final String title;
  final bool done;
  final String? assigneeId;
  final String? assigneeName;
  final String? assigneeAvatar;
  final DateTime? dueDate;

  Subtask copyWith({bool? done}) => Subtask(
    id: id,
    title: title,
    done: done ?? this.done,
    assigneeId: assigneeId,
    assigneeName: assigneeName,
    assigneeAvatar: assigneeAvatar,
    dueDate: dueDate,
  );
}

/// Somebody who has opened this task, and when they last did.
///
/// A seen-list, not an audit log: the manager's question is "did they get it",
/// which one row per person answers and a row per open buries.
class TaskViewer {
  const TaskViewer({
    required this.userId,
    this.name,
    this.avatar,
    this.viewedAt,
  });

  factory TaskViewer.fromJson(Map<String, dynamic> json) => TaskViewer(
    userId: json.strOr('user_id', ''),
    name: json.str('name'),
    avatar: resolveAvatarUrl(json.str('avatar')),
    viewedAt: DateUtilsX.parse(json['viewed_at']),
  );

  final String userId;
  final String? name;
  final String? avatar;
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
    this.userAvatar,
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
    userAvatar: resolveAvatarUrl(json.str('user_avatar')),
    // Tên, không phải id: vai thợ không có quyền nhân sự, app không có danh
    // sách nào để tự tra một UUID ra tên người.
    mentionedUserNames: json.strList('mentioned_user_names'),
    createdAt: DateUtilsX.parse(json['created_at']),
  );

  final String id;
  final String body;
  final String? userId;
  final String? userName;
  final String? userAvatar;
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

/// Một công đoạn của dự án, như công việc nhìn thấy nó.
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
    this.assigneeAvatars = const [],
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
    this.activity = const [],
    this.labels = const [],
    this.likes = const [],
    this.archived = false,
    this.pinned,
    this.locked,
    this.followerIds,
    this.followerNames = const [],
    this.followerAvatars = const [],
    this.assignedBy,
    this.assignedByName,
    this.assignedByAvatar,
    this.createdBy,
    this.createdByName,
    this.createdByAvatar,
    this.customerId,
    this.customerName,
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
    // KHÔNG dùng `strList`: nó nuốt null, mà API cố ý để null giữ chỗ cho
    // người chưa có ảnh để mảng thẳng hàng với `assignee_ids`. Nuốt một null
    // là ảnh của Luận nhảy sang mặt Hằng Ni.
    assigneeAvatars: switch (json['assignee_avatars']) {
      final List raw => [
        for (final v in raw)
          if (v is String && v.trim().isNotEmpty) resolveAvatarUrl(v) else null,
      ],
      _ => const [],
    },
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
    // API KHÔNG gửi `attachments_count` (xem ghi chú ở [TaskAttachment]); nó
    // gửi mảng. Đọc mỗi khoá đếm là thẻ việc không bao giờ hiện 📎 dù có hai
    // tấm ảnh — và test với dữ liệu giả có khoá đếm vẫn xanh. Có khoá thì
    // tin khoá (một danh sách có thể cắt mảng), không có thì đếm mảng.
    attachmentCount: json.containsKey('attachments_count')
        ? json.intOr('attachments_count')
        : json.mapList('attachments').length,
    commentCount: json.intOr('comments_count'),
    rating: json.intOr('rating'),
    viewers: json.mapList('viewers').map(TaskViewer.fromJson).toList(),
    comments: json.mapList('comments').map(TaskComment.fromJson).toList(),
    activity: json.mapList('activity').map(TaskActivityEntry.fromJson).toList(),
    labels: json.strList('labels'),
    // Vắng khoá khi chưa ai từng thích (`MongoTaskRepository::toggleLike`
    // chỉ ghi khoá ở lần thích đầu tiên).
    likes: json.strList('likes'),
    // Tài liệu cũ không có khoá; server coi đó là chưa lưu trữ (`!= true`).
    archived: json.flag('archived'),
    // API Nhóm 2 (`TaskPresenter::withFlags`) LUÔN gửi hai cờ này dạng bool;
    // API cũ không có khoá → null = "chưa có khả năng", nên ẩn nút.
    pinned: _boolOrNull(json['pinned']),
    locked: _boolOrNull(json['locked']),
    // Chỉ có khi việc từng có người theo dõi; vắng khoá trên API mới vẫn
    // theo dõi được ([supportsFollowers] nhìn thêm `pinned`).
    followerIds: json.containsKey('follower_ids')
        ? json.strList('follower_ids')
        : null,
    followerNames: _alignedNames(json['follower_names']),
    followerAvatars: _alignedAvatars(json['follower_avatars']),
    assignedBy: json.str('assigned_by'),
    assignedByName: json.str('assigned_by_name'),
    assignedByAvatar: resolveAvatarUrl(json.str('assigned_by_avatar')),
    createdBy: json.str('created_by'),
    createdByName: json.str('created_by_name'),
    createdByAvatar: resolveAvatarUrl(json.str('created_by_avatar')),
    customerId: json.str('customer_id'),
    // Chỉ có khi tài liệu mang sẵn tên khách; presenter không trang trí.
    customerName: json.str('customer_name'),
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
  /// null cả khi chưa xếp công đoạn lẫn khi nhóm đã bị xoá khỏi dự án: hai
  /// chuyện khác nhau với cơ sở dữ liệu, cùng một câu trả lời với người dùng.
  final String? sectionName;

  /// Các công đoạn của dự án chứa việc này.
  ///
  /// Chỉ có mặt ở phản hồi CHI TIẾT, nơi sheet "Chuyển công đoạn" cần nó.
  /// Dòng danh sách không mang theo: 50 việc × 5 công đoạn là 250 bản sao của
  /// cùng một mảng trên mỗi trang, mà thẻ trên bảng không dùng tới.
  final List<TaskSection> planSections;
  final List<String> assigneeIds;
  final List<String> assigneeNames;

  /// URL ảnh của từng người, THẲNG HÀNG với [assigneeIds]; null khi người đó
  /// chưa đặt ảnh (app rơi về chữ tắt). Rỗng với API cũ chưa gửi trường này.
  final List<String?> assigneeAvatars;

  /// Ảnh của người thứ [index] trong [assigneeIds], hoặc null.
  ///
  /// An toàn với mảng ngắn hơn (API cũ) và chỉ số ngoài phạm vi — một chỗ vẽ
  /// avatar không được văng vì thiếu một tấm ảnh.
  String? assigneeAvatarAt(int index) =>
      index >= 0 && index < assigneeAvatars.length
      ? assigneeAvatars[index]
      : null;
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

  /// Nhật ký của công việc: ai đã làm gì với cây đàn này, cũ nhất trước.
  ///
  /// API đã ghi nó từ lâu (tối đa 200 dòng, cắt phần cũ nhất) và gửi kèm ở
  /// phản hồi CHI TIẾT, nhưng app chưa từng đọc — nên "ai đã kéo cây này về
  /// lại Đang làm" là câu hỏi không có chỗ nào trả lời, kể cả khi câu trả lời
  /// đã nằm sẵn trong phản hồi.
  ///
  /// Rỗng trên dòng danh sách: `TaskController::listRow` bên API cắt nó cùng
  /// với `comments`.
  final List<TaskActivityEntry> activity;

  /// Mã nhãn gắn trên việc (`labels[]`, mỗi mã ≤64). Tên và màu tra từ bộ
  /// nhãn công ty (`TASK_LABEL`), không lưu ở đây.
  final List<String> labels;

  /// Id những người đã thích việc này.
  final List<String> likes;

  /// Việc đã lưu trữ: ẩn khỏi bảng (`GET /tasks` mặc định `archived=active`).
  final bool archived;

  /// Việc được ghim lên đầu cột (chung cả kế hoạch). null = API cũ chưa có
  /// khả năng ghim; thứ tự ghim-trước do SERVER sắp, app không tự sắp.
  final bool? pinned;

  /// Việc đã khoá: mọi lượt sửa trả 423 `task_locked`. null = API cũ.
  final bool? locked;

  /// Id người theo dõi. null = khoá vắng (API cũ, hoặc API mới mà việc chưa
  /// từng có ai theo dõi — xem [supportsFollowers]).
  final List<String>? followerIds;

  /// Tên / ảnh người theo dõi, THẲNG HÀNG với [followerIds] (null giữ chỗ).
  final List<String?> followerNames;
  final List<String?> followerAvatars;

  /// Người giao việc (server đặt khi có người MỚI vào `assignee_ids`).
  final String? assignedBy;
  final String? assignedByName;
  final String? assignedByAvatar;

  /// Id người tạo việc. Tên / ảnh chỉ có khi API Nhóm 2 tra được.
  final String? createdBy;
  final String? createdByName;
  final String? createdByAvatar;

  /// Đã ghim (thiếu khoá = không).
  bool get isPinned => pinned == true;

  /// Đã khoá (thiếu khoá = không).
  bool get isLocked => locked == true;

  /// Khả năng ghim: chỉ khi API gửi khoá `pinned`.
  bool get supportsPin => pinned != null;

  /// Khả năng khoá: chỉ khi API gửi khoá `locked`.
  bool get supportsLock => locked != null;

  /// Khả năng theo dõi. `follower_ids` chỉ có sau lần theo dõi đầu tiên, nên
  /// `pinned` — khoá API Nhóm 2 gửi trên MỌI việc, cùng bản phát hành với
  /// `/follow` — cũng là tín hiệu. API cũ thiếu cả hai.
  bool get supportsFollowers => followerIds != null || pinned != null;

  /// Người theo dõi, ghép id / tên / ảnh theo chỉ số (an toàn với mảng ngắn).
  List<({String id, String? name, String? avatar})> get followers => [
    for (var i = 0; i < (followerIds?.length ?? 0); i++)
      (
        id: followerIds![i],
        name: i < followerNames.length ? followerNames[i] : null,
        avatar: i < followerAvatars.length ? followerAvatars[i] : null,
      ),
  ];

  /// Tên người giao cho chuỗi "người giao → người làm". Việc cũ không có
  /// `assigned_by` thì rơi về người tạo (theo hợp đồng API); có `assigned_by`
  /// mà không tra được tên thì null — không gán nhầm sang người tạo.
  String? get assignerName =>
      assignedBy != null ? assignedByName : createdByName;

  String? get assignerAvatar =>
      assignedBy != null ? assignedByAvatar : createdByAvatar;

  /// Khách hàng gắn với việc, lưu thô. Không có tên đi kèm chắc chắn.
  final String? customerId;

  /// Tên khách nếu tài liệu có `customer_name`. null = chỉ có id.
  final String? customerName;

  bool isLikedBy(String userId) => likes.contains(userId);

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

  /// Công đoạn chưa xong đứng đầu danh sách, hoặc null khi đã xong hết.
  ///
  /// Là thứ một cú vuốt trên thẻ sẽ tick. Theo THỨ TỰ danh sách chứ không theo
  /// người được giao: checklist của xưởng là quy trình, và công đoạn kế tiếp
  /// là công đoạn kế tiếp trong quy trình.
  Subtask? get nextOpenSubtask {
    for (final s in subtasks) {
      if (!s.done) return s;
    }

    return null;
  }

  /// Days past the deadline, or null when it is not overdue.
  ///
  /// Compared by calendar day, not by instant: a task due today at 09:00 is not
  /// "overdue" at 10:00 to somebody standing at a workbench.
  int? get daysOverdue {
    final due = dueDate;
    if (due == null || isDone) return null;
    // Ngày VN như dueToneOf, để thẻ và chip luôn khớp nhau.
    final difference = VnTime.today().difference(VnTime.day(due)).inDays;

    return difference > 0 ? difference : null;
  }

  bool get isOverdue => daysOverdue != null;

  bool get isDueToday {
    final due = dueDate;
    if (due == null || isDone) return false;

    return VnTime.day(due) == VnTime.today();
  }

  /// Bản sao có sửa vài trường.
  ///
  /// Viết tay, nên nó CHỈ đúng khi mọi trường đều được chép lại — và bản trước
  /// bỏ sót đúng ba trường thêm vào lúc làm tầng nhóm việc: `sectionId`,
  /// `sectionName`, `planSections`.
  ///
  /// Hậu quả không nằm ở chỗ dễ đoán. Tick một việc con là đi qua đây (cập
  /// nhật lạc quan), nên chỉ cần tick một cái là `planSections` biến mất —
  /// và sheet "Chuyển nhóm việc" từ đó báo "dự án này chưa khai báo nhóm
  /// việc nào". Tức là: tick xong công đoạn thì hết kéo được cây đàn sang cột
  /// kế tiếp, đúng hai thao tác đi liền nhau ở §B2 → §B3.
  ///
  /// `task_copy_with_test.dart` so từng trường, để lần thêm trường sau không
  /// lặp lại chuyện này.
  Task copyWith({
    List<Subtask>? subtasks,
    String? status,
    List<String>? labels,
    List<String>? likes,
    bool? pinned,
    bool? locked,
    List<String>? followerIds,
    List<String?>? followerNames,
    List<String?>? followerAvatars,
  }) => Task(
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
    assigneeAvatars: assigneeAvatars,
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
    activity: activity,
    labels: labels ?? this.labels,
    likes: likes ?? this.likes,
    archived: archived,
    pinned: pinned ?? this.pinned,
    locked: locked ?? this.locked,
    followerIds: followerIds ?? this.followerIds,
    followerNames: followerNames ?? this.followerNames,
    followerAvatars: followerAvatars ?? this.followerAvatars,
    assignedBy: assignedBy,
    assignedByName: assignedByName,
    assignedByAvatar: assignedByAvatar,
    createdBy: createdBy,
    createdByName: createdByName,
    createdByAvatar: createdByAvatar,
    customerId: customerId,
    customerName: customerName,
  );
}

/// Cờ bool của API Nhóm 2; kiểu khác (hoặc vắng) là null — không đoán.
bool? _boolOrNull(Object? raw) => raw is bool ? raw : null;

/// Mảng tên thẳng hàng với id: giữ null chỗ không tra được.
List<String?> _alignedNames(Object? raw) => switch (raw) {
  final List list => [
    for (final v in list)
      if (v is String && v.trim().isNotEmpty) v else null,
  ],
  _ => const [],
};

/// Như [_alignedNames] nhưng chuẩn hoá URL ảnh.
List<String?> _alignedAvatars(Object? raw) => switch (raw) {
  final List list => [
    for (final v in list)
      if (v is String && v.trim().isNotEmpty) resolveAvatarUrl(v) else null,
  ],
  _ => const [],
};
