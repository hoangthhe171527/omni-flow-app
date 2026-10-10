import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/design/components/omni_dashed_circle.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/tasks/application/task_controller.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/domain/task_permissions.dart';
import 'package:omni_app/modules/tasks/presentation/task_detail_page.dart';
import 'package:omni_app/modules/team/team.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

/// Việc con: vòng nét đứt có +, giao / đổi / bỏ gán từ danh sách thành viên dự
/// án. Chạy trên TaskDetailPage thật; chỉ controller bị thay bằng bản ghi lại.
void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  const worker = {'tasks.read', 'tasks.write'};
  const assigner = {'tasks.read', 'tasks.write', 'tasks.projects.manage.all'};

  final recorded = <(String, String, String?)>[];
  setUp(recorded.clear);

  TeamMember member(String id, String name, [String? job]) =>
      TeamMember(membershipId: 'm$id', userId: id, name: name, jobTitle: job);

  Subtask sub(String id, String title, {String? assignee, String? name}) =>
      Subtask(
        id: id,
        title: title,
        done: false,
        assigneeId: assignee,
        assigneeName: name,
      );

  Widget host({
    required List<Subtask> subtasks,
    required Set<String> perms,
    bool membersError = false,
    AppException? assignThrows,
    bool reduceMotion = false,
    SessionUser? me,
    Duration addDelay = Duration.zero,
  }) {
    final task = Task(
      id: 't1',
      title: 'KAWAI HAT-5',
      projectId: 'p1',
      subtasks: subtasks,
    );

    return ProviderScope(
      overrides: [
        taskDetailProvider.overrideWith(
          () => _RecordingDetail(
            TaskDetailState(task: task),
            recorded,
            assignThrows,
            addDelay,
          ),
        ),
        taskAccessProvider.overrideWithValue(
          TaskAccess.of(AccessPolicy(perms)),
        ),
        projectMembersProvider.overrideWith((ref, id) async {
          if (membersError) throw const NetworkException('mạng hỏng');
          return [
            member('u1', 'Hoàng', 'Thợ chính'),
            member('u2', 'Minh'),
            member('u3', 'Tuấn'),
          ];
        }),
        if (me != null)
          sessionProvider.overrideWithValue(
            Session(status: SessionStatus.authenticated, user: me),
          ),
      ],
      child: MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: const TaskDetailPage(taskId: 't1'),
      ),
    );
  }

  void phone(WidgetTester t) {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
  }

  testWidgets('việc con chưa ai làm: vòng nét đứt, KHÔNG có chữ "Tôi nhận"', (
    t,
  ) async {
    phone(t);
    await t.pumpWidget(host(subtasks: [sub('c1', 'Vệ sinh')], perms: worker));
    await t.pumpAndSettle();
    expect(find.byType(OmniDashedCircle), findsOneWidget);
    expect(find.bySemanticsLabel('Giao việc con'), findsOneWidget);
    expect(find.textContaining('Tôi nhận'), findsNothing);
    expect(find.textContaining('Nhận'), findsNothing);
  });

  testWidgets('chạm vòng → sheet có ô tìm, lọc, chọn → assignSubtask(c1, u2)', (
    t,
  ) async {
    phone(t);
    await t.pumpWidget(host(subtasks: [sub('c1', 'Vệ sinh')], perms: worker));
    await t.pumpAndSettle();
    await t.tap(find.bySemanticsLabel('Giao việc con'));
    await t.pumpAndSettle();
    expect(find.text('Ai làm việc này'), findsOneWidget);
    expect(find.text('Việc con: Vệ sinh'), findsOneWidget);
    expect(find.text('Bỏ gán'), findsNothing);
    await t.enterText(find.byType(TextField).last, 'minh');
    await t.pumpAndSettle();
    expect(find.text('Hoàng'), findsNothing);
    await t.tap(find.text('Minh'));
    await t.pumpAndSettle();
    expect(recorded.last, ('assignSubtask', 'c1', 'u2'));
  });

  testWidgets('tìm không dấu vẫn ra người có dấu', (t) async {
    phone(t);
    await t.pumpWidget(host(subtasks: [sub('c1', 'A')], perms: worker));
    await t.pumpAndSettle();
    await t.tap(find.bySemanticsLabel('Giao việc con'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).last, 'hoang');
    await t.pumpAndSettle();
    expect(find.text('Hoàng'), findsOneWidget);
    expect(find.text('Minh'), findsNothing);
  });

  testWidgets('tìm không ra: "Không tìm thấy ai"', (t) async {
    phone(t);
    await t.pumpWidget(host(subtasks: [sub('c1', 'A')], perms: worker));
    await t.pumpAndSettle();
    await t.tap(find.bySemanticsLabel('Giao việc con'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).last, 'zzz');
    await t.pumpAndSettle();
    expect(find.text('Không tìm thấy ai'), findsOneWidget);
  });

  testWidgets('đã có người: chạm avatar → Bỏ gán → assignSubtask(c1, null)', (
    t,
  ) async {
    phone(t);
    await t.pumpWidget(
      host(
        subtasks: [sub('c1', 'A', assignee: 'u1', name: 'Hoàng')],
        perms: worker,
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.bySemanticsLabel('Đổi người làm: Hoàng'));
    await t.pumpAndSettle();
    await t.tap(find.text('Bỏ gán'));
    await t.pumpAndSettle();
    expect(recorded.last, ('assignSubtask', 'c1', null));
  });

  testWidgets('chọn đúng người đang giữ: không ghi gì', (t) async {
    phone(t);
    await t.pumpWidget(
      host(
        subtasks: [sub('c1', 'A', assignee: 'u1', name: 'Hoàng')],
        perms: worker,
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.bySemanticsLabel('Đổi người làm: Hoàng'));
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.check_rounded), findsWidgets);
    await t.tap(find.text('Hoàng').last);
    await t.pumpAndSettle();
    expect(recorded, isEmpty);
  });

  testWidgets('danh sách thành viên lỗi: vẫn có Thử lại và Bỏ gán', (t) async {
    phone(t);
    await t.pumpWidget(
      host(
        subtasks: [sub('c1', 'A', assignee: 'u1', name: 'Hoàng')],
        perms: worker,
        membersError: true,
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.bySemanticsLabel('Đổi người làm: Hoàng'));
    await t.pumpAndSettle();
    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.text('Bỏ gán'), findsOneWidget);
  });

  testWidgets('thợ không đọc được danh bạ: vẫn tự nhận việc con về mình', (
    t,
  ) async {
    phone(t);
    await t.pumpWidget(
      host(
        subtasks: [sub('c1', 'Vệ sinh')],
        perms: worker,
        membersError: true,
        me: const SessionUser(id: 'u9', fullName: 'Thợ Chín', email: 'x@y.z'),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.bySemanticsLabel('Giao việc con'));
    await t.pumpAndSettle();
    await t.tap(find.text('Thợ Chín').last);
    await t.pumpAndSettle();
    expect(recorded.last, ('assignSubtask', 'c1', 'u9'));
  });

  testWidgets(
    'không có quyền ghi: nút người làm chỉ hiển thị, không mở sheet',
    (t) async {
      phone(t);
      await t.pumpWidget(
        host(subtasks: [sub('c1', 'A')], perms: const {'tasks.read'}),
      );
      await t.pumpAndSettle();
      await t.tap(find.bySemanticsLabel('Giao việc con'));
      await t.pumpAndSettle();
      expect(find.text('Ai làm việc này'), findsNothing);
    },
  );

  testWidgets('máy chủ từ chối (422): SnackBar lỗi, avatar cũ giữ nguyên', (
    t,
  ) async {
    phone(t);
    await t.pumpWidget(
      host(
        subtasks: [sub('c1', 'A', assignee: 'u1', name: 'Hoàng')],
        perms: worker,
        assignThrows: const ValidationException(
          'Người này không còn trong workspace.',
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.bySemanticsLabel('Đổi người làm: Hoàng'));
    await t.pumpAndSettle();
    await t.tap(find.text('Minh'));
    await t.pumpAndSettle();
    expect(find.text('Người này không còn trong workspace.'), findsOneWidget);
    expect(find.bySemanticsLabel('Đổi người làm: Hoàng'), findsOneWidget);
  });

  testWidgets('thêm việc con bằng Enter (người giao việc)', (t) async {
    phone(t);
    await t.pumpWidget(host(subtasks: const [], perms: assigner));
    await t.pumpAndSettle();
    await t.enterText(
      find.widgetWithText(TextField, 'Thêm việc con'),
      'Lên dây lần 2',
    );
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect(recorded.last, ('addSubtask', 'Lên dây lần 2', null));
  });

  testWidgets('Enter hai lần khi đang thêm: chỉ thêm MỘT việc con', (t) async {
    phone(t);
    await t.pumpWidget(
      host(
        subtasks: const [],
        perms: assigner,
        addDelay: const Duration(milliseconds: 200),
      ),
    );
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextField, 'Thêm việc con'), 'Lắp');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pump(const Duration(milliseconds: 50));
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pump(const Duration(milliseconds: 400));
    await t.pumpAndSettle();
    expect(recorded.where((r) => r.$1 == 'addSubtask'), hasLength(1));
  });

  testWidgets('trình đọc màn hình: ô tick và nút người làm kích hoạt được', (
    t,
  ) async {
    phone(t);
    final handle = t.ensureSemantics();
    await t.pumpWidget(host(subtasks: [sub('c1', 'Vệ sinh')], perms: worker));
    await t.pumpAndSettle();
    final tick = find.bySemanticsLabel('Xong');
    expect(t.getSemantics(tick).getSemanticsData().value, 'Vệ sinh');
    expect(
      t.getSemantics(tick),
      matchesSemantics(
        hasTapAction: true,
        isButton: true,
        hasCheckedState: true,
        label: 'Xong',
        value: 'Vệ sinh',
      ),
    );
    t.semantics.tap(find.semantics.byLabel('Xong'));
    await t.pump();
    expect(recorded.last, ('toggleSubtask', 'c1', 'true'));

    t.semantics.tap(find.semantics.byLabel('Giao việc con'));
    await t.pumpAndSettle();
    expect(find.text('Ai làm việc này'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('thêm việc con: chuỗi trống bị bỏ qua', (t) async {
    phone(t);
    await t.pumpWidget(host(subtasks: const [], perms: assigner));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextField, 'Thêm việc con'), '   ');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect(recorded, isEmpty);
  });

  testWidgets('người thợ không thấy ô "Thêm việc con"', (t) async {
    phone(t);
    await t.pumpWidget(host(subtasks: [sub('c1', 'A')], perms: worker));
    await t.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Thêm việc con'), findsNothing);
  });

  testWidgets('tiêu đề khối: VIỆC CON và số xong/tổng', (t) async {
    phone(t);
    await t.pumpWidget(
      host(subtasks: [sub('c1', 'A'), sub('c2', 'B')], perms: worker),
    );
    await t.pumpAndSettle();
    expect(find.text('VIỆC CON'), findsOneWidget);
    expect(find.text('0/2'), findsOneWidget);
  });

  testWidgets('giảm chuyển động: tick không để lại hoạt ảnh', (t) async {
    phone(t);
    await t.pumpWidget(
      host(subtasks: [sub('c1', 'A')], perms: worker, reduceMotion: true),
    );
    await t.pumpAndSettle();
    await t.tap(find.bySemanticsLabel('Xong'));
    await t.pump();
    await t.pump();
    expect(t.hasRunningAnimations, isFalse);
    expect(recorded.last, ('toggleSubtask', 'c1', 'true'));
  });

  testWidgets('vùng chạm ô tick và nút người làm ≥ 44', (t) async {
    phone(t);
    await t.pumpWidget(host(subtasks: [sub('c1', 'A')], perms: worker));
    await t.pumpAndSettle();
    expect(
      t.getSize(find.bySemanticsLabel('Giao việc con')).shortestSide,
      greaterThanOrEqualTo(44),
    );
    expect(
      t.getSize(find.bySemanticsLabel('Xong')).shortestSide,
      greaterThanOrEqualTo(44),
    );
  });
}

class _RecordingDetail extends TaskController {
  _RecordingDetail(this._state, this._log, this._assignThrows, this._addDelay);

  final TaskDetailState _state;
  final List<(String, String, String?)> _log;
  final AppException? _assignThrows;
  final Duration _addDelay;

  @override
  Future<TaskDetailState> build(String taskId) async => _state;

  @override
  Future<void> assignSubtask(String subtaskId, String? userId) async {
    _log.add(('assignSubtask', subtaskId, userId));
    final error = _assignThrows;
    if (error != null) throw error;
  }

  @override
  Future<void> addSubtask(String title) async {
    _log.add(('addSubtask', title, null));
    await Future<void>.delayed(_addDelay);
  }

  @override
  Future<void> toggleSubtask(String subtaskId, {required bool done}) async {
    _log.add(('toggleSubtask', subtaskId, '$done'));
  }
}
