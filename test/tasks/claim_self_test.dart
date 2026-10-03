import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/modules/tasks/application/task_controller.dart';
import 'package:omni_app/modules/tasks/data/tasks_api.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';

/// "Nhận việc" đi qua `POST /tasks/{id}/claim` (CV-I2).
///
/// Trước đây app PUT lại cả `assignee_ids` từ bản chụp lúc mở màn: quản đốc
/// vừa thêm ai đó giữa chừng thì người đó bị gỡ ra, im lặng. Server tự THÊM
/// mình vào danh sách thì không còn bản chụp nào để đè.
///
/// API cũ (trước Đợt 5) chưa có route này và trả 404 — khi đó app làm như cũ,
/// để một bản app mới chạy với API chưa cập nhật vẫn nhận được việc.
void main() {
  Task taskWith(List<String> ids) => Task.fromJson({
    'id': 't1',
    'title': 'KAWAI HAT-5',
    'project_id': 'p1',
    'assignee_ids': ids,
  });

  late _RoutingAdapter adapter;

  ProviderContainer containerWith(Task task) {
    final container = ProviderContainer(
      overrides: [
        tasksApiProvider.overrideWithValue(
          TasksApi(ApiClient(Dio()..httpClientAdapter = adapter)),
        ),
        taskDetailProvider.overrideWith(
          () => _StubDetail(TaskDetailState(task: task)),
        ),
      ],
    );
    addTearDown(container.dispose);
    // autoDispose: giữ provider sống suốt bài kiểm.
    container.listen(
      taskDetailProvider('t1'),
      (_, _) {},
      fireImmediately: true,
    );

    return container;
  }

  test(
    'TasksApi.claim gọi POST /tasks/{id}/claim, không kèm danh sách',
    () async {
      adapter = _RoutingAdapter({
        'POST /api/v1/tasks/t1/claim': (
          200,
          '{"success":true,"data":{"id":"t1","title":"x","assignee_ids":["u1","u9"]}}',
        ),
      });
      final api = TasksApi(ApiClient(Dio()..httpClientAdapter = adapter));

      final task = await api.claim('t1');

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.uri.path, '/api/v1/tasks/t1/claim');
      expect(request.data is Map && (request.data as Map).isNotEmpty, isFalse);
      expect(task.assigneeIds, ['u1', 'u9']);
    },
  );

  test('claimSelf dùng lệnh claim và lấy danh sách server trả về', () async {
    adapter = _RoutingAdapter({
      // Server đã có u5 (quản đốc vừa thêm) mà bản chụp trong máy chưa thấy.
      'POST /api/v1/tasks/t1/claim': (
        200,
        '{"success":true,"data":{"id":"t1","title":"x","assignee_ids":["u1","u5","u9"]}}',
      ),
    });
    final container = containerWith(taskWith(['u1']));
    await container.read(taskDetailProvider('t1').future);

    await container.read(taskDetailProvider('t1').notifier).claimSelf('u9');

    expect(adapter.requests.map((r) => '${r.method} ${r.uri.path}'), [
      'POST /api/v1/tasks/t1/claim',
    ]);
    expect(
      container.read(taskDetailProvider('t1')).requireValue.task.assigneeIds,
      ['u1', 'u5', 'u9'],
    );
  });

  test(
    'API cũ chưa có route claim (404) → làm như cũ: PUT cả danh sách',
    () async {
      adapter = _RoutingAdapter({
        'POST /api/v1/tasks/t1/claim': (
          404,
          '{"message":"The route api/v1/tasks/t1/claim could not be found."}',
        ),
        'PUT /api/v1/tasks/t1': (
          200,
          '{"success":true,"data":{"id":"t1","title":"x","assignee_ids":["u1","u9"]}}',
        ),
      });
      final container = containerWith(taskWith(['u1']));
      await container.read(taskDetailProvider('t1').future);

      await container.read(taskDetailProvider('t1').notifier).claimSelf('u9');

      expect(adapter.requests.map((r) => '${r.method} ${r.uri.path}'), [
        'POST /api/v1/tasks/t1/claim',
        'PUT /api/v1/tasks/t1',
      ]);
      expect(adapter.requests.last.data, {
        'assignee_ids': ['u1', 'u9'],
      });
      expect(
        container.read(taskDetailProvider('t1')).requireValue.task.assigneeIds,
        ['u1', 'u9'],
      );
    },
  );

  test('lỗi khác 404 (vd. 403) NÉM ra, không lặng lẽ thử đường cũ', () async {
    adapter = _RoutingAdapter({
      'POST /api/v1/tasks/t1/claim': (403, '{"message":"Không có quyền."}'),
    });
    final container = containerWith(taskWith(['u1']));
    await container.read(taskDetailProvider('t1').future);

    await expectLater(
      container.read(taskDetailProvider('t1').notifier).claimSelf('u9'),
      throwsA(isA<ForbiddenException>()),
    );
    expect(adapter.requests, hasLength(1));
  });
}

class _StubDetail extends TaskController {
  _StubDetail(this._state);

  final TaskDetailState _state;

  @override
  Future<TaskDetailState> build(String taskId) async => _state;
}

/// Trả phản hồi theo "METHOD /path"; đường lạ là 500 để bài kiểm lộ ra ngay.
class _RoutingAdapter implements HttpClientAdapter {
  _RoutingAdapter(this.routes);

  final Map<String, (int, String)> routes;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, body) =
        routes['${options.method} ${options.uri.path}'] ??
        (500, '{"message":"route lạ trong test"}');

    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
