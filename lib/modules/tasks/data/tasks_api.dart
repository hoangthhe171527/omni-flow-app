import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_envelope.dart';
import '../domain/task.dart';

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

  /// Tự nhận một việc con đang trống.
  ///
  /// §3: xưởng chạy kiểu pull — ai rảnh thì nhận công đoạn kế tiếp, không ai
  /// đứng ra phân. Server bắn "Công đoạn đang trống" cho cả tổ; đây là đường
  /// duy nhất trong app trả lời được cái thông báo đó.
  ///
  /// Cùng một lệnh PATCH với tick, KHÔNG phải PUT cả mảng checklist: nhận việc
  /// và tick xảy ra cùng lúc ở xưởng, nên một bản chụp cả mảng gửi lúc nhận
  /// việc sẽ xoá mất dấu tick người khác vừa đánh — im lặng.
  Future<Task> claimSubtask(
    String taskId,
    String subtaskId,
    String userId,
  ) async {
    final response = await _client.patch(
      '$_base/$taskId/checklist/$subtaskId',
      body: {'assignee_id': userId},
    );

    return Task.fromJson(response.object);
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

  Future<void> attach(String taskId, String filePath, {String? filename}) =>
      _client.upload(
        '$_base/$taskId/attachments',
        field: 'file',
        filePath: filePath,
        filename: filename,
      );
}

final tasksApiProvider = Provider<TasksApi>((ref) {
  return TasksApi(ref.watch(apiClientProvider));
});
