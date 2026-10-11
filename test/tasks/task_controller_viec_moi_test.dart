import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/core/storage/preferences_store.dart';
import 'package:omni_app/modules/tasks/application/task_controller.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/data/tasks_api.dart';
import 'package:omni_app/modules/tasks/domain/custom_field.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Đường ghi Việc mới trong `TaskController`: cái gì lạc quan (nhãn, thích),
/// cái gì chờ server, và trường tuỳ chỉnh KHÔNG xoá trường khác.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeApi api;
  late ProviderContainer container;

  Future<TaskController> open(Task task) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    api = _FakeApi(task);
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        tasksApiProvider.overrideWithValue(api),
        taskRealtimeSignalProvider.overrideWith(_Silent.new),
      ],
    );
    addTearDown(container.dispose);
    container.listen(taskDetailProvider('t1'), (_, _) {});
    await container.read(taskDetailProvider('t1').future);
    return container.read(taskDetailProvider('t1').notifier);
  }

  Task visible() => container.read(taskDetailProvider('t1')).value!.task;

  final base = Task.fromJson(const {
    'id': 't1',
    'title': 'KAWAI',
    'labels': ['khan_cap'],
    'likes': ['u9'],
    'custom_fields': {'f1': 'Đen', 'f2': 3},
  });

  group('trường tuỳ chỉnh', () {
    test('sửa một trường gửi CẢ map đã gộp, không xoá trường khác', () async {
      final c = await open(base);
      await c.setCustomField('f3', '2026-01-02');

      expect(api.sentCustomFields, {'f1': 'Đen', 'f2': 3, 'f3': '2026-01-02'});
    });

    test('đổi giá trị trường đã có giữ nguyên các trường còn lại', () async {
      final c = await open(base);
      await c.setCustomField('f1', 'Trắng');

      expect(api.sentCustomFields, {'f1': 'Trắng', 'f2': 3});
    });

    test('xoá giá trị: gửi null cho trường đó, giữ trường khác', () async {
      final c = await open(base);
      await c.setCustomField('f2', null);

      expect(api.sentCustomFields, {'f1': 'Đen', 'f2': null});
    });

    test('màn hiện lại theo phản hồi máy chủ', () async {
      final c = await open(base);
      api.reply = Task.fromJson(const {
        'id': 't1',
        'title': 'KAWAI',
        'custom_fields': {'f1': 'server'},
      });
      await c.setCustomField('f1', 'Trắng');

      expect(visible().customFields, {'f1': 'server'});
    });
  });

  group('nhãn — lạc quan', () {
    test('hiện ngay trước khi server trả lời, rồi theo bản server', () async {
      final c = await open(base);
      api.gate = Completer<void>();
      api.reply = Task.fromJson(const {
        'id': 't1',
        'title': 'KAWAI',
        'labels': ['cho_khach', 'noi_bo'],
      });

      final pending = c.setLabels(['cho_khach']);
      expect(visible().labels, ['cho_khach']);

      api.gate!.complete();
      await pending;
      expect(api.sentLabels, ['cho_khach']);
      expect(visible().labels, ['cho_khach', 'noi_bo']);
    });

    test('lỗi thì hoàn tác và ném cho chỗ gọi báo', () async {
      final c = await open(base);
      api.fail = true;

      await expectLater(
        c.setLabels(const []),
        throwsA(isA<NetworkException>()),
      );
      expect(visible().labels, ['khan_cap']);
    });
  });

  group('thích — lạc quan', () {
    test('bật ngay cho người đang đăng nhập, rồi theo bản server', () async {
      final c = await open(base);
      api.gate = Completer<void>();
      api.reply = Task.fromJson(const {
        'id': 't1',
        'title': 'KAWAI',
        'likes': ['u9', 'u1'],
      });

      final pending = c.toggleLike('u1');
      expect(visible().isLikedBy('u1'), isTrue);
      expect(visible().likes, contains('u9'));

      api.gate!.complete();
      await pending;
      expect(api.likeCalls, 1);
      expect(visible().likes, ['u9', 'u1']);
    });

    test('bấm lại khi đã thích thì tắt ngay', () async {
      final c = await open(base);
      api.gate = Completer<void>();
      final pending = c.toggleLike('u9');
      expect(visible().isLikedBy('u9'), isFalse);
      api.gate!.complete();
      await pending;
    });

    test('lỗi thì hoàn tác và ném', () async {
      final c = await open(base);
      api.fail = true;

      await expectLater(c.toggleLike('u1'), throwsA(isA<NetworkException>()));
      expect(visible().likes, ['u9']);
    });
  });

  group('không lạc quan — hiện theo phản hồi', () {
    test('lưu trữ', () async {
      final c = await open(base);
      api.reply = Task.fromJson(const {'id': 't1', 'archived': true});
      await c.setArchived(true);
      expect(api.calls.last, 'setArchived(true)');
      expect(visible().archived, isTrue);
    });

    test('chuyển việc', () async {
      final c = await open(base);
      api.reply = Task.fromJson(const {
        'id': 't1',
        'project_id': 'p2',
        'section_id': 's1',
      });
      await c.moveTask(projectId: 'p2', sectionId: 's1');
      expect(api.calls.last, 'moveTask(p2,s1)');
      expect(visible().projectId, 'p2');
    });

    test('ngày bắt đầu', () async {
      final c = await open(base);
      api.reply = Task.fromJson(const {'id': 't1', 'start_date': '2026-02-01'});
      await c.setStartDate(DateTime(2026, 2, 1));
      expect(api.calls.last, 'setStartDate(2026-02-01)');
      expect(visible().startDate, isNotNull);
    });

    test('xoá tệp và xoá bình luận thay state bằng việc trả về', () async {
      final c = await open(base);
      api.reply = Task.fromJson(const {'id': 't1', 'title': 'sau xoá tệp'});
      await c.deleteAttachment('a9');
      expect(api.calls.last, 'deleteAttachment(a9)');
      expect(visible().title, 'sau xoá tệp');

      api.reply = Task.fromJson(const {'id': 't1', 'title': 'sau xoá bl'});
      await c.deleteComment('c3');
      expect(api.calls.last, 'deleteComment(c3)');
      expect(visible().title, 'sau xoá bl');
      // Không tải lại: chỉ một lần get lúc mở.
      expect(api.getCalls, 1);
    });
  });

  group('provider', () {
    test('archivedTasksProvider gọi list(archived: archived)', () async {
      await open(base);
      final items = await container.read(archivedTasksProvider('p1').future);
      expect(api.calls.last, 'list(p1,null,archived)');
      expect(items, isEmpty);
    });

    test('planCustomFieldsProvider đọc định nghĩa của kế hoạch', () async {
      await open(base);
      final defs = await container.read(planCustomFieldsProvider('p1').future);
      expect(defs.single.id, 'f1');
    });
  });
}

class _Silent extends TaskRealtimeSignal {
  @override
  int build() => 0;
}

class _FakeApi implements TasksApi {
  _FakeApi(this._task);

  final Task _task;
  Task? reply;
  Completer<void>? gate;
  bool fail = false;
  int getCalls = 0;
  int likeCalls = 0;
  List<String>? sentLabels;
  Map<String, Object?>? sentCustomFields;
  final calls = <String>[];

  Future<Task> _answer() async {
    if (gate != null) await gate!.future;
    if (fail) throw const NetworkException('Không có kết nối mạng');
    return reply ?? _task;
  }

  @override
  Future<Task> get(String id) async {
    getCalls++;
    return _task;
  }

  @override
  Future<Task> setLabels(String taskId, List<String> labels) {
    sentLabels = labels;
    return _answer();
  }

  @override
  Future<Task> toggleLike(String taskId) {
    likeCalls++;
    return _answer();
  }

  @override
  Future<Task> setCustomFields(String taskId, Map<String, Object?> fields) {
    sentCustomFields = fields;
    return _answer();
  }

  @override
  Future<Task> setArchived(String taskId, bool archived) {
    calls.add('setArchived($archived)');
    return _answer();
  }

  @override
  Future<Task> moveTask(
    String taskId, {
    required String projectId,
    String? sectionId,
  }) {
    calls.add('moveTask($projectId,$sectionId)');
    return _answer();
  }

  @override
  Future<Task> setStartDate(String taskId, DateTime? startDate) {
    final d = startDate;
    calls.add(
      'setStartDate(${d == null ? null : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'})',
    );
    return _answer();
  }

  @override
  Future<Task> deleteAttachment(String taskId, String attachmentId) {
    calls.add('deleteAttachment($attachmentId)');
    return _answer();
  }

  @override
  Future<Task> deleteComment(String taskId, String commentId) {
    calls.add('deleteComment($commentId)');
    return _answer();
  }

  @override
  Future<Paged<Task>> list({
    required String projectId,
    String? search,
    TaskArchiveScope archived = TaskArchiveScope.active,
    int page = 1,
    int perPage = 100,
  }) async {
    calls.add('list($projectId,$search,${archived.name})');
    return const Paged(items: [], pagination: ApiPagination.empty());
  }

  @override
  Future<List<CustomFieldDef>> projectCustomFields(String projectId) async => [
    const CustomFieldDef(id: 'f1', name: 'Màu'),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
