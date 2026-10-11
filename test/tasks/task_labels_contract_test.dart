import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/data/tasks_api.dart';
import 'package:omni_app/modules/tasks/domain/task_label.dart';
import 'package:omni_app/modules/tasks/domain/task_permissions.dart';
import 'package:omni_app/security/permissions/access_policy.dart';

/// Bộ nhãn công ty `TASK_LABEL` (`system_options`).
///
/// Đối chiếu `omni-flow-api` origin/main, `SystemOptionController`:
///  * index: `group_key` BẮT BUỘC (thiếu → 422), `active_only` boolean,
///    quyền `system_options.read`;
///  * store: group_key, code (regex `^[a-z0-9_]+$`, ≤100), label (≤255), color?
///    (≤30), quyền `system_options.write`;
///  * update: label, color — KHÔNG có code / group_key.
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

  group('GET /system-options', () {
    test(
      'đúng group_key=TASK_LABEL&active_only=1, parse id/code/label/color',
      () async {
        rec.body = jsonEncode({
          'success': true,
          'data': [
            {
              'id': 'o1',
              'tenant_id': 'x',
              'group_key': 'TASK_LABEL',
              'code': 'khan_cap',
              'label': 'Khẩn cấp',
              'color': '#ef4444',
              'icon': null,
              'sort_order': 0,
              'is_default': false,
              'is_system': true,
              'is_active': true,
            },
            {
              'id': 'o2',
              'group_key': 'TASK_LABEL',
              'code': 'loai_1',
              'label': 'Loại 1',
              'color': null,
              'is_system': false,
            },
          ],
        });

        final labels = await api.taskLabels();
        expect(rec.single.method, 'GET');
        expect(rec.single.uri.path, '/api/v1/system-options');
        expect(rec.single.uri.queryParameters, {
          'group_key': 'TASK_LABEL',
          'active_only': '1',
        });
        expect(labels.map((l) => l.code), ['khan_cap', 'loai_1']);
        expect(labels.first.id, 'o1');
        expect(labels.first.label, 'Khẩn cấp');
        expect(labels.first.color, '#ef4444');
        expect(labels.first.isSystem, isTrue);
        expect(labels.last.color, isNull);
      },
    );

    test('403 (thiếu system_options.read) → [] chứ không ném', () async {
      rec.status = 403;
      rec.body = '{"success":false,"message":"Forbidden"}';
      expect(await api.taskLabels(), isEmpty);
    });

    test('lỗi khác vẫn ném', () async {
      rec.status = 500;
      rec.body = '{"success":false,"message":"boom"}';
      await expectLater(api.taskLabels(), throwsA(isA<AppException>()));
    });
  });

  group('POST /system-options', () {
    // Mã mới phải tránh CẢ mã của nhãn đã tắt: `createLabel` đọc danh mục
    // KHÔNG `active_only` trước khi sinh mã. Dùng lại mã của nhãn đã tắt là
    // gắn tên/màu mới lên các việc cũ còn mang mã đó.
    test(
      'đọc danh mục KHÔNG active_only rồi gửi {group_key, code, label, color}',
      () async {
        rec.getBody = jsonEncode({'success': true, 'data': []});
        rec.body = jsonEncode({
          'success': true,
          'data': {
            'id': 'o9',
            'code': 'cho_linh_kien',
            'label': 'Chờ linh kiện',
            'color': '#0E7490',
          },
        });
        final created = await api.createLabel(
          label: 'Chờ linh kiện',
          color: '#0E7490',
        );
        expect(rec.requests, hasLength(2));
        final get = rec.requests.first;
        expect(get.method, 'GET');
        expect(get.uri.path, '/api/v1/system-options');
        expect(get.uri.queryParameters, {'group_key': 'TASK_LABEL'});
        final post = rec.requests.last;
        expect(post.method, 'POST');
        expect(post.uri.path, '/api/v1/system-options');
        expect(bodyOf(post), {
          'group_key': 'TASK_LABEL',
          'code': 'cho_linh_kien',
          'label': 'Chờ linh kiện',
          'color': '#0E7490',
        });
        expect(created.id, 'o9');
      },
    );

    test('mã trùng (kể cả nhãn đã tắt) thì thêm _2, _3…', () async {
      rec.getBody = jsonEncode({
        'success': true,
        'data': [
          {'id': 'o1', 'code': 'khan_cap', 'label': 'Khẩn cấp'},
          {
            'id': 'o2',
            'code': 'khan_cap_2',
            'label': 'Khẩn cấp cũ',
            'is_active': false,
          },
        ],
      });
      await api.createLabel(label: 'Khẩn cấp', color: '#B42318');
      expect(bodyOf(rec.requests.last)['code'], 'khan_cap_3');
    });

    test('không đọc được danh mục (403) vẫn tạo được', () async {
      rec.getStatus = 403;
      rec.getBody = '{"success":false,"message":"Forbidden"}';
      await api.createLabel(label: 'Nội bộ 2');
      expect(rec.requests.last.method, 'POST');
      expect(bodyOf(rec.requests.last)['code'], 'noi_bo_2');
    });

    test('không màu thì không gửi khoá color', () async {
      rec.getBody = jsonEncode({'success': true, 'data': []});
      await api.createLabel(label: 'Nội bộ 2');
      expect(bodyOf(rec.requests.last).containsKey('color'), isFalse);
    });
  });

  group('PUT /system-options/{id}', () {
    test('gửi đúng {label, color}, không code', () async {
      await api.updateLabel('o1', label: 'Gấp', color: '#B42318');
      expect(rec.single.method, 'PUT');
      expect(rec.single.uri.path, '/api/v1/system-options/o1');
      expect(bodyOf(rec.single), {'label': 'Gấp', 'color': '#B42318'});
    });
  });

  group('sinh mã nhãn', () {
    test('bỏ dấu, chữ thường, _ ; khớp ^[a-z0-9_]+\$', () {
      final re = RegExp(r'^[a-z0-9_]+$');
      for (final (name, code) in [
        ('Chờ khách', 'cho_khach'),
        ('Đã duyệt!', 'da_duyet'),
        ('  Bảo   hành  2 ', 'bao_hanh_2'),
        ('Ưu tiên #1', 'uu_tien_1'),
      ]) {
        final got = TaskLabel.codeFor(name);
        expect(got, code, reason: name);
        expect(re.hasMatch(got), isTrue);
      }
    });

    test('tên không còn ký tự hợp lệ vẫn ra mã hợp lệ', () {
      expect(
        RegExp(r'^[a-z0-9_]+$').hasMatch(TaskLabel.codeFor('!!!')),
        isTrue,
      );
    });

    test('mã không dài quá 100', () {
      expect(TaskLabel.codeFor('a' * 300).length, lessThanOrEqualTo(100));
      expect(
        TaskLabel.codeFor('a' * 300, taken: {'a' * 100}).length,
        lessThanOrEqualTo(100),
      );
    });
  });

  group('quyền', () {
    test('canEditLabels đọc system_options.write', () {
      expect(
        TaskAccess.of(const AccessPolicy({'tasks.read'})).canEditLabels,
        isFalse,
      );
      expect(
        TaskAccess.of(
          const AccessPolicy({'tasks.read', 'system_options.write'}),
        ).canEditLabels,
        isTrue,
      );
    });

    test('canReadLabels đọc system_options.read', () {
      expect(
        TaskAccess.of(const AccessPolicy({'tasks.read'})).canReadLabels,
        isFalse,
      );
      expect(
        TaskAccess.of(
          const AccessPolicy({'system_options.read'}),
        ).canReadLabels,
        isTrue,
      );
    });
  });

  group('taskLabelsProvider', () {
    test('có quyền đọc thì tải danh mục', () async {
      final fake = _FakeLabelsApi();
      final c = ProviderContainer(
        overrides: [
          tasksApiProvider.overrideWithValue(fake),
          taskAccessProvider.overrideWithValue(
            TaskAccess.of(const AccessPolicy({'system_options.read'})),
          ),
        ],
      );
      addTearDown(c.dispose);
      final labels = await c.read(taskLabelsProvider.future);
      expect(labels.single.code, 'khan_cap');
      expect(fake.calls, 1);
    });

    test('không có quyền đọc → [] và không gọi mạng', () async {
      final fake = _FakeLabelsApi();
      final c = ProviderContainer(
        overrides: [
          tasksApiProvider.overrideWithValue(fake),
          taskAccessProvider.overrideWithValue(
            // Có `tasks.read` thì đi `/system-options/task-labels` (Nhóm 2,
            // xem viec_moi_group2_tasks_contract_test); ở đây không quyền nào.
            TaskAccess.of(const AccessPolicy({})),
          ),
        ],
      );
      addTearDown(c.dispose);
      expect(await c.read(taskLabelsProvider.future), isEmpty);
      expect(fake.calls, 0);
    });
  });
}

class _FakeLabelsApi implements TasksApi {
  int calls = 0;

  @override
  Future<List<TaskLabel>> taskLabels() async {
    calls++;
    return const [TaskLabel(id: 'o1', code: 'khan_cap', label: 'Khẩn cấp')];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Recorder implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  int status = 200;
  String body = '{"success":true,"data":{"id":"o1","code":"x","label":"x"}}';

  /// Trả lời riêng cho GET (danh mục), khi đặt.
  String? getBody;
  int? getStatus;

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
    final isGet = options.method == 'GET' && getBody != null;
    return ResponseBody.fromString(
      isGet ? getBody! : body,
      isGet ? (getStatus ?? 200) : status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
