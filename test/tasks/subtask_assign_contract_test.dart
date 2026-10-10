import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/modules/tasks/data/tasks_api.dart';

/// Khoá đúng tên khoá mà `UpdateChecklistItemRequest` nhận. Lệch một chữ là
/// máy chủ trả 400 "Cần ít nhất done, title hoặc assignee_id" — hoặc tệ hơn,
/// bỏ khoá null đi và "Bỏ gán" thành một lệnh không làm gì.
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

  test(
    'giao việc con: PATCH checklist/{item} đúng một khoá assignee_id',
    () async {
      await api.assignSubtask('t1', 'c2', 'u7');
      final o = rec.single;
      expect(o.method, 'PATCH');
      expect(o.uri.path, '/api/v1/tasks/t1/checklist/c2');
      expect(bodyOf(o), {'assignee_id': 'u7'});
    },
  );

  test('Bỏ gán: gửi assignee_id = null tường minh, không bỏ khoá', () async {
    await api.assignSubtask('t1', 'c2', null);
    final body = bodyOf(rec.single);
    expect(body.containsKey('assignee_id'), isTrue);
    expect(body['assignee_id'], isNull);
    expect(body.keys, ['assignee_id']);
  });

  test('thêm việc con: POST checklist đúng một khoá title', () async {
    await api.addSubtask('t1', 'Vệ sinh');
    final o = rec.single;
    expect(o.method, 'POST');
    expect(o.uri.path, '/api/v1/tasks/t1/checklist');
    expect(bodyOf(o), {'title': 'Vệ sinh'});
  });

  test('thành viên dự án: GET /projects/{id}, gộp owner_id, bỏ trùng', () async {
    rec.body =
        '{"success":true,"data":{"id":"p1","owner_id":"u1","member_ids":["u2","u1"]}}';
    final ids = await api.projectMemberIds('p1');
    expect(rec.single.method, 'GET');
    expect(rec.single.uri.path, '/api/v1/projects/p1');
    expect(ids, ['u2', 'u1']);
  });

  test(
    'thành viên dự án: owner chưa nằm trong member_ids thì được thêm',
    () async {
      rec.body =
          '{"success":true,"data":{"id":"p1","owner_id":"u9","member_ids":["u2"]}}';
      expect(await api.projectMemberIds('p1'), ['u2', 'u9']);
    },
  );
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
