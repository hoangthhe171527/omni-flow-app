import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/modules/tasks/application/task_controller.dart';
import 'package:omni_app/modules/tasks/application/task_detail_actions.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';

/// Phần "có gì để ghi không" của màn chi tiết, tách khỏi widget.
///
/// Trước đây bảy thao tác điều phối nằm trong `_Loaded` của TaskDetailPage —
/// mỗi cái mở một sheet, so với giá trị cũ, gọi controller, bắt lỗi — và cái
/// file 1200 dòng đó là thứ duy nhất kiểm được chúng. Ở đây chúng là hàm
/// thuần trên Task + lựa chọn: không context, không sheet, không snackbar.
void main() {
  final task = Task.fromJson({
    'id': 't1',
    'title': 'KAWAI HAT-5',
    'description': 'Body xước nhẹ',
    'priority': 'med',
    'section_id': 's1',
    'due_date': '2026-12-31T00:00:00Z',
    'assignee_ids': ['u1', 'u2'],
  });

  late _Recording controller;
  late TaskDetailActions actions;

  setUp(() {
    controller = _Recording();
    actions = TaskDetailActions(controller);
  });

  group('claim', () {
    test('THÊM mình vào danh sách, gửi cả những người đang làm', () async {
      // PUT ghi đè assignee_ids: gửi mỗi id của mình là lặng lẽ gỡ người
      // khác ra khỏi việc.
      await actions.claim(task, 'u9');

      // So từng vế: record so List theo danh tính, không theo nội dung.
      expect(controller.calls.single.$1, 'setAssignees');
      expect(controller.calls.single.$2, ['u1', 'u2', 'u9']);
    });

    test('đã có tên rồi thì không ghi', () async {
      await actions.claim(task, 'u1');

      expect(controller.calls, isEmpty);
    });
  });

  group('assign', () {
    test('đóng sheet không chọn thì không ghi', () async {
      await actions.assign(task, null);

      expect(controller.calls, isEmpty);
    });

    test('cùng danh sách, khác thứ tự, thì không ghi', () async {
      // Một lượt ghi rỗng vẫn chạm updated_at lẫn nhật ký hoạt động.
      await actions.assign(task, ['u2', 'u1']);

      expect(controller.calls, isEmpty);
    });

    test('danh sách khác thì gửi đúng danh sách đó', () async {
      await actions.assign(task, ['u3']);

      expect(controller.calls.single.$1, 'setAssignees');
      expect(controller.calls.single.$2, ['u3']);
    });

    test('bỏ chọn hết là một lựa chọn hợp lệ', () async {
      await actions.assign(task, const []);

      expect(controller.calls, [('setAssignees', const <String>[])]);
    });
  });

  group('editDueDate', () {
    test('cùng ngày, khác giờ, thì không ghi', () async {
      await actions.editDueDate(task, DateTime(2026, 12, 31, 15, 30));

      expect(controller.calls, isEmpty);
    });

    test('ngày khác thì ghi', () async {
      final next = DateTime(2027, 1, 5);
      await actions.editDueDate(task, next);

      expect(controller.calls, [('setDueDate', next)]);
    });

    test('xoá hạn đang có thì ghi null', () async {
      await actions.editDueDate(task, null);

      expect(controller.calls, [('setDueDate', null)]);
    });

    test('xoá hạn khi vốn chưa có hạn thì không ghi', () async {
      final undated = Task.fromJson({'id': 't1', 'title': 'x'});
      await actions.editDueDate(undated, null);

      expect(controller.calls, isEmpty);
    });
  });

  group('editPriority', () {
    test('không chọn hoặc chọn lại mức đang có thì không ghi', () async {
      await actions.editPriority(task, null);
      await actions.editPriority(task, 'med');

      expect(controller.calls, isEmpty);
    });

    test('mức khác thì ghi mã API', () async {
      await actions.editPriority(task, 'high');

      expect(controller.calls, [('setPriority', 'high')]);
    });
  });

  group('editTitle', () {
    test('không chọn hoặc giữ nguyên thì không ghi', () async {
      await actions.editTitle(task, null);
      await actions.editTitle(task, 'KAWAI HAT-5');

      expect(controller.calls, isEmpty);
    });

    test('tên mới thì ghi', () async {
      await actions.editTitle(task, 'KAWAI HAT-5 · 2308512');

      expect(controller.calls, [('setTitle', 'KAWAI HAT-5 · 2308512')]);
    });
  });

  group('editDescription', () {
    test('không chọn hoặc giữ nguyên thì không ghi', () async {
      await actions.editDescription(task, null);
      await actions.editDescription(task, 'Body xước nhẹ');

      expect(controller.calls, isEmpty);
    });

    test('xoá sạch mô tả là lựa chọn hợp lệ', () async {
      await actions.editDescription(task, '');

      expect(controller.calls, [('setDescription', '')]);
    });
  });

  group('moveSection', () {
    test(
      'không chọn hoặc chọn lại công đoạn đang đứng thì không ghi',
      () async {
        await actions.moveSection(task, null);
        await actions.moveSection(task, 's1');

        expect(controller.calls, isEmpty);
      },
    );

    test('công đoạn khác thì ghi', () async {
      await actions.moveSection(task, 's2');

      expect(controller.calls, [('moveToSection', 's2')]);
    });
  });

  test('lỗi API ném ra ngoài, không nuốt', () async {
    // UI là chỗ có ScaffoldMessenger; lớp này không được quyết định thay nó
    // rằng "không sao". Cổng QC từ chối bằng 422 kèm tên công đoạn còn thiếu
    // — nuốt ở đây là quản đốc bấm lại mà không hiểu vì sao thẻ không đi.
    controller.failWith = const NetworkException('Còn thiếu: Lên dây');

    await expectLater(
      actions.moveSection(task, 's2'),
      throwsA(
        isA<AppException>().having(
          (e) => e.message,
          'message',
          'Còn thiếu: Lên dây',
        ),
      ),
    );
  });
}

/// Ghi lại từng lệnh gửi tới controller; không chạm state hay ref.
class _Recording extends TaskController {
  final List<(String, Object?)> calls = [];
  AppException? failWith;

  Future<void> _record(String method, Object? arg) async {
    final failure = failWith;
    if (failure != null) throw failure;
    calls.add((method, arg));
  }

  @override
  Future<void> setAssignees(List<String> userIds) =>
      _record('setAssignees', userIds);

  @override
  Future<void> setDueDate(DateTime? dueDate) => _record('setDueDate', dueDate);

  @override
  Future<void> setPriority(String priority) => _record('setPriority', priority);

  @override
  Future<void> setTitle(String title) => _record('setTitle', title);

  @override
  Future<void> setDescription(String description) =>
      _record('setDescription', description);

  @override
  Future<void> moveToSection(String? sectionId) =>
      _record('moveToSection', sectionId);
}
