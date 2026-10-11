import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/utils/json.dart';
import '../domain/custom_field.dart';
import '../domain/task.dart';
import '../domain/task_label.dart';
import '../domain/task_project.dart';
import '../domain/task_reminder.dart';

/// Which slice of a person's work to show.
///
/// These are the four questions a worker actually has, in the order they have
/// them — not a generic filter builder. Cộng một câu thứ năm mà chỉ QUẢN ĐỐC
/// hỏi, xem [open].
///
/// Tên các case khớp với `enum TaskBucket` bên API
/// (`modules/Tasks/Domain/Enums/TaskBucket.php`). Lệch một chữ thì server
/// không hiểu và im lặng rơi về "tất cả" — im lặng, vì một bộ lọc không đọc
/// được thì bị bỏ qua chứ không báo lỗi.
enum TaskBucket {
  today('Hôm nay'),
  overdue('Quá hạn'),
  upcoming('Sắp tới'),

  /// Chưa xong, bất kể có đặt hạn hay không.
  ///
  /// Bốn nhóm kia đều xoay quanh HẠN, vì đó là cách một người thợ nhìn hàng
  /// đợi của chính mình. Quản đốc hỏi khác — "người này đang gánh bao nhiêu
  /// cây" — và câu đó không lọc theo hạn: phần lớn công đoạn ở xưởng không
  /// đặt hạn riêng, chúng chạy theo bảng tháng (§B0).
  open('Chưa xong'),
  all('Tất cả');

  const TaskBucket(this.label);

  final String label;

  /// Bốn nhóm hiện trên màn "Việc của tôi".
  ///
  /// KHÔNG phải [values]: [open] là câu hỏi của quản đốc về NGƯỜI KHÁC, và
  /// thêm nó vào hàng nút của người thợ là thêm một nút gần trùng "Tất cả"
  /// vào đúng màn hình cần ít lựa chọn nhất.
  static const forMyWork = [today, overdue, upcoming, all];
}

/// Phạm vi lưu trữ khi liệt kê việc của một kế hoạch.
///
/// Tên case là đúng chữ `MongoTaskRepository::paginate` nhận cho `archived`:
/// `active` (mặc định của server), `archived`, `all`.
enum TaskArchiveScope { active, archived, all }

/// Một kế hoạch, như sheet "Chuyển việc" cần: id, tên, các nhóm việc.
typedef MovablePlan = ({String id, String name, List<TaskSection> sections});

class TasksApi {
  TasksApi(this._client);

  static const _base = '/tasks';

  final ApiClient _client;

  /// Tasks assigned to the caller, narrowed by [bucket].
  ///
  /// `assignee=me` is resolved server-side; sending a user id from the client
  /// would let a caller ask for somebody else's list.
  Future<Paged<Task>> mine({
    required TaskBucket bucket,
    int page = 1,
    int perPage = AppConfig.defaultPerPage,
  }) async {
    final response = await _client.get(
      _base,
      query: {
        'assignee': 'me',
        'bucket': bucket.name,
        'page': page,
        'per_page': perPage,
      },
    );

    return Paged(
      items: response.list.map(Task.fromJson).toList(),
      pagination: response.pagination ?? const ApiPagination.empty(),
    );
  }

  /// Việc của MỘT người, cho quản đốc xem tải.
  ///
  /// Khác [mine] ở chỗ id đi từ client lên — và đó là lý do màn gọi hàm này
  /// nằm sau `tasks.projects.manage.all`. [mine] cố ý không nhận id: nếu nhận
  /// thì ai cũng đọc được hàng đợi của người khác chỉ bằng cách đổi tham số,
  /// và §7 nói rõ xưởng không công khai số liệu từng cá nhân.
  Future<Paged<Task>> byAssignee(
    String userId, {
    TaskBucket bucket = TaskBucket.open,
    int page = 1,
    int perPage = AppConfig.defaultPerPage,
  }) async {
    final response = await _client.get(
      _base,
      query: {
        'assignee_id': userId,
        'bucket': bucket.name,
        'page': page,
        'per_page': perPage,
      },
    );

    return Paged(
      items: response.list.map(Task.fromJson).toList(),
      pagination: response.pagination ?? const ApiPagination.empty(),
    );
  }

  /// Số việc quá hạn của một người, đếm ở SERVER.
  ///
  /// Không đếm trên danh sách đã tải: danh sách có phân trang, nên một con số
  /// đếm từ trang một là con số của trang một — và nó trông y hệt một con số
  /// của tất cả.
  Future<int> overdueCount(String userId) async {
    final response = await _client.get(
      '$_base/stats',
      query: {'assignee_id': userId},
    );

    return (response.object['overdue'] as num?)?.toInt() ?? 0;
  }

  /// Tìm một cây đàn theo tên hoặc số máy.
  ///
  /// Server so khớp trên `title`, `customer_name`, `name` và `code`, nên
  /// "471302" tìm ra "SCHWESTER No.53 — SN 471302". Không lọc theo người:
  /// người đi tìm một cây đàn thường KHÔNG phải người đang giữ nó — đó chính
  /// là lý do họ phải tìm.
  Future<Paged<Task>> search(
    String query, {
    int page = 1,
    int perPage = AppConfig.defaultPerPage,
  }) async {
    final response = await _client.get(
      _base,
      query: {
        'search': query,
        // "Tất cả": một cây đã bàn giao tháng trước vẫn phải tìm lại được —
        // đó gần như là lý do duy nhất người ta gõ một số máy vào ô tìm kiếm.
        'bucket': TaskBucket.all.name,
        'page': page,
        'per_page': perPage,
      },
    );

    return Paged(
      items: response.list.map(Task.fromJson).toList(),
      pagination: response.pagination ?? const ApiPagination.empty(),
    );
  }

  Future<Task> get(String id) async {
    final response = await _client.get('$_base/$id');

    return Task.fromJson(response.object);
  }

  /// Xoá mềm một công việc cha. Việc đã xoá biến mất ở cả web và app sau khi
  /// hai client nhận tín hiệu realtime hoặc lần tải lại kế tiếp.
  Future<void> deleteTask(String taskId) async {
    await _client.delete('$_base/$taskId');
  }

  /// Ticks or un-ticks one stage.
  ///
  /// [clientRequestId] is the idempotency key. A worker on bad workshop wifi
  /// retries, and a stage counted twice moves the monthly piano count that the
  /// team bonus is paid on — so a repeat must resolve to the same result rather
  /// than a second completion.
  Future<Task> setSubtaskDone(
    String taskId,
    String subtaskId, {
    required bool done,
    String? clientRequestId,
  }) async {
    final response = await _client.patch(
      '$_base/$taskId/checklist/$subtaskId',
      body: {
        'done': done,
        if (clientRequestId != null && clientRequestId.isNotEmpty)
          'client_request_id': clientRequestId,
      },
    );

    return Task.fromJson(response.object);
  }

  /// Thêm một việc con vào cuối danh sách.
  ///
  /// Id do SERVER sinh: hai người thêm cùng lúc mà client tự sinh id thì có thể
  /// trùng, và một checklist có hai mục cùng id thì mọi lệnh sau đó trỏ nhầm.
  Future<Task> addSubtask(String taskId, String title) async {
    final response = await _client.post(
      '$_base/$taskId/checklist',
      body: {'title': title},
    );

    return Task.fromJson(response.object);
  }

  /// Đổi tên một việc con.
  ///
  /// Một lệnh cho một việc con, không PUT cả mảng checklist: hai người sửa hai
  /// mục khác nhau trên cùng công việc sẽ ghi đè nhau, vì mỗi bên gửi lên một
  /// bản chụp của cả mảng.
  Future<Task> renameSubtask(
    String taskId,
    String subtaskId,
    String title,
  ) async {
    final response = await _client.patch(
      '$_base/$taskId/checklist/$subtaskId',
      body: {'title': title},
    );

    return Task.fromJson(response.object);
  }

  /// Giao (hoặc gỡ, khi [userId] null) người làm MỘT việc con.
  ///
  /// Khoá `assignee_id` LUÔN có mặt: máy chủ hỏi `has('assignee_id')`, và null
  /// là "gỡ người" có chủ ý (`UpdateChecklistItem` dùng array_key_exists).
  /// Server chỉ nhận thành viên đang làm của workspace — người khác → 422.
  ///
  /// Cùng một lệnh PATCH với tick, KHÔNG phải PUT cả mảng checklist: giao việc
  /// và tick xảy ra cùng lúc ở xưởng, nên một bản chụp cả mảng sẽ xoá mất dấu
  /// tick người khác vừa đánh — im lặng.
  Future<Task> assignSubtask(
    String taskId,
    String subtaskId,
    String? userId,
  ) async {
    final response = await _client.patch(
      '$_base/$taskId/checklist/$subtaskId',
      body: <String, dynamic>{'assignee_id': userId},
    );

    return Task.fromJson(response.object);
  }

  /// Ai thuộc dự án: `member_ids` ∪ `owner_id` từ `GET /projects/{id}`.
  ///
  /// Đọc thẳng ở đây chứ không qua `PlansApi`: plans đã import tasks, và
  /// tasks import ngược lại là một chu trình (`module_cycle_test.dart`).
  Future<List<String>> projectMemberIds(String projectId) async {
    final response = await _client.get('/projects/$projectId');
    final json = response.object;
    final ids = <String>[...json.strList('member_ids')];
    final owner = json.str('owner_id');
    if (owner != null && owner.isNotEmpty && !ids.contains(owner)) {
      ids.add(owner);
    }
    return ids;
  }

  Future<Task> removeSubtask(String taskId, String subtaskId) async {
    final response = await _client.delete(
      '$_base/$taskId/checklist/$subtaskId',
    );

    return Task.fromJson(response.object);
  }

  Future<Task> setStatus(String taskId, String status) async {
    final response = await _client.patch(
      '$_base/$taskId/status',
      body: {'status': status},
    );

    return Task.fromJson(response.object);
  }

  /// Chuyển một công việc sang công đoạn khác.
  ///
  /// Thay cho kéo thả thẻ giữa các cột: trên điện thoại, kéo qua ranh giới
  /// trang là một cử chỉ tồi — nó tranh với chính cử chỉ lật trang của bảng.
  ///
  /// Đi qua PUT /tasks/{id} vì `section_id` là một trường thường của công
  /// việc, không phải một hành động riêng. Đặt ra một endpoint riêng cho nó
  /// nghĩa là có hai đường ghi cùng một trường.
  Future<Task> moveToSection(String taskId, String? sectionId) async {
    final response = await _client.put(
      '$_base/$taskId',
      // Luôn GỬI khoá `section_id`, kể cả khi gỡ. Server phân biệt "có gửi
      // khoá" với "không gửi khoá" chứ không nhìn giá trị — chuỗi rỗng bị
      // middleware của Laravel biến thành null trước khi tới controller.
      body: {'section_id': sectionId ?? ''},
    );

    return Task.fromJson(response.object);
  }

  /// Tạo một công việc mới.
  ///
  /// Chỉ `title` là bắt buộc — đúng như API. Mọi thứ khác bỏ trống được, vì
  /// người tạo việc thường đang đứng giữa ca làm và chỉ kịp gõ cái tên; điền
  /// nốt là chuyện của màn chi tiết sau đó.
  ///
  /// Trường nào null thì KHÔNG gửi, chứ không gửi null: `UpdateTaskDTO` bỏ qua
  /// null, nên gửi cũng vô ích, và một thân request đầy null làm nhật ký khó
  /// đọc khi cần truy lại ai đã đặt gì.
  Future<Task> create({
    required String title,
    String? projectId,
    String? sectionId,
    List<String> assigneeIds = const [],
    DateTime? dueDate,
  }) async {
    final response = await _client.post(
      _base,
      body: {
        'title': title,
        if (projectId != null && projectId.isNotEmpty) 'project_id': projectId,
        if (sectionId != null && sectionId.isNotEmpty) 'section_id': sectionId,
        if (assigneeIds.isNotEmpty) 'assignee_ids': assigneeIds,
        // API nhận `YYYY-MM-DD` và tự hiểu theo múi giờ nghiệp vụ. Gửi cả giờ
        // là mời nó lệch một ngày ở hai đầu tháng.
        if (dueDate != null) 'due_date': _ymd(dueDate),
      },
    );

    return Task.fromJson(response.object);
  }

  static String _ymd(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Đổi tên công việc.
  Future<Task> setTitle(String taskId, String title) =>
      _patch(taskId, {'title': title});

  /// Đổi mô tả. Chuỗi rỗng là xoá mô tả — một lựa chọn hợp lệ.
  Future<Task> setDescription(String taskId, String description) =>
      _patch(taskId, {'description': description});

  /// Đổi mức ưu tiên. API nhận `low` | `med` | `high`.
  Future<Task> setPriority(String taskId, String priority) =>
      _patch(taskId, {'priority': priority});

  /// Chấm điểm QC, 0–5 sao. 0 = xoá điểm đã chấm.
  ///
  /// Gửi số 0 chứ không gửi null: `UpdateTaskDTO::toAttributes` lọc bỏ đúng
  /// những trường null, nên null sẽ lặng lẽ không làm gì. Cùng cái bẫy đã
  /// gặp ở `section_id` và `due_date`.
  Future<Task> setRating(String taskId, int rating) =>
      _patch(taskId, {'rating': rating.clamp(0, 5)});

  /// Đặt hoặc XOÁ hạn.
  ///
  /// null = xoá, gửi đi bằng chuỗi rỗng. Điều QUAN TRỌNG là gửi khoá đó lên —
  /// server phân biệt "có gửi khoá" với "không gửi khoá", chứ không nhìn giá
  /// trị: `ConvertEmptyStringsToNull` của Laravel biến chuỗi rỗng thành null
  /// trước khi tới controller, nên gửi '' hay null tới nơi đều là null.
  ///
  /// Chú thích cũ ở đây nói ngược lại — rằng chuỗi rỗng đi qua được còn null
  /// thì bị lọc. Suốt thời gian đó hạn KHÔNG xoá được: API trả 200 với dữ liệu
  /// y nguyên. Xem `ClearFieldWithEmptyStringTest` bên API.
  Future<Task> setDueDate(String taskId, DateTime? dueDate) =>
      _patch(taskId, {'due_date': dueDate == null ? '' : _ymd(dueDate)});

  /// Đặt lại TOÀN BỘ danh sách người làm.
  ///
  /// API ghi đè `assignee_ids` chứ không thêm/bớt từng người, nên chỗ gọi phải
  /// gửi danh sách đầy đủ sau thay đổi. Gửi thiếu một người là gỡ họ ra khỏi
  /// việc — im lặng, và người đó mất luôn thông báo lẫn việc trong danh sách
  /// của mình.
  ///
  /// Danh sách rỗng gửi được và có nghĩa: trả việc về "chưa gán ai".
  Future<Task> setAssignees(String taskId, List<String> userIds) =>
      _patch(taskId, {'assignee_ids': userIds});

  /// Tự nhận việc: server THÊM người đang đăng nhập vào `assignee_ids` (CV-I2).
  ///
  /// Không gửi danh sách nào: một bản chụp gửi lên là đè người vừa được thêm
  /// giữa lúc mở màn và lúc bấm. API trước Đợt 5 chưa có route này (404).
  Future<Task> claim(String taskId) async {
    final response = await _client.post('$_base/$taskId/claim');

    return Task.fromJson(response.object);
  }

  /// Ghi MỘT trường của công việc.
  ///
  /// API chỉ có PUT /tasks/{id} và nó ghi đúng những trường được gửi, nên gửi
  /// một trường là sửa một trường — không cần đọc rồi ghi lại cả bản ghi, và
  /// hai người sửa hai trường khác nhau không đè lên nhau.
  Future<Task> _patch(String taskId, Map<String, dynamic> body) async {
    final response = await _client.put('$_base/$taskId', body: body);

    return Task.fromJson(response.object);
  }

  /// Viết một bình luận, và nhận về công việc đã có nó.
  ///
  /// Khoá là `body`, KHÔNG phải `content`. Bản trước gửi `content` và server
  /// trả 422 cho mọi bình luận gửi từ app — không ai phát hiện vì chưa màn
  /// hình nào gọi tới hàm này. Xem `CreateTaskCommentRequest`.
  Future<Task> comment(
    String taskId,
    String body, {
    List<String> mentionedUserIds = const [],
  }) async {
    final response = await _client.post(
      '$_base/$taskId/comments',
      // §B3: QC trượt thì bình luận phải nhắc tên người phụ trách công đoạn
      // lỗi. Khoá server nhận là `mentioned_user_ids` (xem
      // `CreateTaskCommentRequest`). Không gửi thì tên chỉ là chữ trong câu:
      // không ai được báo, và không màn hình nào tô nó lên.
      body: {'body': body, 'mentioned_user_ids': mentionedUserIds},
    );

    return Task.fromJson(response.object);
  }

  /// Bình luận của một việc, MỚI NHẤT TRƯỚC, phân trang.
  ///
  /// Phản hồi chi tiết chỉ mang phần mới nhất; đây là đường đọc phần còn lại
  /// ngay trong app thay vì "xem trên web". Cùng hình dạng phần tử với
  /// `comments[]` trong chi tiết, nên [TaskComment.fromJson] dùng lại được.
  /// `per_page` trần 50 ở server — gửi hơn là bị cắt lặng lẽ, nên kẹp ở đây.
  Future<Paged<TaskComment>> comments(
    String taskId, {
    int page = 1,
    int perPage = AppConfig.defaultPerPage,
  }) async {
    final response = await _client.get(
      '$_base/$taskId/comments',
      query: {'page': page, 'per_page': perPage.clamp(1, 50)},
    );

    return Paged(
      items: response.list.map(TaskComment.fromJson).toList(),
      pagination: response.pagination ?? const ApiPagination.empty(),
    );
  }

  /// Đặt lại TOÀN BỘ nhãn của việc (`labels[]`).
  ///
  /// Danh sách rỗng vẫn gửi khoá: đó là "bỏ hết nhãn". Bỏ khoá thì server
  /// không đổi gì và trả 200 — lượt ghi bị nuốt lặng.
  Future<Task> setLabels(String taskId, List<String> labels) =>
      _patch(taskId, {'labels': labels});

  /// Bật/tắt thích của người đang đăng nhập. Server trả việc đầy đủ đã trang
  /// trí; chỗ gọi thay state bằng nó, không tải lại.
  Future<Task> toggleLike(String taskId) async {
    final response = await _client.post('$_base/$taskId/like');

    return Task.fromJson(response.object);
  }

  /// Lưu trữ hoặc bỏ lưu trữ. Gửi `bool` thật, không chuỗi.
  Future<Task> setArchived(String taskId, bool archived) =>
      _patch(taskId, {'archived': archived});

  /// Chuyển việc sang kế hoạch (và nhóm việc) khác.
  ///
  /// `section_id` LUÔN có khoá: null là "chưa xếp nhóm" ở kế hoạch đích. Bỏ
  /// khoá thì việc mang theo `section_id` của kế hoạch cũ — một id không có
  /// trong kế hoạch mới.
  Future<Task> moveTask(
    String taskId, {
    required String projectId,
    String? sectionId,
  }) => _patch(taskId, <String, dynamic>{
    'project_id': projectId,
    'section_id': sectionId,
  });

  /// Đặt hoặc XOÁ ngày bắt đầu. null = xoá, gửi khoá với giá trị null
  /// (`UpdateTaskDTO::$provided` giữ khoá đã gửi kể cả khi null).
  Future<Task> setStartDate(String taskId, DateTime? startDate) => _patch(
    taskId,
    <String, dynamic>{'start_date': startDate == null ? null : _ymd(startDate)},
  );

  /// Ghi giá trị trường tuỳ chỉnh.
  ///
  /// Server THAY CẢ MAP `custom_fields`, nên [fields] phải là map đã gộp đủ
  /// mọi trường. Gửi một trường là xoá mọi trường còn lại — im lặng.
  Future<Task> setCustomFields(String taskId, Map<String, Object?> fields) =>
      _patch(taskId, {'custom_fields': fields});

  /// Xoá một tệp đã đính. Server trả việc sau khi xoá.
  Future<Task> deleteAttachment(String taskId, String attachmentId) async {
    final response = await _client.delete(
      '$_base/$taskId/attachments/$attachmentId',
    );

    return Task.fromJson(response.object);
  }

  /// Xoá một bình luận (tác giả hoặc quản lý kế hoạch; người khác → 403).
  Future<Task> deleteComment(String taskId, String commentId) async {
    final response = await _client.delete('$_base/$taskId/comments/$commentId');

    return Task.fromJson(response.object);
  }

  // ── Nhóm 2, Task 11 (`ApiCapability`: subtaskFields, checklistMove, taskCopy,
  // taskReminders, commentAttachments). Chỗ gọi chỉ gọi khi phiên khai khả
  // năng tương ứng.

  /// Tạo việc con ĐỦ trường trong MỘT lượt `POST /tasks/{id}/checklist`
  /// (`CreateChecklistItemRequest`). Trường trống không gửi. `assignee_id`
  /// phải là thành viên đang làm (422 `errors.assignee_id`).
  Future<Task> createSubtask(
    String taskId, {
    required String title,
    String? description,
    DateTime? startDate,
    DateTime? dueDate,
    String? assigneeId,
  }) async {
    final note = description?.trim() ?? '';
    final response = await _client.post(
      '$_base/$taskId/checklist',
      body: {
        'title': title,
        if (note.isNotEmpty) 'description': note,
        if (startDate != null) 'start_date': _ymd(startDate),
        if (dueDate != null) 'due_date': _ymd(dueDate),
        if (assigneeId != null && assigneeId.isNotEmpty)
          'assignee_id': assigneeId,
      },
    );

    return Task.fromJson(response.object);
  }

  /// Đặt / XOÁ hạn một việc con. Khoá LUÔN gửi: null = xoá
  /// (`UpdateChecklistItemRequest`, `array_key_exists`).
  Future<Task> setSubtaskDueDate(
    String taskId,
    String subtaskId,
    DateTime? dueDate,
  ) => _patchSubtask(taskId, subtaskId, {
    'due_date': dueDate == null ? null : _ymd(dueDate),
  });

  /// Đặt / xoá ngày bắt đầu một việc con (null = xoá).
  Future<Task> setSubtaskStartDate(
    String taskId,
    String subtaskId,
    DateTime? startDate,
  ) => _patchSubtask(taskId, subtaskId, {
    'start_date': startDate == null ? null : _ymd(startDate),
  });

  /// Sửa ghi chú việc con; rỗng = xoá (gửi null).
  Future<Task> setSubtaskDescription(
    String taskId,
    String subtaskId,
    String? description,
  ) {
    final note = description?.trim() ?? '';
    return _patchSubtask(taskId, subtaskId, {
      'description': note.isEmpty ? null : note,
    });
  }

  Future<Task> _patchSubtask(
    String taskId,
    String subtaskId,
    Map<String, dynamic> body,
  ) async {
    final response = await _client.patch(
      '$_base/$taskId/checklist/$subtaskId',
      body: body,
    );

    return Task.fromJson(response.object);
  }

  /// Kéo thả: đặt MỘT việc con ngay sau [afterId] (null = lên đầu) —
  /// `POST …/checklist/{itemId}/move`. Khoá `after_id` LUÔN có (`present`).
  /// Không PUT cả mảng `checklist`.
  Future<Task> moveSubtask(
    String taskId,
    String subtaskId, {
    required String? afterId,
  }) async {
    final response = await _client.post(
      '$_base/$taskId/checklist/$subtaskId/move',
      body: <String, dynamic>{'after_id': afterId},
    );

    return Task.fromJson(response.object);
  }

  /// Sao chép việc phía server (`POST /tasks/{id}/copy`, 201 + việc mới).
  /// [title] null = tên mặc định của server. Không chép bình luận, tệp,
  /// ghim, khoá, người theo dõi.
  Future<Task> copyTask(String taskId, {String? title}) async {
    final name = title?.trim() ?? '';
    final response = await _client.post(
      '$_base/$taskId/copy',
      body: {if (name.isNotEmpty) 'title': name},
    );

    return Task.fromJson(response.object);
  }

  /// Lời nhắc người này thấy được trên việc: của mình, và `everyone`.
  Future<List<TaskReminder>> reminders(String taskId) async {
    final response = await _client.get('$_base/$taskId/reminders');

    return response.list.map(TaskReminder.fromJson).toList();
  }

  /// Đặt lời nhắc lúc [at]. Gửi ISO **UTC có `Z`** — regex server bắt buộc
  /// có múi giờ; phải sau bây giờ và trong 366 ngày. [everyone] cần quyền
  /// sửa việc (người xem → 403); tối đa 20 lời nhắc đang chờ / người / việc
  /// (422 `reminder_limit_reached`).
  Future<TaskReminder> addReminder(
    String taskId,
    DateTime at, {
    bool everyone = false,
  }) async {
    final response = await _client.post(
      '$_base/$taskId/reminders',
      body: {
        'remind_at': at.toUtc().toIso8601String(),
        'audience': everyone ? 'everyone' : 'me',
      },
    );

    return TaskReminder.fromJson(response.object);
  }

  /// Xoá lời nhắc (người đặt; `everyone` của người khác cần quản lý việc).
  Future<void> deleteReminder(String taskId, String reminderId) async {
    await _client.delete('$_base/$taskId/reminders/$reminderId');
  }

  /// Bình luận KÈM tệp: multipart `files[]` (≤10 tệp, mỗi tệp ≤25MB, cả
  /// request ≤64MB) trên CÙNG `POST /tasks/{id}/comments`. Thân rỗng thì
  /// không gửi `body` (`required_without_all:attachment_ids,files`).
  Future<Task> commentWithFiles(
    String taskId,
    String body, {
    List<String> mentionedUserIds = const [],
    required List<CommentUpload> files,
  }) async {
    final text = body.trim();
    final response = await _client.uploadMany(
      '$_base/$taskId/comments',
      files: [
        for (final f in files)
          (field: 'files[]', path: f.path, filename: f.name),
      ],
      fields: [
        if (text.isNotEmpty) MapEntry('body', text),
        for (final id in mentionedUserIds) MapEntry('mentioned_user_ids[]', id),
      ],
    );

    return Task.fromJson(response.object);
  }

  /// Gỡ một tệp kèm bình luận (người tải hoặc quản lý; việc khoá vẫn được).
  Future<Task> deleteCommentAttachment(
    String taskId,
    String commentId,
    String attachmentId,
  ) async {
    final response = await _client.delete(
      '$_base/$taskId/comments/$commentId/attachments/$attachmentId',
    );

    return Task.fromJson(response.object);
  }

  /// Việc của một kế hoạch, có tìm theo chữ và lọc lưu trữ.
  ///
  /// [archived] mặc định `active` — đúng mặc định của server, nên khi đó
  /// KHÔNG gửi khoá. `search` rỗng cũng không gửi: rỗng ở server là "không
  /// lọc", gửi đi chỉ thêm nhiễu.
  Future<Paged<Task>> list({
    required String projectId,
    String? search,
    TaskArchiveScope archived = TaskArchiveScope.active,
    int page = 1,
    int perPage = AppConfig.maxPerPage,
  }) async {
    final query = search?.trim() ?? '';
    final response = await _client.get(
      _base,
      query: {
        'project_id': projectId,
        if (query.isNotEmpty) 'search': query,
        if (archived != TaskArchiveScope.active) 'archived': archived.name,
        'page': page,
        'per_page': perPage,
      },
    );

    return Paged(
      items: response.list.map(Task.fromJson).toList(),
      pagination: response.pagination ?? const ApiPagination.empty(),
    );
  }

  /// Kế hoạch chứa việc: chủ, thành viên, vai, trường tuỳ chỉnh — một lượt
  /// `GET /projects/{id}`. Đọc thẳng ở đây: tasks không import plans.
  Future<TaskProject> project(String projectId) async {
    final response = await _client.get('/projects/$projectId');

    return TaskProject.fromJson(response.object);
  }

  /// Định nghĩa trường tuỳ chỉnh của một kế hoạch (`projects.custom_fields`).
  ///
  /// Đọc thẳng `/projects/{id}` như [projectMemberIds]: tasks không import
  /// plans.
  Future<List<CustomFieldDef>> projectCustomFields(String projectId) async {
    final response = await _client.get('/projects/$projectId');

    return response.object
        .mapList('custom_fields')
        .map(CustomFieldDef.fromJson)
        .toList();
  }

  /// Mọi kế hoạch người dùng đọc được, kèm nhóm việc — cho sheet "Chuyển
  /// việc". Gom hết các trang; dừng theo dữ liệu nhận được.
  Future<List<MovablePlan>> projectsForMove() async {
    final all = <MovablePlan>[];
    var page = 1;
    while (true) {
      final response = await _client.get(
        '/projects',
        query: {'page': page, 'per_page': AppConfig.maxPerPage},
      );
      final rows = response.list;
      for (final json in rows) {
        all.add((
          id: json.strOr('id', ''),
          name: json.strOr('name', ''),
          sections: json.mapList('sections').map(TaskSection.fromJson).toList(),
        ));
      }
      final pagination = response.pagination;
      if (rows.length < AppConfig.maxPerPage ||
          pagination == null ||
          !pagination.hasMore) {
        break;
      }
      page = pagination.nextPage;
    }

    return all;
  }

  /// Nhóm `system_options` chứa bộ nhãn việc của công ty.
  static const labelGroup = 'TASK_LABEL';

  /// Bộ nhãn việc của công ty, chỉ nhãn đang bật.
  ///
  /// `group_key` BẮT BUỘC (thiếu → 422). Người thiếu `system_options.read`
  /// nhận 403: trả rỗng thay vì ném — họ vẫn làm việc được, chỉ không có tên
  /// và màu cho nhãn.
  Future<List<TaskLabel>> taskLabels() async {
    try {
      final response = await _client.get(
        '/system-options',
        query: {'group_key': labelGroup, 'active_only': 1},
      );

      return response.list.map(TaskLabel.fromJson).toList();
    } on ForbiddenException {
      return const [];
    }
  }

  /// Bộ nhãn cho người chỉ có `tasks.read` (thợ): `GET
  /// /system-options/task-labels` → `[{code, label, color, sort_order}]`, chỉ
  /// nhãn đang bật. Không có `id`, nên KHÔNG dùng để sửa nhãn.
  ///
  /// Chỉ gọi khi phiên khai `system_options.task_labels`. Phòng khi API vẫn
  /// lùi bản giữa phiên: API cũ KHÔNG có `GET /system-options/{id}` (chỉ
  /// `PUT`/`DELETE /{id}`), nên đường này ra 405; tắt `feature:tasks` hay
  /// thiếu quyền ra 403; route lạ ra 404. Cả ba ra rỗng như trước đây.
  Future<List<TaskLabel>> taskLabelsForReaders() async {
    try {
      final response = await _client.get('/system-options/task-labels');

      return response.list.map(TaskLabel.fromJson).toList();
    } on ForbiddenException {
      return const [];
    } on NotFoundException {
      return const [];
    } on RequestRejectedException catch (e) {
      if (e.code == '405') return const [];
      rethrow;
    }
  }

  /// Ghim / bỏ ghim việc lên đầu cột (`POST|DELETE /tasks/{id}/pin`). Không
  /// body; server trả việc đầy đủ. Việc đã khoá → 423.
  Future<Task> setPinned(String taskId, bool pinned) =>
      _toggle('$_base/$taskId/pin', pinned);

  /// Khoá / mở khoá việc (`POST|DELETE /tasks/{id}/lock`, chủ / quản lý kế
  /// hoạch; người khác 403 kèm câu của server).
  Future<Task> setLocked(String taskId, bool locked) =>
      _toggle('$_base/$taskId/lock', locked);

  /// Tự theo dõi / bỏ theo dõi (`POST|DELETE /tasks/{id}/follow`, chỉ cần
  /// `tasks.read`; việc đã khoá vẫn được).
  Future<Task> setFollowing(String taskId, bool following) =>
      _toggle('$_base/$taskId/follow', following);

  /// Đặt lại TOÀN BỘ người theo dõi (`PUT /tasks/{id}` `follower_ids[]`).
  /// Rỗng vẫn gửi khoá: đó là "bỏ hết". Mọi id phải là thành viên đang làm
  /// (422 `errors.follower_ids`), tối đa 50.
  Future<Task> setFollowers(String taskId, List<String> userIds) =>
      _patch(taskId, {'follower_ids': userIds});

  Future<Task> _toggle(String path, bool on) async {
    final response = on ? await _client.post(path) : await _client.delete(path);

    return Task.fromJson(response.object);
  }

  /// Mã của mọi nhãn trong nhóm, đang bật lẫn đã tắt. Thiếu quyền đọc (403)
  /// thì rỗng: vẫn tạo được, chỉ không tránh trùng được.
  Future<Set<String>> _allLabelCodes() async {
    try {
      final response = await _client.get(
        '/system-options',
        query: {'group_key': labelGroup},
      );

      return {for (final l in response.list.map(TaskLabel.fromJson)) l.code};
    } on ForbiddenException {
      return const {};
    }
  }

  /// Tạo một nhãn mới (`system_options.write`).
  ///
  /// Mã sinh từ [label] ([TaskLabel.codeFor]), tránh MỌI mã đã có trong nhóm
  /// — kể cả nhãn đã tắt, nên đọc danh mục KHÔNG `active_only` ngay trước khi
  /// gửi. Server không kiểm trùng mã; dùng lại mã của một nhãn đã tắt là gắn
  /// tên/màu mới lên các việc cũ còn mang mã đó. [color] null thì không gửi
  /// khoá.
  Future<TaskLabel> createLabel({required String label, String? color}) async {
    final taken = await _allLabelCodes();
    final response = await _client.post(
      '/system-options',
      body: {
        'group_key': labelGroup,
        'code': TaskLabel.codeFor(label, taken: taken),
        'label': label,
        if (color != null && color.isNotEmpty) 'color': color,
      },
    );

    return TaskLabel.fromJson(response.object);
  }

  /// Sửa tên / màu một nhãn theo [id] bản ghi. Server KHÔNG nhận `code` hay
  /// `group_key` ở đây — mã trên các việc cũ giữ nguyên.
  Future<TaskLabel> updateLabel(
    String id, {
    required String label,
    String? color,
  }) async {
    final response = await _client.put(
      '/system-options/$id',
      body: {'label': label, 'color': color},
    );

    return TaskLabel.fromJson(response.object);
  }

  Future<void> attach(String taskId, String filePath, {String? filename}) =>
      _client.upload(
        '$_base/$taskId/attachments',
        field: 'file',
        filePath: filePath,
        filename: filename,
      );
}

/// Lỗi "việc đã khoá": 423 `code: task_locked` (`TaskController::
/// lockedResponse`). Câu cho người đọc nằm sẵn trong `message` của lỗi.
bool isTaskLockedError(Object error) =>
    error is RequestRejectedException &&
    (error.reason == 'task_locked' || error.code == '423');

final tasksApiProvider = Provider<TasksApi>((ref) {
  return TasksApi(ref.watch(apiClientProvider));
});
