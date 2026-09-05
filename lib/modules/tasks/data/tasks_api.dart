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
