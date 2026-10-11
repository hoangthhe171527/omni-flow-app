import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/core/storage/preferences_store.dart';
import 'package:omni_app/modules/tasks/application/task_controller.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/data/tasks_api.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hai lượt ghi chồng nhau trên cùng một việc (rà soát Task 1–2).
///
/// * Lượt lạc quan hỏng chỉ được hoàn tác TRƯỜNG của nó, trên state mới nhất:
///   đặt lại cả việc về ảnh chụp cũ là xoá luôn lượt ghi khác đã được server
///   xác nhận trong lúc nó bay.
/// * Hai lượt sửa trường tuỳ chỉnh liền nhau: lượt sau không được gửi map
///   thiếu giá trị của lượt trước (server thay cả map).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _GatedApi api;
  late ProviderContainer container;

  Future<TaskController> open(Task task) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    api = _GatedApi(task);
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

  group('lạc quan hỏng chỉ hoàn tác trường của nó', () {
    test('nhãn hỏng sau khi lượt thích đã xong: giữ lượt thích', () async {
      final c = await open(base);
      final labels = c.setLabels(['noi_bo']);
      // Lượt nhãn đi qua hàng đợi: gửi sau một nhịp vi tác vụ.
      await Future<void>.delayed(Duration.zero);
      final like = c.toggleLike('u1');

      // Lượt thứ hai xong trước: server chưa có nhãn mới, đã có lượt thích.
      api.resolve(
        'toggleLike',
        Task.fromJson(const {
          'id': 't1',
          'title': 'KAWAI',
          'labels': ['khan_cap'],
          'likes': ['u9', 'u1'],
          'custom_fields': {'f1': 'Đen', 'f2': 3},
        }),
      );
      await like;
      // Lượt nhãn hỏng sau.
      api.reject('setLabels');
      await expectLater(labels, throwsA(isA<NetworkException>()));

      expect(visible().likes, ['u9', 'u1']);
      expect(visible().labels, ['khan_cap']);
    });

    test(
      'nhãn hỏng sau một lượt ghi chờ server: giữ kết quả lượt đó',
      () async {
        final c = await open(base);
        final labels = c.setLabels(['noi_bo']);
        // Lượt nhãn đi qua hàng đợi: gửi sau một nhịp vi tác vụ.
        await Future<void>.delayed(Duration.zero);
        final start = c.setStartDate(DateTime(2026, 10, 20));

        api.resolve(
          'setStartDate',
          Task.fromJson(const {
            'id': 't1',
            'title': 'KAWAI',
            'labels': ['khan_cap'],
            'likes': ['u9'],
            'start_date': '2026-10-20',
          }),
        );
        await start;
        api.reject('setLabels');
        await expectLater(labels, throwsA(isA<NetworkException>()));

        expect(visible().startDate, isNotNull);
        expect(visible().startDate!.day, 20);
        expect(visible().labels, ['khan_cap']);
      },
    );

    test('thích hỏng sau khi lượt nhãn đã xong: giữ nhãn', () async {
      final c = await open(base);
      final like = c.toggleLike('u1');
      final labels = c.setLabels(['noi_bo']);
      // Lượt nhãn đi qua hàng đợi: gửi sau một nhịp vi tác vụ.
      await Future<void>.delayed(Duration.zero);

      api.resolve(
        'setLabels',
        Task.fromJson(const {
          'id': 't1',
          'title': 'KAWAI',
          'labels': ['noi_bo'],
          'likes': ['u9'],
        }),
      );
      await labels;
      api.reject('toggleLike');
      await expectLater(like, throwsA(isA<NetworkException>()));

      expect(visible().labels, ['noi_bo']);
      expect(visible().likes, ['u9']);
    });
  });

  group('lượt chờ server áp lên state MỚI NHẤT, giữ hàng chờ tick', () {
    final withSub = Task.fromJson(const {
      'id': 't1',
      'title': 'KAWAI',
      'checklist': [
        {'id': 's1', 'title': 'Lên dây', 'done': false},
      ],
    });
    final serverAfter = Task.fromJson(const {
      'id': 't1',
      'title': 'KAWAI',
      'start_date': '2026-10-20',
      'status': 'doing',
      'checklist': [
        {'id': 's1', 'title': 'Lên dây', 'done': false},
      ],
    });

    PendingTick? pendingS1() =>
        container.read(taskDetailProvider('t1')).value!.pendingFor('s1');

    final writes = <String, Future<void> Function(TaskController)>{
      'setStartDate': (c) => c.setStartDate(DateTime(2026, 10, 20)),
      'setStatus': (c) => c.setStatus('doing'),
      'moveToSection': (c) => c.moveToSection('sec2'),
    };

    for (final entry in writes.entries) {
      test('${entry.key} về sau khi tick việc con đã vào hàng chờ', () async {
        final c = await open(withSub);
        final write = entry.value(c);
        // Tick xảy ra TRONG LÚC lượt ghi đang bay; mạng của tick chưa về.
        final tick = c.toggleSubtask('s1', done: true);
        expect(pendingS1(), isNotNull);

        api.resolve(entry.key, serverAfter);
        await write;

        expect(pendingS1(), isNotNull, reason: 'hàng chờ tick bị ghi đè');
        expect(pendingS1()!.done, isTrue);
        final state = container.read(taskDetailProvider('t1')).value!;
        expect(state.task.status, 'doing');
        expect(state.visible.subtasks.single.done, isTrue);

        api.resolve('setSubtaskDone', serverAfter);
        await tick;
      });
    }

    test('tick hỏng trong lúc lượt ghi bay: lỗi vẫn còn sau đó', () async {
      final c = await open(withSub);
      final write = c.setStartDate(DateTime(2026, 10, 20));
      final tick = c.toggleSubtask('s1', done: true);
      api.reject('setSubtaskDone');
      await tick;
      expect(pendingS1()!.failed, isTrue);

      api.resolve('setStartDate', serverAfter);
      await write;

      expect(pendingS1(), isNotNull);
      expect(pendingS1()!.failed, isTrue);
      expect(visible().startDate!.day, 20);
    });

    test('lượt ghi chờ server giữ kết quả lượt lạc quan xen giữa', () async {
      final c = await open(base);
      final start = c.setStartDate(DateTime(2026, 10, 20));
      final labels = c.setLabels(['noi_bo']);
      // Lượt nhãn đi qua hàng đợi: gửi sau một nhịp vi tác vụ.
      await Future<void>.delayed(Duration.zero);
      api.resolve(
        'setLabels',
        Task.fromJson(const {
          'id': 't1',
          'title': 'KAWAI',
          'labels': ['noi_bo'],
          'likes': ['u9'],
        }),
      );
      await labels;
      // Bản server của lượt ngày bắt đầu đã có nhãn mới (server ghi tuần tự).
      api.resolve(
        'setStartDate',
        Task.fromJson(const {
          'id': 't1',
          'title': 'KAWAI',
          'labels': ['noi_bo'],
          'likes': ['u9'],
          'start_date': '2026-10-20',
        }),
      );
      await start;
      expect(visible().labels, ['noi_bo']);
      expect(visible().startDate!.day, 20);
    });
  });

  group('lượt khác về trong lúc nhãn / thích lạc quan đang bay', () {
    const stale = {
      'id': 't1',
      'title': 'KAWAI',
      'labels': ['khan_cap'],
      'likes': ['u9'],
      'start_date': '2026-10-20',
    };

    test('ngày bắt đầu về trước: nhãn đang chờ không bật về cũ', () async {
      final c = await open(base);
      final labels = c.setLabels(['noi_bo']);
      // Lượt nhãn đi qua hàng đợi: gửi sau một nhịp vi tác vụ.
      await Future<void>.delayed(Duration.zero);
      final start = c.setStartDate(DateTime(2026, 10, 20));
      api.resolve('setStartDate', Task.fromJson(stale));
      await start;
      expect(visible().labels, ['noi_bo']);
      expect(visible().startDate!.day, 20);

      api.resolve(
        'setLabels',
        Task.fromJson({
          ...stale,
          'labels': ['noi_bo'],
        }),
      );
      await labels;
      expect(visible().labels, ['noi_bo']);
      expect(visible().startDate!.day, 20);
    });

    test('ngày bắt đầu về trước: lượt thích đang chờ không mất', () async {
      final c = await open(base);
      final like = c.toggleLike('u1');
      final start = c.setStartDate(DateTime(2026, 10, 20));
      api.resolve('setStartDate', Task.fromJson(stale));
      await start;
      expect(visible().likes, ['u9', 'u1']);

      api.resolve(
        'toggleLike',
        Task.fromJson({
          ...stale,
          'likes': ['u9', 'u1'],
        }),
      );
      await like;
      expect(visible().likes, ['u9', 'u1']);
    });

    test('thích xong trước: nhãn đang chờ không bật về cũ', () async {
      final c = await open(base);
      final labels = c.setLabels(['noi_bo']);
      // Lượt nhãn đi qua hàng đợi: gửi sau một nhịp vi tác vụ.
      await Future<void>.delayed(Duration.zero);
      final like = c.toggleLike('u1');
      api.resolve(
        'toggleLike',
        Task.fromJson({
          ...stale,
          'likes': ['u9', 'u1'],
        }),
      );
      await like;
      expect(visible().labels, ['noi_bo']);
      expect(visible().likes, ['u9', 'u1']);

      api.reject('setLabels');
      await expectLater(labels, throwsA(isA<NetworkException>()));
      expect(visible().labels, ['khan_cap']);
      expect(visible().likes, ['u9', 'u1']);
    });
  });

  group('trường tuỳ chỉnh: hai lượt liền nhau', () {
    test('lượt sau gửi map có cả giá trị của lượt trước', () async {
      final c = await open(base);
      final first = c.setCustomField('f1', 'Trắng');
      final second = c.setCustomField('f3', 'x');

      // Lượt sau chờ lượt trước, không gửi song song với map cũ.
      await pumpEventQueue();
      expect(api.sentCustomFields, hasLength(1));

      api.resolveCustomFieldsEcho();
      await first;
      await pumpEventQueue();
      api.resolveCustomFieldsEcho();
      await second;

      expect(api.sentCustomFields.last, {'f1': 'Trắng', 'f2': 3, 'f3': 'x'});
      expect(visible().customFields, {'f1': 'Trắng', 'f2': 3, 'f3': 'x'});
    });

    test(
      'lượt trước hỏng thì lượt sau vẫn chạy, không mang giá trị hỏng',
      () async {
        final c = await open(base);
        final first = c.setCustomField('f1', 'Trắng');
        final second = c.setCustomField('f3', 'x');

        await pumpEventQueue();
        api.reject('setCustomFields');
        await expectLater(first, throwsA(isA<NetworkException>()));
        await pumpEventQueue();
        api.resolveCustomFieldsEcho();
        await second;

        expect(api.sentCustomFields.last, {'f1': 'Đen', 'f2': 3, 'f3': 'x'});
      },
    );
  });
}

class _GatedApi implements TasksApi {
  _GatedApi(this._task);

  final Task _task;
  final _pending = <String, List<Completer<Task>>>{};
  final sentCustomFields = <Map<String, Object?>>[];

  Future<Task> _wait(String name) {
    final c = Completer<Task>();
    _pending.putIfAbsent(name, () => []).add(c);
    return c.future;
  }

  Completer<Task> _take(String name) {
    final list = _pending[name];
    if (list == null || list.isEmpty) {
      throw StateError('không có lượt $name nào đang chờ');
    }
    return list.removeAt(0);
  }

  void resolve(String name, Task task) => _take(name).complete(task);

  void reject(String name) =>
      _take(name).completeError(const NetworkException('Không có kết nối'));

  /// Server trả lại đúng map vừa nhận.
  void resolveCustomFieldsEcho() => _take('setCustomFields').complete(
    Task.fromJson({
      'id': 't1',
      'title': 'KAWAI',
      'labels': const ['khan_cap'],
      'likes': const ['u9'],
      'custom_fields': sentCustomFields.last,
    }),
  );

  @override
  Future<Task> get(String id) async => _task;

  @override
  Future<Task> setLabels(String taskId, List<String> labels) =>
      _wait('setLabels');

  @override
  Future<Task> toggleLike(String taskId) => _wait('toggleLike');

  @override
  Future<Task> setStartDate(String taskId, DateTime? startDate) =>
      _wait('setStartDate');

  @override
  Future<Task> setStatus(String taskId, String status) => _wait('setStatus');

  @override
  Future<Task> moveToSection(String taskId, String? sectionId) =>
      _wait('moveToSection');

  @override
  Future<Task> setSubtaskDone(
    String taskId,
    String subtaskId, {
    required bool done,
    String? clientRequestId,
  }) => _wait('setSubtaskDone');

  @override
  Future<Task> setCustomFields(String taskId, Map<String, Object?> fields) {
    sentCustomFields.add(Map.of(fields));
    return _wait('setCustomFields');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Silent extends TaskRealtimeSignal {
  @override
  int build() => 0;
}
