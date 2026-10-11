import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/modules/tasks/data/tasks_api.dart';
import 'package:omni_app/modules/tasks/domain/custom_field.dart';

/// Khoá đúng method, path và TÊN KHOÁ mà API nhận cho các thao tác Việc mới
/// (Nhóm 1). Đối chiếu `omni-flow-api` origin/main:
///  * `UpdateTaskRequest` — labels[], archived, project_id, section_id,
///    start_date, custom_fields (map, thay cả map);
///  * `UpdateTaskDTO::$provided` — khoá gửi kèm null là XOÁ;
///  * routes.php — POST /like, DELETE /attachments/{aid}, DELETE /comments/{cid};
///  * `MongoTaskRepository::paginate` — `archived=active|archived|all`.
void main() {
  late _Recorder rec;
  late TasksApi api;

  setUp(() {
    rec = _Recorder();
    api = TasksApi(ApiClient(Dio()..httpClientAdapter = rec));
  });

  Map<String, dynamic> bodyOf(RequestOptions o) =>
      (o.data is String ? jsonDecode(o.data as String) : o.data)
          as Map<String, dynamic>;

  group('PUT /tasks/{id}', () {
    test('nhãn: PUT /tasks/{id} đúng một khoá labels', () async {
      await api.setLabels('t1', ['UU_TIEN', 'CHO_KHACH']);
      expect(rec.single.method, 'PUT');
      expect(rec.single.uri.path, '/api/v1/tasks/t1');
      expect(bodyOf(rec.single), {
        'labels': ['UU_TIEN', 'CHO_KHACH'],
      });
    });

    test('bỏ hết nhãn: gửi labels = [] chứ không bỏ khoá', () async {
      await api.setLabels('t1', const []);
      expect(bodyOf(rec.single), {'labels': <String>[]});
    });

    test('lưu trữ: {archived: true}; bỏ lưu trữ: {archived: false}', () async {
      await api.setArchived('t1', true);
      await api.setArchived('t1', false);
      expect(rec.requests.map((o) => o.method), ['PUT', 'PUT']);
      expect(rec.requests.first.uri.path, '/api/v1/tasks/t1');
      expect(bodyOf(rec.requests[0]), {'archived': true});
      expect(bodyOf(rec.requests[1]), {'archived': false});
    });

    test('chuyển việc: {project_id, section_id}', () async {
      await api.moveTask('t1', projectId: 'p2', sectionId: 's3');
      expect(rec.single.method, 'PUT');
      expect(rec.single.uri.path, '/api/v1/tasks/t1');
      expect(bodyOf(rec.single), {'project_id': 'p2', 'section_id': 's3'});
    });

    test('chuyển việc: section null vẫn có khoá (null = gỡ nhóm)', () async {
      await api.moveTask('t1', projectId: 'p2');
      final body = bodyOf(rec.single);
      expect(body.keys.toSet(), {'project_id', 'section_id'});
      expect(body['section_id'], isNull);
    });

    test('ngày bắt đầu: {start_date: "YYYY-MM-DD"}', () async {
      await api.setStartDate('t1', DateTime(2026, 3, 5, 14, 30));
      expect(rec.single.method, 'PUT');
      expect(bodyOf(rec.single), {'start_date': '2026-03-05'});
    });

    test('ngày bắt đầu: xoá → khoá start_date = null', () async {
      await api.setStartDate('t1', null);
      final body = bodyOf(rec.single);
      expect(body.keys, ['start_date']);
      expect(body['start_date'], isNull);
    });

    test('hạn vẫn đi bằng due_date, không bao giờ due_at', () async {
      await api.setDueDate('t1', DateTime(2026, 12, 31));
      expect(bodyOf(rec.single), {'due_date': '2026-12-31'});
      await api.create(title: 'x', dueDate: DateTime(2026, 1, 2));
      final created = bodyOf(rec.requests.last);
      expect(created['due_date'], '2026-01-02');
      expect(created.containsKey('due_at'), isFalse);
    });

    test(
      'trường tuỳ chỉnh: gửi cả map đã gộp dưới khoá custom_fields',
      () async {
        await api.setCustomFields('t1', {'f1': 'Đen', 'f2': 3, 'f3': null});
        expect(rec.single.method, 'PUT');
        expect(rec.single.uri.path, '/api/v1/tasks/t1');
        expect(bodyOf(rec.single), {
          'custom_fields': {'f1': 'Đen', 'f2': 3, 'f3': null},
        });
      },
    );
  });

  group('lệnh riêng', () {
    test('thích: POST /tasks/t1/like, không body', () async {
      await api.toggleLike('t1');
      expect(rec.single.method, 'POST');
      expect(rec.single.uri.path, '/api/v1/tasks/t1/like');
      expect(rec.single.data, isNull);
    });

    test('thích: dùng việc trả về (likes mới)', () async {
      rec.body = jsonEncode({
        'success': true,
        'data': {
          'id': 't1',
          'title': 'x',
          'likes': ['u1'],
        },
      });
      final task = await api.toggleLike('t1');
      expect(task.likes, ['u1']);
    });

    test(
      'xoá tệp: DELETE /tasks/t1/attachments/a9, dùng việc trả về',
      () async {
        rec.body = jsonEncode({
          'success': true,
          'data': {'id': 't1', 'title': 'x', 'attachments': <Object>[]},
        });
        final task = await api.deleteAttachment('t1', 'a9');
        expect(rec.single.method, 'DELETE');
        expect(rec.single.uri.path, '/api/v1/tasks/t1/attachments/a9');
        expect(task.id, 't1');
        expect(task.attachments, isEmpty);
      },
    );

    test(
      'xoá bình luận: DELETE /tasks/t1/comments/c3, dùng việc trả về',
      () async {
        final task = await api.deleteComment('t1', 'c3');
        expect(rec.single.method, 'DELETE');
        expect(rec.single.uri.path, '/api/v1/tasks/t1/comments/c3');
        expect(task.id, 't1');
      },
    );
  });

  group('GET /tasks', () {
    test(
      'việc đã lưu trữ: GET /tasks?project_id=p1&archived=archived',
      () async {
        rec.body = '{"success":true,"data":[],"pagination":{"total":0}}';
        await api.list(projectId: 'p1', archived: TaskArchiveScope.archived);
        final q = rec.single.uri.queryParameters;
        expect(rec.single.method, 'GET');
        expect(rec.single.uri.path, '/api/v1/tasks');
        expect(q['project_id'], 'p1');
        expect(q['archived'], 'archived');
        expect(q.containsKey('search'), isFalse);
      },
    );

    test('tìm trong kế hoạch: GET /tasks?project_id=p1&search=kawai', () async {
      rec.body = '{"success":true,"data":[{"id":"t1","title":"KAWAI"}]}';
      final page = await api.list(projectId: 'p1', search: 'kawai');
      final q = rec.single.uri.queryParameters;
      expect(q['project_id'], 'p1');
      expect(q['search'], 'kawai');
      // Mặc định server đã là `active`; không gửi khoá thừa.
      expect(q.containsKey('archived'), isFalse);
      expect(page.items.single.id, 't1');
    });

    test('archived = all gửi đúng chữ all', () async {
      rec.body = '{"success":true,"data":[]}';
      await api.list(projectId: 'p1', archived: TaskArchiveScope.all);
      expect(rec.single.uri.queryParameters['archived'], 'all');
    });

    test('search rỗng không gửi khoá search', () async {
      rec.body = '{"success":true,"data":[]}';
      await api.list(projectId: 'p1', search: '  ');
      expect(rec.single.uri.queryParameters.containsKey('search'), isFalse);
    });
  });

  group('/projects (đọc thẳng, không qua plans)', () {
    test('định nghĩa trường: GET /projects/p1 → custom_fields', () async {
      rec.body = jsonEncode({
        'success': true,
        'data': {
          'id': 'p1',
          'name': 'Đàn cơ',
          'custom_fields': [
            {
              'id': 'f1',
              'name': 'Màu',
              'type': 'select',
              'options': ['Đen'],
            },
            {'id': 'f2', 'name': 'Số máy', 'type': 'text'},
          ],
        },
      });
      final defs = await api.projectCustomFields('p1');
      expect(rec.single.method, 'GET');
      expect(rec.single.uri.path, '/api/v1/projects/p1');
      expect(defs.map((d) => d.id), ['f1', 'f2']);
      expect(defs.first.type, CustomFieldType.select);
      expect(defs.first.options, ['Đen']);
    });

    test('định nghĩa trường: kế hoạch chưa có custom_fields → rỗng', () async {
      rec.body = '{"success":true,"data":{"id":"p1"}}';
      expect(await api.projectCustomFields('p1'), isEmpty);
    });

    test(
      'kế hoạch để chuyển việc: GET /projects, đọc id/name/sections',
      () async {
        rec.body = jsonEncode({
          'success': true,
          'data': [
            {
              'id': 'p1',
              'name': 'Đàn cơ',
              'sections': [
                {'id': 's1', 'name': 'Nhập xưởng'},
                {'id': 's2', 'name': 'QC'},
              ],
            },
            {'id': 'p2', 'name': 'Đàn điện'},
          ],
          'pagination': {'current_page': 1, 'last_page': 1, 'total': 2},
        });
        final plans = await api.projectsForMove();
        expect(rec.single.method, 'GET');
        expect(rec.single.uri.path, '/api/v1/projects');
        expect(plans.map((p) => p.id), ['p1', 'p2']);
        expect(plans.first.name, 'Đàn cơ');
        expect(plans.first.sections.map((s) => s.id), ['s1', 's2']);
        expect(plans.last.sections, isEmpty);
      },
    );
  });
}

class _Recorder implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  String body = '{"success":true,"data":{"id":"t1","title":"x"}}';

  RequestOptions get single {
    expect(requests, hasLength(1));
    return requests.single;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
