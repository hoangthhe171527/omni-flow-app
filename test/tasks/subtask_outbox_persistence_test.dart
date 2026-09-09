import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/core/storage/preferences_store.dart';
import 'package:omni_app/modules/tasks/application/task_controller.dart';
import 'package:omni_app/modules/tasks/data/tasks_api.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tick một công đoạn lúc mất sóng, rồi RỜI màn chi tiết.
///
/// `test/tasks/subtask_outbox_test.dart` đã đo hàng chờ tick, nhưng chỉ đo
/// trong một `TaskDetailState` dựng bằng tay — nó không bao giờ chạm tới vòng
/// đời của provider. `taskDetailProvider` là autoDispose, nên bấm quay lại là
/// huỷ notifier và huỷ luôn hàng chờ nằm trong RAM của nó. Bài này đo đúng
/// khoảng trống đó: đóng container (= rời màn hình), mở lại, và hỏi tick còn
/// không.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Task piano({required bool boMayDone}) => Task.fromJson({
    'id': 't1',
    'title': 'KAWAI HAT-5 2308512',
    'checklist': [
      {'id': 'c1', 'title': 'Bộ máy', 'done': boMayDone},
      {'id': 'c2', 'title': 'Nắp phím', 'done': false},
    ],
  });

  ProviderContainer open(SharedPreferences prefs, TasksApi api) {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        tasksApiProvider.overrideWithValue(api),
      ],
    );
    // Giữ một người nghe: provider là autoDispose, không giữ thì nó bị huỷ
    // ngay giữa hai lần đọc và bài kiểm sẽ đo nhầm thứ khác.
    container.listen(
      taskDetailProvider('t1'),
      (_, _) {},
      fireImmediately: true,
    );

    return container;
  }

  test('tick chưa gửi được vẫn còn khi mở lại công việc', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();

    // Ca sáng: thợ tick "Bộ máy", xưởng mất sóng, ô báo chưa lưu được.
    final first = open(prefs, _OfflineTasksApi(piano(boMayDone: false)));
    await first.read(taskDetailProvider('t1').future);
    await first
        .read(taskDetailProvider('t1').notifier)
        .toggleSubtask('c1', done: true);

    expect(
      first.read(taskDetailProvider('t1')).value!.pendingFor('c1')?.failed,
      isTrue,
      reason: 'tiền đề: lần tick này đã hỏng và đang nằm trong hàng chờ',
    );

    // Thợ bấm quay lại. taskDetailProvider là autoDispose nên nó bị huỷ ở đây.
    first.dispose();

    // Ca chiều: mở lại đúng cây đàn đó, vẫn chưa có sóng.
    final second = open(prefs, _OfflineTasksApi(piano(boMayDone: false)));
    final reopened = await second.read(taskDetailProvider('t1').future);
    second.dispose();

    final restored = reopened.pendingFor('c1');
    expect(
      restored,
      isNotNull,
      reason:
          'Tick chưa gửi được đã biến mất cùng provider. Ô tự bỏ tick và không '
          'còn gì nói rằng nó chưa lưu — công đoạn coi như chưa ai làm.',
    );
    expect(restored!.done, isTrue);
    expect(
      restored.failed,
      isTrue,
      reason: 'phải ở trạng thái lỗi thì hàng mới hiện được nút "Thử lại"',
    );
    expect(
      restored.clientRequestId,
      isNotEmpty,
      reason: 'gửi lại phải mang đúng khoá cũ, không sinh khoá mới',
    );
    expect(
      reopened.visible.subtasks.first.done,
      isTrue,
      reason: 'màn hình vẫn giữ đúng thứ người thợ đã chọn',
    );
  });

  test('tick server đã nhận thì không báo nhầm là chưa lưu', () async {
    // Lệnh đi được nhưng phản hồi không về (thợ rời màn hình giữa chừng). Nếu
    // mở lại vẫn báo "chưa lưu được" thì thợ bấm "Thử lại" cho một việc đã
    // xong, và học được rằng cảnh báo đó không đáng tin.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();

    final first = open(prefs, _OfflineTasksApi(piano(boMayDone: false)));
    await first.read(taskDetailProvider('t1').future);
    await first
        .read(taskDetailProvider('t1').notifier)
        .toggleSubtask('c1', done: true);
    first.dispose();

    // Lần này server trả về checklist đã có "Bộ máy" xong.
    final second = open(prefs, _OfflineTasksApi(piano(boMayDone: true)));
    final reopened = await second.read(taskDetailProvider('t1').future);
    second.dispose();

    expect(reopened.pendingFor('c1'), isNull);
    expect(reopened.visible.subtasks.first.done, isTrue);
  });
}

/// Đọc được, ghi thì không — đúng như xưởng lúc sóng chập chờn.
class _OfflineTasksApi implements TasksApi {
  _OfflineTasksApi(this._task);

  final Task _task;

  @override
  Future<Task> get(String id) async => _task;

  @override
  Future<Task> setSubtaskDone(
    String taskId,
    String subtaskId, {
    required bool done,
    String? clientRequestId,
  }) async {
    throw const NetworkException('Không có kết nối mạng');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
