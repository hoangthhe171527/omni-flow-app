import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/tasks/application/task_controller.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/domain/task_permissions.dart';
import 'package:omni_app/modules/tasks/presentation/task_detail_page.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

/// Người thợ TỰ NHẬN một cây đàn chưa ai nhận.
///
/// §3 của TNP_PIANO_WORKSHOP_FLOW.md là pull-based: ai rảnh tự nhận. Phía API
/// đã cho phép từ đầu — `ProjectAccessService::assertCanEditTasks` chỉ chặn
/// vai `viewer`, còn `tasks.write` thì vai `worker` có sẵn — nhưng app không
/// có chỗ nào để bấm: nơi duy nhất chạm được `assignee_ids` là bảng điều phối,
/// và bảng đó chỉ hiện với người có `tasks.projects.manage.all`.
void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  /// Đúng bộ quyền của vai `worker` bên API (`SystemRolePresets::worker`),
  /// trừ quyền thiết bị vốn không liên quan tới màn này.
  const worker = {'tasks.read', 'tasks.write'};
  const me = 'u9';

  Task taskWith(List<String> ids, List<String> names) => Task.fromJson({
    'id': 't1',
    'title': 'SCHWESTER No.53 — SN 471302',
    'project_id': 'p1',
    'section_id': 's2',
    'assignee_ids': ids,
    'assignee_names': names,
  });

  late List<List<String>> saved;

  Widget host({List<String> ids = const [], List<String> names = const []}) {
    saved = [];

    return ProviderScope(
      overrides: [
        taskDetailProvider.overrideWith(
          () => _RecordingDetail(
            TaskDetailState(task: taskWith(ids, names)),
            saved,
          ),
        ),
        taskAccessProvider.overrideWithValue(
          TaskAccess.of(const AccessPolicy(worker)),
        ),
        sessionProvider.overrideWithValue(
          const Session(
            status: SessionStatus.authenticated,
            user: SessionUser(
              id: me,
              fullName: 'Thợ Hùng',
              email: 'hung@tnp.vn',
            ),
          ),
        ),
      ],
      child: MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        home: const TaskDetailPage(taskId: 't1'),
      ),
    );
  }

  testWidgets('việc chưa ai nhận: người thợ tự nhận được', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nhận việc này'));
    await tester.pumpAndSettle();

    expect(saved, [
      [me],
    ]);
  });

  testWidgets('việc đã có người: nhận THÊM chứ không đá ai ra', (tester) async {
    // API ghi đè cả mảng `assignee_ids`, nên gửi mỗi id của mình là lặng lẽ gỡ
    // người đang làm dở ra khỏi việc — và họ mất luôn việc trong danh sách của
    // mình mà không có gì báo.
    await tester.pumpWidget(host(ids: ['u1'], names: ['Hằng Ni']));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nhận việc này'));
    await tester.pumpAndSettle();

    expect(saved, [
      ['u1', me],
    ]);
  });

  testWidgets('đã có tên mình rồi thì không còn nút nhận', (tester) async {
    // Nút này THÊM mình vào, không bật/tắt: gỡ mình ra là quyết định khác hẳn
    // và vẫn là việc của quản đốc.
    await tester.pumpWidget(host(ids: [me], names: ['Thợ Hùng']));
    await tester.pumpAndSettle();

    expect(find.text('Nhận việc này'), findsNothing);
  });

  testWidgets('nhận việc KHÔNG đi qua danh bạ nhân sự', (tester) async {
    // Vai `worker` cố ý không có `membership.members.read`. Nếu nút này mở bộ
    // chọn người thì nó rỗng với đúng người cần nó — đó chính là cách nút
    // "Gán" bên web đang hỏng.
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nhận việc này'));
    await tester.pumpAndSettle();

    expect(find.text('Ai làm việc này'), findsNothing);
    expect(saved, [
      [me],
    ]);
  });
}

class _RecordingDetail extends TaskController {
  _RecordingDetail(this._state, this._saved);

  final TaskDetailState _state;
  final List<List<String>> _saved;

  @override
  Future<TaskDetailState> build(String taskId) async => _state;

  @override
  Future<void> setAssignees(List<String> userIds) async {
    _saved.add(userIds);
  }
}
