import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/modules/tasks/data/tasks_api.dart';
import 'package:omni_app/modules/tasks/domain/task_copy_request.dart';

/// Hợp đồng "góp ý bảng kế hoạch" (API `feat/gop-y-bang-ke-hoach`):
///  * `POST /tasks/{id}/copy`: khoá cũ `title`, `project_id`, `section_id`,
///    `keep_assignees`, `keep_checklist`; khoá mới (sau capability
///    `tasks.copy_options`) `start_date`, `due_date` (nullable, CÓ MẶT = ghi
///    đè, null = xoá), `assignee_ids` (thay `keep_assignees`),
///    `keep_custom_fields`;
///  * `PUT /tasks/{id}` nhận `section_id` + `order` cùng lúc;
///  * `/projects` trả `team_id`, `team_name`.
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

  group('copyTask', () {
    test('API cũ: chỉ năm khoá cũ, đúng kiểu', () async {
      await api.copyTask(
        't1',
        const TaskCopyRequest(
          title: '  KAWAI (bản sao) ',
          projectId: 'p2',
          sectionId: 's9',
          keepAssignees: false,
          keepChecklist: true,
        ),
      );
      expect(rec.single.method, 'POST');
      expect(rec.single.uri.path, '/api/v1/tasks/t1/copy');
      expect(bodyOf(rec.single), {
        'title': 'KAWAI (bản sao)',
        'project_id': 'p2',
        'section_id': 's9',
        'keep_assignees': false,
        'keep_checklist': true,
      });
    });

    test(
      'tên rỗng → không có title; project/section null hoặc rỗng → không có khoá',
      () async {
        await api.copyTask(
          't1',
          const TaskCopyRequest(title: '   ', projectId: '', sectionId: ''),
        );
        await api.copyTask('t1', const TaskCopyRequest());
        for (final r in rec.requests) {
          final body = bodyOf(r);
          expect(body.containsKey('title'), isFalse);
          expect(body.containsKey('project_id'), isFalse);
          expect(body.containsKey('section_id'), isFalse);
        }
      },
    );

    test(
      'ngày ghi đè: start_date "2026-10-12", due_date null vẫn CÓ khoá',
      () async {
        await api.copyTask(
          't1',
          TaskCopyRequest(
            startDate: (date: DateTime(2026, 10, 12)),
            dueDate: (date: null),
          ),
        );
        expect(bodyOf(rec.single), containsPair('start_date', '2026-10-12'));
        expect(bodyOf(rec.single).containsKey('due_date'), isTrue);
        expect(bodyOf(rec.single)['due_date'], isNull);
      },
    );

    test(
      'ngày không đổi (null override) → không có start_date/due_date',
      () async {
        await api.copyTask('t1', const TaskCopyRequest());
        final body = bodyOf(rec.single);
        expect(body.containsKey('start_date'), isFalse);
        expect(body.containsKey('due_date'), isFalse);
      },
    );

    test(
      'assignee_ids: [] vẫn gửi; có assignee_ids thì KHÔNG gửi keep_assignees',
      () async {
        await api.copyTask('t1', const TaskCopyRequest(assigneeIds: []));
        final body = bodyOf(rec.single);
        expect(body['assignee_ids'], <String>[]);
        expect(body.containsKey('keep_assignees'), isFalse);
      },
    );

    test('assignee_ids có người → gửi nguyên danh sách', () async {
      await api.copyTask(
        't1',
        const TaskCopyRequest(assigneeIds: ['u1', 'u2']),
      );
      expect(bodyOf(rec.single)['assignee_ids'], ['u1', 'u2']);
    });

    test(
      'keep_custom_fields false/true là bool; null → không có khoá',
      () async {
        await api.copyTask(
          't1',
          const TaskCopyRequest(keepCustomFields: false),
        );
        await api.copyTask('t1', const TaskCopyRequest(keepCustomFields: true));
        await api.copyTask('t1', const TaskCopyRequest());
        expect(bodyOf(rec.requests[0])['keep_custom_fields'], isFalse);
        expect(bodyOf(rec.requests[1])['keep_custom_fields'], isTrue);
        expect(
          bodyOf(rec.requests[2]).containsKey('keep_custom_fields'),
          isFalse,
        );
      },
    );

    test('đọc việc mới từ 201', () async {
      rec.status = 201;
      rec.body = jsonEncode({
        'success': true,
        'data': {'id': 't2', 'title': 'Bản sao', 'order': 3},
      });
      final copy = await api.copyTask('t1', const TaskCopyRequest());
      expect(copy.id, 't2');
      expect(copy.order, 3.0);
    });
  });

  test('moveOnBoard: PUT /tasks/t1 đúng {section_id, order}', () async {
    await api.moveOnBoard('t1', sectionId: 's2', order: 1.5);
    expect(rec.single.method, 'PUT');
    expect(rec.single.uri.path, '/api/v1/tasks/t1');
    expect(bodyOf(rec.single), {'section_id': 's2', 'order': 1.5});
  });

  test('moveOnBoard: order null → chỉ {section_id}', () async {
    await api.moveOnBoard('t1', sectionId: 's2');
    expect(bodyOf(rec.single), {'section_id': 's2'});
  });

  test('projectsForMove đọc team_id/team_name; thiếu khoá → null', () async {
    rec.body = jsonEncode({
      'success': true,
      'data': [
        {
          'id': 'p1',
          'name': 'A',
          'team_id': 'tm1',
          'team_name': 'Xưởng',
          'sections': [],
        },
        {'id': 'p2', 'name': 'B', 'sections': []},
      ],
      'meta': {
        'pagination': {
          'page': 1,
          'per_page': 100,
          'total': 2,
          'total_pages': 1,
        },
      },
    });
    final plans = await api.projectsForMove();
    expect(plans[0].teamId, 'tm1');
    expect(plans[0].teamName, 'Xưởng');
    expect(plans[1].teamId, isNull);
    expect(plans[1].teamName, isNull);
  });
}

class _Recorder implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  int status = 200;
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
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
