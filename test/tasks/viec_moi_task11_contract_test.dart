import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/modules/notifications/application/push_notifications.dart';
import 'package:omni_app/modules/notifications/domain/app_notification.dart';
import 'package:omni_app/modules/tasks/data/tasks_api.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/domain/task_reminder.dart';

/// Hợp đồng Task 11 (API `feat/viec-moi-api`), đối chiếu mã thật:
///  * `CreateChecklistItemRequest`: `title` (bắt buộc), `description`,
///    `start_date`, `due_date`, `assignee_id` — tất cả nullable;
///  * `UpdateChecklistItemRequest`: `description` / `start_date` / `due_date`
///    — khoá CÓ MẶT kể cả null (null = xoá), vắng = giữ;
///  * `MoveChecklistItemRequest`: `after_id` `present|nullable` (null = đầu);
///  * `CopyTaskRequest`: `title?` … → 201 + việc mới;
///  * `CreateTaskReminderRequest`: `remind_at` ISO CÓ múi giờ, `after:now`,
///    `audience in:me,everyone`; `TaskReminderDTO::toArray`;
///  * `CreateTaskCommentRequest`: `body` nullable khi có `files[]` (≤10);
///    `DELETE /tasks/{id}/comments/{cid}/attachments/{aid}` → việc;
///  * `comments[].attachments[]` `{id, file, name, type, size, user_id,
///    comment_only, url}` (`TaskPresenter::commentAttachmentUrls`);
///  * push `data.type = task_reminder` + `task_id`
///    (`SendTaskRemindersCommand`), `NotificationType::TaskReminder`.
void main() {
  Map<String, dynamic> fixture(String name) =>
      (jsonDecode(File('test/contract/fixtures/$name').readAsStringSync())
              as Map<String, dynamic>)['data']
          as Map<String, dynamic>;

  group('đọc', () {
    test(
      'việc con có description / start_date / due_date; null là không có',
      () {
        final t = Task.fromJson(fixture('tasks_show_viec_moi_task11.json'));
        final c1 = t.subtasks[0];
        expect(c1.description, 'Linh + Rubi');
        expect(c1.startDate, DateTime(2026, 10, 10));
        expect(c1.dueDate, DateTime(2026, 10, 12));
        expect(t.subtasks[1].description, isNull);
        expect(t.subtasks[1].startDate, isNull);
        // Bản sao lạc quan (tick) giữ đủ trường.
        final ticked = c1.copyWith(done: false);
        expect(ticked.description, 'Linh + Rubi');
        expect(ticked.startDate, DateTime(2026, 10, 10));
        expect(ticked.dueDate, DateTime(2026, 10, 12));
        expect(ticked.assigneeId, c1.assigneeId);
      },
    );

    test('bình luận có tệp: thân rỗng được, tệp có url / loại / người tải', () {
      final t = Task.fromJson(fixture('tasks_show_viec_moi_task11.json'));
      final c = t.comments.first;
      expect(c.body, '');
      expect(c.attachments, hasLength(2));
      expect(c.attachments[0].id, 'a1');
      expect(c.attachments[0].isImage, isTrue);
      expect(c.attachments[0].url, startsWith('https://'));
      expect(c.attachments[0].userId, '01a071b9-6569-72ca-a631-69491063fa4e');
      expect(c.attachments[1].isImage, isFalse);
      expect(c.attachments[1].name, 'bao-gia.pdf');
      expect(t.comments[1].attachments, isEmpty);
    });

    test('lời nhắc: TaskReminderDTO::toArray + created_by_name', () {
      final r = TaskReminder.fromJson({
        'id': 'r1',
        'task_id': 't1',
        'remind_at': '2026-10-12T01:30:00.000000Z',
        'audience': 'everyone',
        'status': 'pending',
        'sent_at': null,
        'created_by': 'u9',
        'created_by_name': 'Thợ Hùng',
        'created_at': '2026-10-11T03:00:00.000000Z',
      });
      expect(r.id, 'r1');
      expect(r.remindAt, DateTime.utc(2026, 10, 12, 1, 30));
      expect(r.forEveryone, isTrue);
      expect(r.isPending, isTrue);
      expect(r.createdBy, 'u9');
      expect(r.createdByName, 'Thợ Hùng');
    });

    test('push task_reminder mở việc; chuông TASK_REMINDER là việc', () {
      final intent = PushIntent.fromData({
        'type': 'task_reminder',
        'task_id': 't-1',
        'reminder_id': 'r-1',
      });
      expect(intent, isNotNull);
      expect(intent!.target, PushTarget.task);
      expect(intent.id, 't-1');
      expect(
        NotificationKind.parse('TASK_REMINDER'),
        NotificationKind.taskReminder,
      );
      expect(NotificationKind.taskReminder.isTask, isTrue);
    });
  });

  group('gửi', () {
    late _Recorder rec;
    late TasksApi api;

    setUp(() {
      rec = _Recorder();
      api = TasksApi(ApiClient(Dio()..httpClientAdapter = rec));
    });

    Map<String, dynamic> bodyOf(RequestOptions o) =>
        (o.data is String ? jsonDecode(o.data as String) : o.data)
            as Map<String, dynamic>;

    test('createSubtask: POST checklist đủ trường, ngày YYYY-MM-DD', () async {
      await api.createSubtask(
        't1',
        title: 'Thay nỉ búa',
        description: 'Nỉ đỏ',
        startDate: DateTime(2026, 10, 11),
        dueDate: DateTime(2026, 10, 18),
        assigneeId: 'u2',
      );
      expect(rec.single.method, 'POST');
      expect(rec.single.uri.path, '/api/v1/tasks/t1/checklist');
      expect(bodyOf(rec.single), {
        'title': 'Thay nỉ búa',
        'description': 'Nỉ đỏ',
        'start_date': '2026-10-11',
        'due_date': '2026-10-18',
        'assignee_id': 'u2',
      });
    });

    test('createSubtask: trường trống KHÔNG gửi', () async {
      await api.createSubtask('t1', title: 'A', description: '  ');
      expect(bodyOf(rec.single), {'title': 'A'});
    });

    test('PATCH việc con: description / start_date / due_date; null = xoá '
        '(khoá vẫn gửi)', () async {
      await api.setSubtaskDueDate('t1', 'c1', DateTime(2026, 10, 20));
      await api.setSubtaskDueDate('t1', 'c1', null);
      await api.setSubtaskStartDate('t1', 'c1', DateTime(2026, 10, 2));
      await api.setSubtaskDescription('t1', 'c1', 'Ghi chú');
      await api.setSubtaskDescription('t1', 'c1', '');
      for (final r in rec.requests) {
        expect(r.method, 'PATCH');
        expect(r.uri.path, '/api/v1/tasks/t1/checklist/c1');
      }
      expect(rec.requests.map(bodyOf).toList(), [
        {'due_date': '2026-10-20'},
        {'due_date': null},
        {'start_date': '2026-10-02'},
        {'description': 'Ghi chú'},
        {'description': null},
      ]);
    });

    test(
      'moveSubtask: POST …/move {after_id}; lên đầu gửi after_id null',
      () async {
        await api.moveSubtask('t1', 'c3', afterId: 'c1');
        await api.moveSubtask('t1', 'c3', afterId: null);
        expect(rec.requests[0].method, 'POST');
        expect(rec.requests[0].uri.path, '/api/v1/tasks/t1/checklist/c3/move');
        expect(bodyOf(rec.requests[0]), {'after_id': 'c1'});
        expect(bodyOf(rec.requests[1]), {'after_id': null});
      },
    );

    test('copyTask: POST /tasks/{id}/copy {title}; đọc việc mới', () async {
      rec.body = jsonEncode({
        'success': true,
        'data': {'id': 't2', 'title': 'KAWAI (bản sao)'},
      });
      final copy = await api.copyTask('t1', title: 'KAWAI (bản sao)');
      expect(rec.single.method, 'POST');
      expect(rec.single.uri.path, '/api/v1/tasks/t1/copy');
      expect(bodyOf(rec.single), {'title': 'KAWAI (bản sao)'});
      expect(copy.id, 't2');
    });

    test(
      'nhắc việc: GET danh sách, POST remind_at ISO có múi giờ, DELETE',
      () async {
        rec.body = jsonEncode({
          'success': true,
          'data': [
            {
              'id': 'r1',
              'remind_at': '2026-10-12T01:30:00Z',
              'audience': 'me',
              'status': 'pending',
            },
          ],
        });
        final list = await api.reminders('t1');
        expect(rec.requests.last.method, 'GET');
        expect(rec.requests.last.uri.path, '/api/v1/tasks/t1/reminders');
        expect(list.single.id, 'r1');

        rec.body = jsonEncode({
          'success': true,
          'data': {
            'id': 'r2',
            'remind_at': '2026-10-12T01:30:00Z',
            'audience': 'everyone',
            'status': 'pending',
          },
        });
        final at = DateTime.utc(2026, 10, 12, 1, 30);
        final created = await api.addReminder('t1', at, everyone: true);
        final post = rec.requests.last;
        expect(post.method, 'POST');
        expect(post.uri.path, '/api/v1/tasks/t1/reminders');
        final body = bodyOf(post);
        expect(body.keys.toSet(), {'remind_at', 'audience'});
        expect(body['audience'], 'everyone');
        // Regex `CreateTaskReminderRequest`: bắt buộc có múi giờ.
        expect(
          RegExp(
            r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d+)?)?(Z|[+-]\d{2}:?\d{2})$',
          ).hasMatch(body['remind_at'] as String),
          isTrue,
        );
        expect(DateTime.parse(body['remind_at'] as String), at);
        expect(created.id, 'r2');

        await api.addReminder('t1', at.toLocal());
        expect(bodyOf(rec.requests.last)['audience'], 'me');
        expect(
          DateTime.parse(bodyOf(rec.requests.last)['remind_at'] as String),
          at,
        );

        rec.body = '{"success":true}';
        await api.deleteReminder('t1', 'r2');
        expect(rec.requests.last.method, 'DELETE');
        expect(rec.requests.last.uri.path, '/api/v1/tasks/t1/reminders/r2');
      },
    );

    test('bình luận kèm tệp: multipart files[] + mentioned_user_ids[]; thân '
        'rỗng không gửi body', () async {
      final dir = Directory.systemTemp.createTempSync('cmt');
      addTearDown(() {
        try {
          dir.deleteSync(recursive: true);
        } on FileSystemException {
          // Windows: luồng đọc tệp của Dio có thể còn giữ khoá.
        }
      });
      final a = File('${dir.path}/a.jpg')..writeAsBytesSync([1, 2, 3]);
      final b = File('${dir.path}/b.pdf')..writeAsBytesSync([4, 5]);

      await api.commentWithFiles(
        't1',
        '',
        files: [
          CommentUpload(path: a.path, name: 'a.jpg', isImage: true),
          CommentUpload(path: b.path, name: 'b.pdf', isImage: false),
        ],
      );
      final r = rec.single;
      expect(r.method, 'POST');
      expect(r.uri.path, '/api/v1/tasks/t1/comments');
      final form = r.data as FormData;
      expect(form.files.map((e) => e.key), ['files[]', 'files[]']);
      expect(form.files.map((e) => e.value.filename), ['a.jpg', 'b.pdf']);
      expect(form.fields.map((e) => e.key), isNot(contains('body')));

      rec.requests.clear();
      await api.commentWithFiles(
        't1',
        'Vết xước @Khánh',
        mentionedUserIds: ['u2', 'u3'],
        files: [CommentUpload(path: a.path, name: 'a.jpg', isImage: true)],
      );
      final form2 = rec.single.data as FormData;
      expect(form2.fields.map((e) => '${e.key}=${e.value}'), [
        'body=Vết xước @Khánh',
        'mentioned_user_ids[]=u2',
        'mentioned_user_ids[]=u3',
      ]);
    });

    test('bình luận kèm tệp: tệp không đọc được → NetworkException', () async {
      await expectLater(
        api.commentWithFiles(
          't1',
          'x',
          files: const [
            CommentUpload(path: '/khong/co.jpg', name: 'co.jpg', isImage: true),
          ],
        ),
        throwsA(isA<NetworkException>()),
      );
      expect(rec.requests, isEmpty);
    });

    test(
      'gỡ tệp bình luận: DELETE …/comments/{cid}/attachments/{aid}',
      () async {
        await api.deleteCommentAttachment('t1', 'cm1', 'a1');
        expect(rec.single.method, 'DELETE');
        expect(
          rec.single.uri.path,
          '/api/v1/tasks/t1/comments/cm1/attachments/a1',
        );
      },
    );
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
