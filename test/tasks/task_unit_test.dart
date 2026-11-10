import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/inventory/domain/inventory_models.dart';
import 'package:omni_app/modules/tasks/application/task_controller.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/data/tasks_api.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';

/// Kho nối Xưởng phía việc: đọc `subject` / `unit` đúng khoá của API
/// (`WorkState::subject`, `UnitLookup::summaries`), quy tắc cột "Đã giao" và tô
/// ưu tiên, và sau lượt ghi đổi trạng thái thì việc được đọc lại + Kho được báo.
void main() {
  Map<String, dynamic> unitJson({
    String place = 'in_stock',
    String sale = 'sold',
    Object? condition = 'refurbishing',
  }) => {
    'id': 'u1',
    'maker': 'YAMAHA',
    'model': 'U1E',
    'serial': '1176498',
    'category': 'Piano Upright cũ',
    'lot_id': 'l61',
    'lot_code': 'Ep 61',
    'place': place,
    'condition': condition,
    'sale': sale,
    'retail_hold': false,
    'customer_id': 'c1',
    'customer_name': 'Trần Minh Khôi',
    'received_at': '2026-08-17',
  };

  Task task({
    Object? subject = const {'type': 'unit', 'id': 'u1', 'role': 'refurbish'},
    Object? unit,
    String status = 'todo',
  }) => Task.fromJson({
    'id': 't1',
    'title': 'YAMAHA U1E 1176498',
    'status': status,
    'subject': subject,
    'unit': unit,
  });

  group('đọc subject / unit', () {
    test('đủ khoá: mọi trường của cây đọc đúng tên', () {
      final t = task(unit: unitJson());

      expect(t.subject!.type, 'unit');
      expect(t.subject!.id, 'u1');
      expect(t.subject!.role, 'refurbish');
      final u = t.unit!;
      expect(u.id, 'u1');
      expect(u.maker, 'YAMAHA');
      expect(u.model, 'U1E');
      expect(u.serial, '1176498');
      expect(u.category, 'Piano Upright cũ');
      expect(u.lotId, 'l61');
      expect(u.lotCode, 'Ep 61');
      expect(u.place, 'in_stock');
      expect(u.condition, 'refurbishing');
      expect(u.sale, 'sold');
      expect(u.retailHold, isFalse);
      expect(u.customerId, 'c1');
      expect(u.customerName, 'Trần Minh Khôi');
      expect(u.receivedAt, '2026-08-17');
      expect(u.name, 'YAMAHA U1E');
      expect(u.customerLine, 'Trần Minh Khôi · Ep 61');
    });

    test('việc thường (vắng khoá) và cây đã xoá (unit null)', () {
      final plain = Task.fromJson({'id': 't0', 'title': 'Việc thường'});
      expect(plain.subject, isNull);
      expect(plain.unit, isNull);
      expect(plain.isDeliveredRefurbish, isFalse);
      expect(plain.isSoldPriority, isFalse);

      final gone = task();
      expect(gone.subject, isNotNull);
      expect(gone.unit, isNull);
    });

    test('kiểu lạ không ném: thiếu role là tân trang, số đọc thành chữ', () {
      final t = task(
        subject: {'type': 'unit', 'id': 77},
        unit: {'id': 5, 'maker': 'KAWAI', 'model': 'K5', 'retail_hold': 1},
      );

      expect(t.subject!.id, '77');
      expect(t.subject!.role, 'refurbish');
      expect(t.unit!.id, '5');
      expect(t.unit!.retailHold, isTrue);
      expect(t.unit!.place, 'incoming');
      expect(t.unit!.sale, 'available');
      expect(t.unit!.customerLine, 'Chưa có khách');
      expect(task(subject: 'unit').subject, isNull);
      expect(task(subject: {'type': 'unit'}).subject, isNull);
      expect(task(unit: const <dynamic>[]).unit, isNull);
    });

    test('copyWith giữ subject và unit (tick công đoạn đi qua đây)', () {
      final t = task(unit: unitJson());
      final copy = t.copyWith(status: 'done');

      expect(copy.subject, same(t.subject));
      expect(copy.unit, same(t.unit));
    });

    test('nhãn tình trạng khớp bảng của Kho', () {
      for (final c in UnitCondition.values) {
        expect(TaskUnit(id: 'u', condition: c.wire).conditionLabel, c.label);
      }
      expect(const TaskUnit(id: 'u').conditionLabel, UnitCondition.noneLabel);
    });
  });

  group('quy tắc bảng xưởng', () {
    test('cột Đã giao: tân trang + cây đã giao; bảo hành thì không', () {
      expect(
        task(unit: unitJson(place: 'delivered')).isDeliveredRefurbish,
        isTrue,
      );
      expect(task(unit: unitJson()).isDeliveredRefurbish, isFalse);
      expect(
        task(
          subject: {'type': 'unit', 'id': 'u1', 'role': 'warranty'},
          unit: unitJson(place: 'delivered'),
        ).isDeliveredRefurbish,
        isFalse,
      );
    });

    test('ưu tiên: đã bán, việc chưa xong, cây chưa giao', () {
      expect(task(unit: unitJson()).isSoldPriority, isTrue);
      expect(task(unit: unitJson(), status: 'done').isSoldPriority, isFalse);
      expect(task(unit: unitJson(place: 'delivered')).isSoldPriority, isFalse);
      expect(task(unit: unitJson(sale: 'reserved')).isSoldPriority, isFalse);
    });
  });

  group('sau lượt ghi đổi trạng thái', () {
    Future<(ProviderContainer, _FakeTasksApi)> open(Task initial) async {
      final api = _FakeTasksApi();
      final container = ProviderContainer(
        overrides: [
          tasksApiProvider.overrideWithValue(api),
          taskDetailProvider.overrideWith(
            () => _StubDetail(TaskDetailState(task: initial)),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(
        taskDetailProvider('t1'),
        (_, _) {},
        fireImmediately: true,
      );
      await container.read(taskDetailProvider('t1').future);

      return (container, api);
    }

    test('xong việc có cây: đọc lại việc và báo Kho tải lại', () async {
      final (container, api) = await open(task(unit: unitJson()));
      api.onStatus = task(unit: unitJson(), status: 'done');
      api.onGet = task(
        unit: unitJson(condition: 'ready'),
        status: 'done',
      );

      await container.read(taskDetailProvider('t1').notifier).setStatus('done');
      await Future<void>.delayed(Duration.zero);

      expect(api.gets, 1);
      expect(container.read(unitWorkRevisionProvider), 1);
      final shown = container.read(taskDetailProvider('t1')).value!.task;
      expect(shown.unit!.condition, 'ready');
      expect(shown.unit!.conditionLabel, 'Sẵn sàng');
    });

    test('việc thường: không đọc lại, không báo Kho', () async {
      final plain = Task.fromJson({'id': 't1', 'title': 'Việc thường'});
      final (container, api) = await open(plain);
      api.onStatus = plain.copyWith(status: 'done');

      await container.read(taskDetailProvider('t1').notifier).setStatus('done');
      await Future<void>.delayed(Duration.zero);

      expect(api.gets, 0);
      expect(container.read(unitWorkRevisionProvider), 0);
    });
  });
}

class _StubDetail extends TaskController {
  _StubDetail(this.initial);

  final TaskDetailState initial;

  @override
  Future<TaskDetailState> build(String taskId) async => initial;
}

class _FakeTasksApi implements TasksApi {
  late Task onStatus;
  late Task onGet;
  int gets = 0;

  @override
  Future<Task> setStatus(String taskId, String status) async => onStatus;

  @override
  Future<Task> get(String taskId) async {
    gets++;
    return onGet;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
