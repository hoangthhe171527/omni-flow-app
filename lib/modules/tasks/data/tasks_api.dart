import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_envelope.dart';
import '../domain/task.dart';

/// Which slice of a person's work to show.
///
/// These are the four questions a worker actually has, in the order they have
/// them — not a generic filter builder.
enum TaskBucket {
  today('Hôm nay'),
  overdue('Quá hạn'),
  upcoming('Sắp tới'),
  all('Tất cả');

  const TaskBucket(this.label);

  final String label;
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
      // Chuỗi rỗng chứ không null: API bỏ qua trường null (xem
      // `UpdateTaskDTO::toAttributes`), nên gửi null sẽ không xoá được công
      // đoạn — nó lặng lẽ không làm gì.
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

  /// Đặt lại TOÀN BỘ danh sách người làm.
  ///
  /// API ghi đè `assignee_ids` chứ không thêm/bớt từng người, nên chỗ gọi phải
  /// gửi danh sách đầy đủ sau thay đổi. Gửi thiếu một người là gỡ họ ra khỏi
  /// việc — im lặng, và người đó mất luôn thông báo lẫn việc trong danh sách
  /// của mình.
  ///
  /// Danh sách rỗng gửi được và có nghĩa: trả việc về "chưa gán ai".
  Future<Task> setAssignees(String taskId, List<String> userIds) async {
    final response = await _client.put(
      '$_base/$taskId',
      body: {'assignee_ids': userIds},
    );

    return Task.fromJson(response.object);
  }

  Future<void> comment(String taskId, String body) =>
      _client.post('$_base/$taskId/comments', body: {'content': body});

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
