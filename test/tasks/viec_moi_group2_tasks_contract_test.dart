import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/data/tasks_api.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/domain/task_label.dart';
import 'package:omni_app/modules/tasks/domain/task_permissions.dart';
import 'package:omni_app/security/permissions/access_policy.dart';

/// Hợp đồng Nhóm 2 phía việc (Task 10), đối chiếu `omni-flow-api` nhánh
/// `feat/viec-moi-api`:
///  * `TaskPresenter::withFlags` — `pinned`/`locked` LUÔN là bool ở API mới
///    (chi tiết lẫn dòng danh sách); API cũ không có khoá → `null`;
///  * `PeopleDirectory::apply` — `follower_names`/`follower_avatars` thẳng
///    hàng với `follower_ids` (null giữ chỗ ảnh); `assigned_by_name`/`_avatar`,
///    `created_by_name`/`_avatar` chỉ có khi tra được;
///  * routes — `POST|DELETE /tasks/{id}/pin` ($write), `/lock` ($write),
///    `/follow` ($read); `PUT /tasks/{id}` nhận `follower_ids[]`;
///  * khoá → 423 `{success:false, code:"task_locked", message}`;
///  * `GET /system-options/task-labels` (`tasks.read`) →
///    `[{code, label, color, sort_order}]`.
void main() {
  Map<String, dynamic> fixture(String name) =>
      (jsonDecode(File('test/contract/fixtures/$name').readAsStringSync())
              as Map<String, dynamic>)['data']
          as Map<String, dynamic>;

  group('đọc (Task.fromJson)', () {
    test(
      'API mới: pinned, locked, follower_*, assigned_by_*, created_by_*',
      () {
        final t = Task.fromJson(fixture('tasks_show_viec_moi_group2.json'));
        expect(t.pinned, isTrue);
        expect(t.locked, isTrue);
        expect(t.isPinned, isTrue);
        expect(t.isLocked, isTrue);
        expect(t.followerIds, [
          '01a071b9-6569-72ca-a631-69491063fa4e',
          '01a071b9-7777-72ca-a631-69491063fa4e',
        ]);
        expect(t.followerNames, ['Nguyễn Quân', 'Hằng Ni']);
        // Null GIỮ CHỖ: ảnh của Hằng Ni không được nhảy sang mặt Quân.
        expect(t.followerAvatars, [null, 'https://cdn.viomni.test/a/hn.png']);
        expect(t.assignedBy, '01a071b9-6528-7384-8013-5b68f7651994');
        expect(t.assignedByName, 'Trần Hưng');
        expect(t.assignedByAvatar, 'https://cdn.viomni.test/a/th.png');
        expect(t.createdByName, 'Trần Hưng');
        expect(t.createdByAvatar, 'https://cdn.viomni.test/a/th.png');
        expect(t.supportsPin, isTrue);
        expect(t.supportsLock, isTrue);
        expect(t.supportsFollowers, isTrue);
        expect(t.assignerName, 'Trần Hưng');
        expect(t.assignerAvatar, 'https://cdn.viomni.test/a/th.png');
      },
    );

    test('API cũ (fixture Task 1): mọi khả năng Nhóm 2 là null / tắt', () {
      final t = Task.fromJson(fixture('tasks_show_viec_moi.json'));
      expect(t.pinned, isNull);
      expect(t.locked, isNull);
      expect(t.followerIds, isNull);
      expect(t.isPinned, isFalse);
      expect(t.isLocked, isFalse);
      expect(t.supportsPin, isFalse);
      expect(t.supportsLock, isFalse);
      expect(t.supportsFollowers, isFalse);
      expect(t.assignedBy, isNull);
      expect(t.assignerName, isNull);
      expect(t.assignerAvatar, isNull);
    });

    test('API mới, việc chưa ai theo dõi: không có follower_ids nhưng có '
        'pinned → theo dõi được, danh sách rỗng', () {
      final t = Task.fromJson({
        'id': 't1',
        'title': 'x',
        'pinned': false,
        'locked': false,
      });
      expect(t.supportsFollowers, isTrue);
      expect(t.followerIds, isNull);
      expect(t.followers, isEmpty);
      expect(t.supportsPin, isTrue);
      expect(t.isPinned, isFalse);
    });

    test('follower_ids: [] (bỏ theo dõi hết) vẫn là API mới', () {
      final t = Task.fromJson({'id': 't1', 'title': 'x', 'follower_ids': []});
      expect(t.followerIds, isEmpty);
      expect(t.supportsFollowers, isTrue);
    });

    test('pinned/locked kiểu lạ (không phải bool) → null, không đoán', () {
      final t = Task.fromJson({
        'id': 't1',
        'title': 'x',
        'pinned': 'yes',
        'locked': 1,
      });
      expect(t.pinned, isNull);
      expect(t.locked, isNull);
    });

    test('có assigned_by mà không tra được tên: KHÔNG rơi về người tạo', () {
      final t = Task.fromJson({
        'id': 't1',
        'title': 'x',
        'assigned_by': 'u7',
        'created_by': 'u1',
        'created_by_name': 'Người tạo',
      });
      expect(t.assignerName, isNull);
    });

    test('việc cũ không có assigned_by: rơi về created_by_name (API mới)', () {
      final t = Task.fromJson({
        'id': 't1',
        'title': 'x',
        'created_by': 'u1',
        'created_by_name': 'Người tạo',
        'created_by_avatar': 'https://cdn.viomni.test/a/u1.png',
      });
      expect(t.assignerName, 'Người tạo');
      expect(t.assignerAvatar, 'https://cdn.viomni.test/a/u1.png');
    });

    test('followers ghép id/tên/ảnh theo chỉ số, an toàn khi mảng ngắn', () {
      final t = Task.fromJson({
        'id': 't1',
        'title': 'x',
        'follower_ids': ['a', 'b'],
        'follower_names': ['An'],
      });
      expect(t.followers.map((f) => (f.id, f.name, f.avatar)), [
        ('a', 'An', null),
        ('b', null, null),
      ]);
    });

    test('copyWith giữ mọi trường Nhóm 2 và đổi được pinned/locked/'
        'follower', () {
      final full = Task.fromJson(fixture('tasks_show_viec_moi_group2.json'));
      final kept = full.copyWith(status: 'done');
      expect(kept.pinned, full.pinned);
      expect(kept.locked, full.locked);
      expect(kept.followerIds, full.followerIds);
      expect(kept.followerNames, full.followerNames);
      expect(kept.followerAvatars, full.followerAvatars);
      expect(kept.assignedBy, full.assignedBy);
      expect(kept.assignedByName, full.assignedByName);
      expect(kept.assignedByAvatar, full.assignedByAvatar);
      expect(kept.createdByName, full.createdByName);
      expect(kept.createdByAvatar, full.createdByAvatar);

      final old = Task.fromJson(fixture('tasks_show_viec_moi.json'));
      expect(old.copyWith(status: 'done').pinned, isNull);
      expect(old.copyWith(status: 'done').followerIds, isNull);
      expect(full.copyWith(pinned: false).pinned, isFalse);
      expect(full.copyWith(locked: false).locked, isFalse);
    });
  });

  group('gửi (TasksApi)', () {
    late _Recorder rec;
    late TasksApi api;

    setUp(() {
      rec = _Recorder();
      api = TasksApi(ApiClient(Dio()..httpClientAdapter = rec));
    });

    Map<String, dynamic> bodyOf(RequestOptions o) =>
        (o.data is String ? jsonDecode(o.data as String) : o.data)
            as Map<String, dynamic>;

    for (final (name, call, method, path)
        in <(String, Future<Task> Function(TasksApi), String, String)>[
          (
            'ghim',
            (a) => a.setPinned('t1', true),
            'POST',
            '/api/v1/tasks/t1/pin',
          ),
          (
            'bỏ ghim',
            (a) => a.setPinned('t1', false),
            'DELETE',
            '/api/v1/tasks/t1/pin',
          ),
          (
            'khoá',
            (a) => a.setLocked('t1', true),
            'POST',
            '/api/v1/tasks/t1/lock',
          ),
          (
            'mở khoá',
            (a) => a.setLocked('t1', false),
            'DELETE',
            '/api/v1/tasks/t1/lock',
          ),
          (
            'theo dõi',
            (a) => a.setFollowing('t1', true),
            'POST',
            '/api/v1/tasks/t1/follow',
          ),
          (
            'bỏ theo dõi',
            (a) => a.setFollowing('t1', false),
            'DELETE',
            '/api/v1/tasks/t1/follow',
          ),
        ]) {
      test('$name: $method $path, không body, đọc việc trả về', () async {
        rec.body = jsonEncode({
          'success': true,
          'data': {
            'id': 't1',
            'title': 'x',
            'pinned': true,
            'locked': false,
            'follower_ids': ['me'],
          },
        });
        final task = await call(api);
        expect(rec.single.method, method);
        expect(rec.single.uri.path, path);
        expect(rec.single.data, anyOf(isNull, isEmpty));
        expect(task.pinned, isTrue);
        expect(task.followerIds, ['me']);
      });
    }

    test(
      'setFollowers: PUT /tasks/{id} {follower_ids} — đủ danh sách',
      () async {
        await api.setFollowers('t1', ['u1', 'u2']);
        expect(rec.single.method, 'PUT');
        expect(rec.single.uri.path, '/api/v1/tasks/t1');
        expect(bodyOf(rec.single), {
          'follower_ids': ['u1', 'u2'],
        });
      },
    );

    test('setFollowers rỗng vẫn GỬI khoá (bỏ hết người theo dõi)', () async {
      await api.setFollowers('t1', const []);
      expect(bodyOf(rec.single), {'follower_ids': <String>[]});
    });

    test('423 task_locked: ném lỗi mang mã và câu của server', () async {
      rec.status = 423;
      rec.body = jsonEncode({
        'success': false,
        'code': 'task_locked',
        'message': 'Công việc đã bị khoá. Mở khoá trước khi sửa.',
      });
      final error = await api
          .setTitle('t1', 'Mới')
          .then<Object?>((_) => null, onError: (Object e) => e);
      expect(error, isA<RequestRejectedException>());
      expect(isTaskLockedError(error!), isTrue);
      expect(
        (error as AppException).message,
        'Công việc đã bị khoá. Mở khoá trước khi sửa.',
      );
      expect(isTaskLockedError(const ServerException('x')), isFalse);
    });

    group('GET /system-options/task-labels', () {
      test('đúng đường dẫn, không tham số; đọc code/label/color', () async {
        rec.body = jsonEncode({
          'success': true,
          'data': [
            {
              'code': 'khan_cap',
              'label': 'Khẩn cấp',
              'color': '#ef4444',
              'sort_order': 0,
            },
            {'code': 'loai_1', 'label': 'Loại 1', 'color': null},
          ],
        });
        final labels = await api.taskLabelsForReaders();
        expect(rec.single.method, 'GET');
        expect(rec.single.uri.path, '/api/v1/system-options/task-labels');
        expect(rec.single.uri.queryParameters, isEmpty);
        expect(labels.map((l) => (l.code, l.label, l.color)), [
          ('khan_cap', 'Khẩn cấp', '#ef4444'),
          ('loai_1', 'Loại 1', null),
        ]);
      });

      for (final status in [403, 404]) {
        test(
          '$status (API cũ: route rơi vào /{id}) → [] chứ không ném',
          () async {
            rec.status = status;
            rec.body = '{"success":false,"message":"x"}';
            expect(await api.taskLabelsForReaders(), isEmpty);
          },
        );
      }

      test('lỗi khác vẫn ném', () async {
        rec.status = 500;
        rec.body = '{"success":false,"message":"boom"}';
        await expectLater(
          api.taskLabelsForReaders(),
          throwsA(isA<AppException>()),
        );
      });
    });
  });

  group('taskLabelsProvider chọn đường đọc theo quyền', () {
    Future<(List<TaskLabel>, List<String>)> read(Set<String> perms) async {
      final fake = _LabelsApi();
      final c = ProviderContainer(
        overrides: [
          tasksApiProvider.overrideWithValue(fake),
          taskAccessProvider.overrideWithValue(
            TaskAccess.of(AccessPolicy(perms)),
          ),
        ],
      );
      addTearDown(c.dispose);
      return (await c.read(taskLabelsProvider.future), fake.calls);
    }

    test('system_options.read → danh mục đầy đủ (có id để sửa)', () async {
      final (labels, calls) = await read({'tasks.read', 'system_options.read'});
      expect(calls, ['full']);
      expect(labels.single.id, 'o1');
    });

    test('chỉ tasks.read (thợ) → /system-options/task-labels', () async {
      final (labels, calls) = await read({'tasks.read', 'tasks.write'});
      expect(calls, ['readers']);
      expect(labels.single.code, 'khan_cap');
    });

    test('không quyền nào → [] và không gọi mạng', () async {
      final (labels, calls) = await read({});
      expect(labels, isEmpty);
      expect(calls, isEmpty);
    });
  });
}

class _LabelsApi implements TasksApi {
  final calls = <String>[];

  @override
  Future<List<TaskLabel>> taskLabels() async {
    calls.add('full');
    return const [TaskLabel(id: 'o1', code: 'khan_cap', label: 'Khẩn cấp')];
  }

  @override
  Future<List<TaskLabel>> taskLabelsForReaders() async {
    calls.add('readers');
    return const [TaskLabel(id: '', code: 'khan_cap', label: 'Khẩn cấp')];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
