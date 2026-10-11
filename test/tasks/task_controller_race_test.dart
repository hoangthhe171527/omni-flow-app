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
