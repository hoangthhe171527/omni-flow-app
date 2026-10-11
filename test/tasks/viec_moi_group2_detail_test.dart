import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/core/storage/preferences_store.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/data/tasks_api.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/domain/task_permissions.dart';
import 'package:omni_app/modules/tasks/domain/task_project.dart';
import 'package:omni_app/modules/tasks/presentation/task_detail_page.dart';
import 'package:omni_app/modules/team/team.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Nhóm 2 ở chi tiết việc (Task 10): người theo dõi, chuỗi người giao, ghim,
/// khoá. Mỗi mục một cặp: JSON API cũ → `findsNothing`; JSON API mới → có nút
/// và gọi đúng phương thức. Controller THẬT, chỉ TasksApi là giả.
void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  const me = 'u9';
  const worker = {'tasks.read', 'tasks.write'};
  const assigner = {'tasks.read', 'tasks.write', 'tasks.projects.manage.all'};

  /// Việc như API cũ trả: không pinned / locked / follower_* / *_by_name.
  Map<String, dynamic> oldJson() => {
    'id': 't1',
    'title': 'YAMAHA U3E',
    'project_id': 'p1',
    'assignee_ids': ['u1'],
    'assignee_names': ['Hằng Ni'],
    'created_by': 'u0',
    'checklist': <Map<String, dynamic>>[],
  };

  Map<String, dynamic> newJson({
    bool pinned = false,
    bool locked = false,
    List<String>? followers,
  }) => {
    ...oldJson(),
    'pinned': pinned,
    'locked': locked,
    'assigned_by': 'u0',
    'assigned_by_name': 'Trần Hưng',
    'created_by_name': 'Trần Hưng',
    'follower_ids': ?followers,
    if (followers != null)
      'follower_names': [
        for (final id in followers) id == me ? 'Thợ Hùng' : 'Khánh',
      ],
  };

  late _Api api;

  Future<void> pump(
    WidgetTester t,
    Map<String, dynamic> json, {
    Set<String> perms = assigner,
    TaskProject project = const TaskProject(ownerId: 'u0'),
  }) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
    api = _Api(json, project);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          taskRealtimeSignalProvider.overrideWith(_Silent.new),
          tasksApiProvider.overrideWithValue(api),
          planCustomFieldsProvider.overrideWith((ref, id) async => const []),
          taskLabelsProvider.overrideWith((ref) async => const []),
          teamDirectoryProvider.overrideWith(
            (ref) async => const [
              TeamMember(membershipId: 'm1', userId: 'u1', name: 'Hằng Ni'),
              TeamMember(membershipId: 'm2', userId: 'u2', name: 'Khánh'),
            ],
          ),
          taskAccessProvider.overrideWithValue(
            TaskAccess.of(AccessPolicy(perms)),
          ),
          sessionProvider.overrideWithValue(
            const Session(
              status: SessionStatus.authenticated,
              user: SessionUser(id: me, fullName: 'Thợ Hùng', email: 'h@t.vn'),
            ),
          ),
        ],
        child: MaterialApp(
          theme: OmniTheme.light(TargetPlatform.android),
          home: const TaskDetailPage(taskId: 't1'),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester t) async {
    await t.tap(find.byTooltip('Tuỳ chọn công việc'));
    await t.pumpAndSettle();
  }

  const group2Menu = [
    'Người theo dõi',
    'Ghim lên đầu cột',
    'Bỏ ghim',
    'Khoá công việc',
    'Mở khoá',
  ];

  testWidgets('API cũ: không nút theo dõi, không người giao, không mục '
      'Nhóm 2, không chip khoá', (t) async {
    await pump(t, oldJson());
    expect(find.byTooltip('Người theo dõi'), findsNothing);
    expect(find.bySemanticsLabel('Người giao: Trần Hưng'), findsNothing);
    expect(find.byKey(const Key('assigner-avatar')), findsNothing);
    expect(find.byKey(const Key('task-locked-chip')), findsNothing);
    await openMenu(t);
    for (final label in group2Menu) {
      expect(find.text(label), findsNothing, reason: label);
    }
  });

  testWidgets('fixture JSON cũ của Task 1 (tasks_show_viec_moi.json): mọi '
      'nút Nhóm 2 findsNothing', (t) async {
    final data =
        (jsonDecode(
                  File(
                    'test/contract/fixtures/tasks_show_viec_moi.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>)['data']
            as Map<String, dynamic>;
    await pump(t, {...data, 'id': 't1'});
    expect(find.byTooltip('Người theo dõi'), findsNothing);
    expect(find.byKey(const Key('assigner-avatar')), findsNothing);
    expect(find.byKey(const Key('task-locked-chip')), findsNothing);
    await openMenu(t);
    for (final label in group2Menu) {
      expect(find.text(label), findsNothing, reason: label);
    }
  });

  testWidgets('API mới: nút theo dõi trên header, chuỗi người giao → người '
      'làm (avatar 30), menu có Theo dõi (số), Ghim, Khoá', (t) async {
    await pump(t, newJson(followers: ['u2']));
    expect(find.byTooltip('Người theo dõi'), findsOneWidget);
    expect(find.bySemanticsLabel('Người giao: Trần Hưng'), findsOneWidget);
    expect(
      t.getSize(find.byKey(const Key('assigner-avatar'))),
      const Size(30, 30),
    );
    expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
    await openMenu(t);
    expect(find.text('Người theo dõi'), findsOneWidget);
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Người theo dõi'),
          matching: find.byType(Row),
        ),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(find.text('Ghim lên đầu cột'), findsOneWidget);
    expect(find.text('Khoá công việc'), findsOneWidget);
  });

  testWidgets('Ghim từ menu: POST pin, rồi menu đổi thành "Bỏ ghim"', (
    t,
  ) async {
    await pump(t, newJson());
    await openMenu(t);
    await t.tap(find.text('Ghim lên đầu cột'));
    await t.pumpAndSettle();
    expect(api.calls.last, ('pin', true));
    expect(find.text('Đã ghim lên đầu cột.'), findsOneWidget);
    await openMenu(t);
    expect(find.text('Bỏ ghim'), findsOneWidget);
    await t.tap(find.text('Bỏ ghim'));
    await t.pumpAndSettle();
    expect(api.calls.last, ('pin', false));
  });

  testWidgets('Khoá: POST lock; việc khoá hiện "Đã khoá", ẩn mọi mục sửa, '
      'còn "Mở khoá" và "Người theo dõi"', (t) async {
    await pump(t, newJson());
    await openMenu(t);
    await t.tap(find.text('Khoá công việc'));
    await t.pumpAndSettle();
    expect(api.calls.last, ('lock', true));
    expect(find.byKey(const Key('task-locked-chip')), findsOneWidget);
    expect(find.text('Đã khoá'), findsOneWidget);
    // Không còn nút sửa trên thẻ thông tin / mô tả.
    expect(find.bySemanticsLabel('Thêm người làm'), findsNothing);
    expect(find.byTooltip('Sửa mô tả'), findsNothing);

    await openMenu(t);
    for (final gone in [
      'Ghim lên đầu cột',
      'Đổi tên việc',
      'Chuyển sang nhóm / kế hoạch khác',
      'Lưu trữ',
      'Xoá công việc',
    ]) {
      expect(find.text(gone), findsNothing, reason: gone);
    }
    expect(find.text('Người theo dõi'), findsOneWidget);
    await t.tap(find.text('Mở khoá'));
    await t.pumpAndSettle();
    expect(api.calls.last, ('lock', false));
    expect(find.byKey(const Key('task-locked-chip')), findsNothing);
  });

  testWidgets('thợ là thành viên thường: không có Khoá; là quản lý kế hoạch: '
      'có', (t) async {
    await pump(
      t,
      newJson(),
      perms: worker,
      project: const TaskProject(ownerId: 'u0', memberIds: [me]),
    );
    await openMenu(t);
    expect(find.text('Khoá công việc'), findsNothing);
    expect(find.text('Ghim lên đầu cột'), findsOneWidget);
  });

  testWidgets('thợ là quản lý kế hoạch (vai từ GET /projects/{id}): có Khoá', (
    t,
  ) async {
    await pump(
      t,
      newJson(),
      perms: worker,
      project: const TaskProject(ownerId: 'u0', memberRoles: {me: 'manager'}),
    );
    await openMenu(t);
    expect(find.text('Khoá công việc'), findsOneWidget);
  });

  testWidgets('sheet theo dõi: "Theo dõi việc này" POST follow; người giao '
      'bỏ người khác bằng PUT follower_ids', (t) async {
    await pump(t, newJson(followers: ['u2']));
    await t.tap(find.byTooltip('Người theo dõi'));
    await t.pumpAndSettle();
    expect(find.text('Người theo dõi (1)'), findsOneWidget);
    expect(find.text('Khánh'), findsOneWidget);

    await t.tap(find.text('Theo dõi việc này'));
    await t.pumpAndSettle();
    expect(api.calls.last, ('follow', true));
    expect(find.text('Người theo dõi (2)'), findsOneWidget);
    expect(find.text('Bỏ theo dõi'), findsOneWidget);

    await t.tap(find.byTooltip('Bỏ Khánh khỏi theo dõi'));
    await t.pumpAndSettle();
    expect(api.calls.last.$1, 'followers');
    expect(api.calls.last.$2, [me]);
  });

  testWidgets('thợ: tự theo dõi được, KHÔNG thêm / bỏ người khác', (t) async {
    await pump(t, newJson(followers: ['u2']), perms: worker);
    await t.tap(find.byTooltip('Người theo dõi'));
    await t.pumpAndSettle();
    expect(find.text('Theo dõi việc này'), findsOneWidget);
    expect(find.text('Thêm người theo dõi'), findsNothing);
    expect(find.byTooltip('Bỏ Khánh khỏi theo dõi'), findsNothing);
  });

  testWidgets('423 task_locked khi sửa: hiện câu server, tải lại và khoá màn', (
    t,
  ) async {
    await pump(t, newJson());
    api.lockOnNextWrite = true;
    await openMenu(t);
    await t.tap(find.text('Đổi tên việc'));
    await t.pumpAndSettle();
    await t.enterText(
      find.byWidgetPredicate((w) => w is TextField && w.autofocus),
      'Tên mới',
    );
    await t.pump();
    await t.tap(find.text('Lưu'));
    await t.pumpAndSettle();
    expect(api.calls.last, ('title', 'Tên mới'));
    expect(find.text('Công việc đã bị khoá.'), findsOneWidget);
    expect(find.byKey(const Key('task-locked-chip')), findsOneWidget);
  });
}

class _Api implements TasksApi {
  _Api(this._json, this._project);

  Map<String, dynamic> _json;
  final TaskProject _project;
  final calls = <(String, Object?)>[];
  bool lockOnNextWrite = false;

  Task _with(Map<String, dynamic> patch) {
    _json = {..._json, ...patch};
    return Task.fromJson(_json);
  }

  @override
  Future<Task> get(String id) async => Task.fromJson(_json);

  @override
  Future<TaskProject> project(String projectId) async {
    calls.add(('project', projectId));
    return _project;
  }

  @override
  Future<Task> setPinned(String taskId, bool pinned) async {
    calls.add(('pin', pinned));
    return _with({'pinned': pinned});
  }

  @override
  Future<Task> setLocked(String taskId, bool locked) async {
    calls.add(('lock', locked));
    return _with({'locked': locked});
  }

  @override
  Future<Task> setFollowing(String taskId, bool following) async {
    calls.add(('follow', following));
    final ids = [...((_json['follower_ids'] as List?) ?? const [])];
    following ? ids.add('u9') : ids.remove('u9');
    return _with({
      'follower_ids': ids,
      'follower_names': [
        for (final id in ids) id == 'u9' ? 'Thợ Hùng' : 'Khánh',
      ],
    });
  }

  @override
  Future<Task> setFollowers(String taskId, List<String> userIds) async {
    calls.add(('followers', userIds));
    return _with({
      'follower_ids': userIds,
      'follower_names': [
        for (final id in userIds) id == 'u9' ? 'Thợ Hùng' : 'Khánh',
      ],
    });
  }

  @override
  Future<Task> setTitle(String taskId, String title) async {
    calls.add(('title', title));
    if (lockOnNextWrite) {
      // Máy khác vừa khoá việc.
      _json = {..._json, 'locked': true};
      throw const RequestRejectedException(
        'Công việc đã bị khoá.',
        code: '423',
        reason: 'task_locked',
      );
    }
    return _with({'title': title});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Silent extends TaskRealtimeSignal {
  @override
  int build() => 0;
}
